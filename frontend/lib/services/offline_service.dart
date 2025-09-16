// lib/services/offline_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Network reachability states surfaced to the app. [adapter-driven]
enum NetworkStatus { online, offline, unknown }

/// High-level sync lifecycle for queue processing.
enum SyncState { idle, syncing, paused, failed }

/// Conflict resolution policies for server/client merges.
enum ConflictPolicy { serverWins, clientWins, merge }

// ---------------------------- Connectivity ----------------------------

/// Provider contract for connectivity; wire connectivity_plus or a custom checker in an adapter.
abstract class ConnectivityProvider {
  Stream<NetworkStatus> get onStatus; // emits online/offline/unknown
  Future<NetworkStatus> current();
}

/// Simple mock for tests.
class MockConnectivityProvider implements ConnectivityProvider {
  MockConnectivityProvider({NetworkStatus initial = NetworkStatus.online})
      : _status = ValueNotifier<NetworkStatus>(initial) {
    _controller.add(initial);
  }

  final ValueNotifier<NetworkStatus> _status;
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();

  @override
  Stream<NetworkStatus> get onStatus => _controller.stream;

  @override
  Future<NetworkStatus> current() async => _status.value;

  void setStatus(NetworkStatus s) {
    _status.value = s;
    _controller.add(s);
  }

  Future<void> dispose() async => _controller.close();
}

// ---------------------------- Storage ----------------------------

/// Lightweight key-value storage for cache and queue persistence.
abstract class KeyValueStore {
  Future<void> putString(String box, String key, String value);
  Future<String?> getString(String box, String key);
  Future<void> delete(String box, String key);
  Future<List<String>> keys(String box);
  Future<void> clear(String box);
}

/// In-memory fallback store; replace with file/SQLite/Isar adapter in production.
class InMemoryStore implements KeyValueStore {
  final Map<String, Map<String, String>> _db = <String, Map<String, String>>{};

  Map<String, String> _box(String name) => _db.putIfAbsent(name, () => <String, String>{});

  @override
  Future<void> putString(String box, String key, String value) async {
    _box(box)[key] = value;
  }

  @override
  Future<String?> getString(String box, String key) async => _box(box)[key];

  @override
  Future<void> delete(String box, String key) async {
    _box(box).remove(key);
  }

  @override
  Future<List<String>> keys(String box) async => _box(box).keys.toList(growable: false);

  @override
  Future<void> clear(String box) async => _box(box).clear();
}

// ---------------------------- HTTP Adapter ----------------------------

/// Minimal HTTP adapter for sync execution; wire your project client here.
abstract class HttpAdapter {
  Future<HttpResponse> send(HttpRequest req);
}

@immutable
class HttpRequest {
  const HttpRequest({
    required this.method,
    required this.url,
    this.headers = const <String, String>{},
    this.bodyBytes,
    this.timeout = const Duration(seconds: 30),
  });

  final String method; // GET, POST, PATCH, PUT, DELETE
  final String url;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
  final Duration timeout;
}

@immutable
class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  String get bodyAsString => utf8.decode(bodyBytes);
}

// ---------------------------- SWR Cache ----------------------------

/// Cache entry used for GET responses (stale-while-revalidate).
@immutable
class CacheEntry {
  const CacheEntry({
    required this.key,
    required this.body,
    required this.etag,
    required this.lastFetched,
    required this.ttlSeconds,
  });

  final String key;
  final String body; // UTF-8 JSON/text payload
  final String? etag; // optional ETag for conditional requests
  final DateTime lastFetched;
  final int ttlSeconds;

  bool get isFresh {
    final age = DateTime.now().toUtc().difference(lastFetched).inSeconds;
    return age <= ttlSeconds;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'body': body,
        'etag': etag,
        'lastFetched': lastFetched.toIso8601String(),
        'ttl': ttlSeconds,
      };

  static CacheEntry fromJson(Map<String, dynamic> json) => CacheEntry(
        key: (json['key'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        etag: (json['etag'] as String?),
        lastFetched: DateTime.parse(json['lastFetched'].toString()),
        ttlSeconds: (json['ttl'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------- Sync Queue ----------------------------

/// A queued mutation with retry/backoff and optional dedupe.
@immutable
class SyncTask {
  const SyncTask({
    required this.id,
    required this.priority,
    required this.request,
    this.createdAt,
    this.lastAttemptAt,
    this.attempts = 0,
    this.maxAttempts = 5,
    this.initialBackoffMs = 1000,
    this.dedupeKey,
    this.conflictPolicy = ConflictPolicy.serverWins,
    this.metadata = const <String, dynamic>{},
  });

  final String id; // unique client id (e.g., uuid)
  final int priority; // lower number => earlier
  final HttpRequest request;

  final DateTime? createdAt;
  final DateTime? lastAttemptAt;
  final int attempts;
  final int maxAttempts;

  final int initialBackoffMs; // base for exponential backoff with jitter
  final String? dedupeKey; // collapse tasks with same dedupeKey if desired
  final ConflictPolicy conflictPolicy;
  final Map<String, dynamic> metadata;

  SyncTask copyWith({
    int? priority,
    HttpRequest? request,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? attempts,
    int? maxAttempts,
    int? initialBackoffMs,
    String? dedupeKey,
    ConflictPolicy? conflictPolicy,
    Map<String, dynamic>? metadata,
  }) {
    return SyncTask(
      id: id,
      priority: priority ?? this.priority,
      request: request ?? this.request,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      initialBackoffMs: initialBackoffMs ?? this.initialBackoffMs,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      conflictPolicy: conflictPolicy ?? this.conflictPolicy,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'priority': priority,
        'request': <String, dynamic>{
          'method': request.method,
          'url': request.url,
          'headers': request.headers,
          'body': request.bodyBytes == null ? null : base64.encode(request.bodyBytes!),
          'timeoutMs': request.timeout.inMilliseconds,
        },
        'createdAt': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'attempts': attempts,
        'maxAttempts': maxAttempts,
        'initialBackoffMs': initialBackoffMs,
        'dedupeKey': dedupeKey,
        'conflictPolicy': conflictPolicy.name,
        'metadata': metadata,
      };

  static SyncTask fromJson(Map<String, dynamic> json) {
    final req = json['request'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return SyncTask(
      id: (json['id'] ?? '').toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      request: HttpRequest(
        method: (req['method'] ?? 'POST').toString(),
        url: (req['url'] ?? '').toString(),
        headers: (req['headers'] as Map?)?.cast<String, String>() ?? const <String, String>{},
        bodyBytes: req['body'] == null ? null : base64.decode((req['body'] as String)),
        timeout: Duration(milliseconds: (req['timeoutMs'] as num?)?.toInt() ?? 30000),
      ),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.tryParse(json['lastAttemptAt'].toString()) : null,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 5,
      initialBackoffMs: (json['initialBackoffMs'] as num?)?.toInt() ?? 1000,
      dedupeKey: (json['dedupeKey'] as String?),
      conflictPolicy: _policy((json['conflictPolicy'] ?? 'serverWins').toString()),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
  }

  static ConflictPolicy _policy(String v) {
    try {
      return ConflictPolicy.values.byName(v);
    } catch (_) {
      return ConflictPolicy.serverWins;
    }
  }
}

/// Persistent queue store using KeyValueStore boxes.
class TaskQueueStore {
  TaskQueueStore(this._kv);

  final KeyValueStore _kv;
  static const String box = 'offline_queue';

  Future<void> put(SyncTask task) async {
    await _kv.putString(box, task.id, json.encode(task.toJson()));
  }

  Future<void> remove(String id) async {
    await _kv.delete(box, id);
  }

  Future<List<SyncTask>> all() async {
    final ks = await _kv.keys(box);
    final out = <SyncTask>[];
    for (final k in ks) {
      final raw = await _kv.getString(box, k);
      if (raw == null) continue;
      try {
        out.add(SyncTask.fromJson(json.decode(raw) as Map<String, dynamic>));
      } catch (_) {
        // skip corrupted
      }
    }
    // sort: priority asc, then createdAt asc
    out.sort((a, b) {
      final c = a.priority.compareTo(b.priority);
      if (c != 0) return c;
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return at.compareTo(bt);
    });
    return out;
  }
}

// ---------------------------- Offline Service ----------------------------

typedef OptimisticApply = Future<void> Function(SyncTask task);
typedef RollbackApply = Future<void> Function(SyncTask task, Object error);
typedef MergeResolver = Future<List<int>> Function({
  required SyncTask task,
  required HttpResponse serverResponse,
  required ConflictPolicy policy,
});

/// Emits overall sync progress snapshot.
@immutable
class SyncProgress {
  const SyncProgress({
    required this.state,
    required this.pending,
    required this.inFlight,
    this.lastError,
  });

  final SyncState state;
  final int pending;
  final int inFlight;
  final String? lastError;
}

/// Core offline engine providing:
/// - connectivity awareness
/// - SWR cache for GETs
/// - optimistic queue for mutations with exponential backoff + jitter
/// - conflict handling policies with a pluggable resolver
class OfflineService {
  OfflineService({
    required ConnectivityProvider connectivity,
    required KeyValueStore store,
    required HttpAdapter http,
    TaskQueueStore? queueStore,
    this.mergeResolver,
    this.maxParallel = 2,
  })  : _connectivity = connectivity,
        _kv = store,
        _http = http,
        _queue = queueStore ?? TaskQueueStore(store) {
    _statusSub = _connectivity.onStatus.listen(_onNetwork);
    _initStatus();
  }

  final ConnectivityProvider _connectivity;
  final KeyValueStore _kv;
  final HttpAdapter _http;
  final TaskQueueStore _queue;

  final MergeResolver? mergeResolver;
  final int maxParallel;

  final StreamController<NetworkStatus> _net$ = StreamController<NetworkStatus>.broadcast();
  final StreamController<SyncProgress> _sync$ = StreamController<SyncProgress>.broadcast();

  late final StreamSubscription<NetworkStatus> _statusSub;

  NetworkStatus _status = NetworkStatus.unknown;
  SyncState _syncState = SyncState.idle;
  int _inFlight = 0;

  Stream<NetworkStatus> get network$ => _net$.stream;
  Stream<SyncProgress> get sync$ => _sync$.stream;

  void _emitSync({String? err}) {
    _sync$.add(SyncProgress(
      state: _syncState,
      pending: _pendingCount,
      inFlight: _inFlight,
      lastError: err,
    ));
  }

  int _pendingCount = 0;

  Future<void> _initStatus() async {
    _status = await _connectivity.current();
    _net$.add(_status);
    if (_status == NetworkStatus.online) {
      // kick off pending sync on launch when online
      unawaited(processQueue());
    }
  }

  void _onNetwork(NetworkStatus s) {
    _status = s;
    _net$.add(s);
    if (s == NetworkStatus.online) {
      unawaited(processQueue());
    }
  }

  Future<void> dispose() async {
    await _statusSub.cancel();
    await _net$.close();
    await _sync$.close();
  }

  // -------------------- SWR Cache for GET --------------------

  static const String _cacheBox = 'offline_cache';

  /// Stale-while-revalidate fetch:
  /// - Immediately return cached body if present (even if stale) via onCache
  /// - Perform network fetch; store fresh cache and deliver via onFresh
  /// - Conditional GET with ETag when available
  Future<void> swrFetch({
    required String cacheKey,
    required HttpRequest request,
    required void Function(String? cachedBody) onCache,
    required void Function(String freshBody) onFresh,
    int ttlSeconds = 60,
  }) async {
    // 1) Return cached (if any)
    final cached = await _kv.getString(_cacheBox, cacheKey);
    CacheEntry? entry;
    if (cached != null) {
      try {
        entry = CacheEntry.fromJson(json.decode(cached) as Map<String, dynamic>);
      } catch (_) {
        entry = null;
      }
    }
    onCache(entry?.body);

    // 2) If offline, stop here
    if (_status != NetworkStatus.online) return;

    // 3) Prepare conditional request if ETag exists
    final headers = Map<String, String>.from(request.headers);
    if (entry?.etag != null) {
      headers['If-None-Match'] = entry!.etag!;
    }

    final res = await _http.send(HttpRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      bodyBytes: request.bodyBytes,
      timeout: request.timeout,
    ));

    if (res.statusCode == 304 && entry != null) {
      // Not modified; keep cache
      onFresh(entry.body);
      return;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final etag = res.headers['etag'];
      final fresh = CacheEntry(
        key: cacheKey,
        body: res.bodyAsString,
        etag: etag,
        lastFetched: DateTime.now().toUtc(),
        ttlSeconds: ttlSeconds,
      );
      await _kv.putString(_cacheBox, cacheKey, json.encode(fresh.toJson()));
      onFresh(fresh.body);
    } else {
      // On error, fall back to cached already emitted
    }
  }

  // -------------------- Optimistic Queue --------------------

  final ValueNotifier<bool> _paused = ValueNotifier<bool>(false);

  void pauseSync() {
    _paused.value = true;
    _syncState = SyncState.paused;
    _emitSync();
  }

  void resumeSync() {
    _paused.value = false;
    if (_status == NetworkStatus.online) {
      unawaited(processQueue());
    }
  }

  /// Enqueue a mutation with optional optimistic reducer and rollback.
  /// Apply optimistic UI changes immediately before network, then reconcile later.
  Future<void> enqueue({
    required SyncTask task,
    OptimisticApply? optimistic,
    RollbackApply? rollback,
  }) async {
    // Deduplicate by dedupeKey (keep latest)
    if (task.dedupeKey != null) {
      final items = await _queue.all();
      for (final t in items) {
        if (t.dedupeKey == task.dedupeKey) {
          await _queue.remove(t.id);
        }
      }
    }
    await _queue.put(task.copyWith(createdAt: DateTime.now().toUtc()));
    _pendingCount = (await _queue.all()).length;
    _emitSync();

    if (optimistic != null) {
      await optimistic(task);
    }

    if (_status == NetworkStatus.online) {
      unawaited(processQueue(rollback: rollback));
    }
  }

  /// Process queue with bounded parallelism, exponential backoff + jitter,
  /// and basic conflict resolution policy hook.
  Future<void> processQueue({RollbackApply? rollback}) async {
    if (_paused.value) return;
    final items = await _queue.all();
    _pendingCount = items.length;
    if (items.isEmpty) {
      _syncState = SyncState.idle;
      _emitSync();
      return;
    }

    _syncState = SyncState.syncing;
    _emitSync();

    final iterator = items.iterator;
    final workers = <Future<void>>[];

    Future<void> worker() async {
      while (true) {
        if (_paused.value) return;

        SyncTask? current;
        // critical section
        if (iterator.moveNext()) {
          current = iterator.current;
        } else {
          break;
        }

        _inFlight++;
        _emitSync();
        try {
          final ok = await _executeTask(current);
          if (ok) {
            await _queue.remove(current.id);
          } else {
            // keep task for later retry
          }
        } catch (e) {
          // bubble to rollback, keep in queue for retry unless attempts exceeded
          if (rollback != null) {
            await rollback(current, e);
          }
        } finally {
          _inFlight--;
          _pendingCount = (await _queue.all()).length;
          _emitSync();
        }
      }
    }

    for (int i = 0; i < math.max(1, maxParallel); i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    _syncState = (await _queue.all()).isEmpty ? SyncState.idle : SyncState.failed;
    _emitSync();
  }

  Future<bool> _executeTask(SyncTask task) async {
    final attempts = task.attempts;
    if (attempts > 0) {
      // exponential backoff with jitter
      final waitMs = _expoBackoffWithJitter(task.initialBackoffMs, attempts);
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }

    final res = await _http.send(task.request);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // success
      return true;
    }

    if (res.statusCode == 409 && mergeResolver != null) {
      // conflict; attempt merge per policy
      final merged = await mergeResolver!(
        task: task,
        serverResponse: res,
        policy: task.conflictPolicy,
      );
      final mergedReq = task.request.copyWith(bodyBytes: merged);
      final mergedTask = task.copyWith(request: mergedReq, attempts: attempts + 1, lastAttemptAt: DateTime.now().toUtc());
      await _queue.put(mergedTask);
      return false;
    }

    // retry path
    final nextAttempts = attempts + 1;
    if (nextAttempts >= task.maxAttempts) {
      // give up; remove or keep for manual review (here keep failed state by returning false)
      return false;
    }

    final updated = task.copyWith(
      attempts: nextAttempts,
      lastAttemptAt: DateTime.now().toUtc(),
    );
    await _queue.put(updated);
    return false;
  }

  int _expoBackoffWithJitter(int initialMs, int attempts) {
    final base = initialMs * math.pow(2, attempts).toInt();
    final cap = 60 * 1000; // cap at 60s
    final bounded = math.min(base, cap);
    final jitter = math.Random().nextInt((bounded * 0.2).toInt() + 1); // +/-20% jitter
    return (bounded * 0.9).toInt() + jitter;
  }
}

// ---------------------------- Extensions ----------------------------

extension on HttpRequest {
  HttpRequest copyWith({
    String? method,
    String? url,
    Map<String, String>? headers,
    List<int>? bodyBytes,
    Duration? timeout,
  }) {
    return HttpRequest(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      bodyBytes: bodyBytes ?? this.bodyBytes,
      timeout: timeout ?? this.timeout,
    );
  }
}
