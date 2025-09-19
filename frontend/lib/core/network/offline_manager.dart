// lib/core/network/offline_manager.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';

/// Connectivity status simplified for app logic.
enum NetworkStatus {
  online,
  offline,
  unknown,
}

/// A queued task to be retried when back online.
class QueuedTask {
  final String id;
  final Future<void> Function() run;
  final int maxAttempts;
  int attempts = 0;

  QueuedTask({
    required this.id,
    required this.run,
    this.maxAttempts = 3,
  });
}

/// Central offline/online coordination, connectivity observation,
/// app-level offline mode, and a simple retry queue for transient failures.
class OfflineManager {
  OfflineManager._();
  static final OfflineManager _instance = OfflineManager._();
  static OfflineManager get instance => _instance;

  final Connectivity _connectivity = Connectivity();

  // State
  NetworkStatus _status = NetworkStatus.unknown;
  bool _offlineMode = false; // manual override (airplane-like inside app)

  // Streams
  final StreamController<NetworkStatus> _statusCtrl =
      StreamController<NetworkStatus>.broadcast();

  // Queue for offline tasks (e.g., POST/PUT) to retry when back online.
  final List<QueuedTask> _queue = <QueuedTask>[];
  Timer? _drainTimer;

  // Debounce connectivity notifications
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Keys for LocalStorage
  static const String _kOfflineMode = 'app_offline_mode';
  static const String _kLastOnlineTs = 'network_last_online_ts';

  bool _initialized = false;

  /// Initialize listeners, load offline mode and set initial state.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Restore offline mode preference
    _offlineMode = await LocalStorage.instance.getBool(_kOfflineMode) ?? false;

    // Determine initial connectivity (now returns a List<ConnectivityResult>)
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateStatusFromResults(results);

    // Listen for changes (now emits List<ConnectivityResult>)
    _connSub = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatusFromResults(results);
    });
  }

  /// Dispose resources (call on app shutdown).
  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
    _drainTimer?.cancel();
    _statusCtrl.close();
  }

  // ------------- State --------------

  NetworkStatus get status => _status;

  /// True if app can attempt network operations (connectivity online AND not forced offline).
  bool get canGoOnline => _status == NetworkStatus.online && !_offlineMode;

  bool get isOfflineMode => _offlineMode;

  Stream<NetworkStatus> get statusStream => _statusCtrl.stream;

  /// Manually toggle app offline mode (still listens to OS connectivity).
  Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    await LocalStorage.instance.setBool(_kOfflineMode, value);
    // Attempt queue drain if switching back to online-allowed
    if (canGoOnline) _scheduleQueueDrain(immediate: true);
  }

  DateTime? get lastOnlineAt => _lastOnlineAt;
  DateTime? _lastOnlineAt;

  // ------------- Queue -------------

  /// Add a task to the retry queue. The task will be executed when `canGoOnline` is true.
  /// Returns the queued task ID for tracking.
  String enqueue(Future<void> Function() task, {String? id, int maxAttempts = 3}) {
    final taskId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _queue.add(QueuedTask(id: taskId, run: task, maxAttempts: maxAttempts));
    _scheduleQueueDrain(immediate: canGoOnline);
    return taskId;
  }

  /// Attempts to run queued tasks while online. Implements a gentle backoff if tasks keep failing.
  void _scheduleQueueDrain({bool immediate = false}) {
    _drainTimer?.cancel();
    if (!canGoOnline) return;

    _drainTimer = Timer(immediate ? Duration.zero : const Duration(milliseconds: 250), () async {
      // Drain tasks sequentially to avoid stampede on reconnect
      var backoffMs = 200;
      while (_queue.isNotEmpty && canGoOnline) {
        final task = _queue.first;
        try {
          await task.run();
          _queue.removeAt(0);
          backoffMs = 200; // reset on success
        } catch (e) {
          task.attempts += 1;
          if (task.attempts >= task.maxAttempts) {
            // Drop task after max attempts
            _queue.removeAt(0);
            if (kDebugMode) {
              debugPrint('[offline] Dropped task ${task.id} after ${task.attempts} attempts: $e');
            }
          } else {
            // Exponential backoff before retrying queue
            if (kDebugMode) {
              debugPrint('[offline] Retry task ${task.id} attempt ${task.attempts}: $e');
            }
            await Future<void>.delayed(Duration(milliseconds: backoffMs));
            backoffMs = (backoffMs * 2).clamp(200, 4000);
          }
        }
      }
    });
  }

  // ------------- Freshness -------------

  /// Persist last online timestamp (called automatically on online transitions).
  Future<void> _setLastOnlineNow() async {
    _lastOnlineAt = DateTime.now();
    await LocalStorage.instance.setCacheTimestamp(_kLastOnlineTs, _lastOnlineAt!);
  }

  /// For stale-data logic: returns whether the last known online time exceeds maxAge.
  Future<bool> isStale(Duration maxAge) async {
    final ts = await LocalStorage.instance.getCacheTimestamp(_kLastOnlineTs);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }

  // ------------- Connectivity mapping -------------

  // New mapper for List<ConnectivityResult> per connectivity_plus v6+ API.
  void _updateStatusFromResults(List<ConnectivityResult> results) {
    final wasOnline = _status == NetworkStatus.online;

    // Treat a single [none] entry as offline; any other available type as online.
    // If empty, keep unknown to be conservative.
    if (results.isEmpty) {
      _status = NetworkStatus.unknown;
    } else if (results.contains(ConnectivityResult.none) && results.length == 1) {
      _status = NetworkStatus.offline;
    } else {
      _status = NetworkStatus.online;
    }

    _statusCtrl.add(_status);

    if (_status == NetworkStatus.online && !wasOnline) {
      // Record last-online time and try draining queue
      _setLastOnlineNow();
      if (!_offlineMode) _scheduleQueueDrain(immediate: true);
    }
  }
}
