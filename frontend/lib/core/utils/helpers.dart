// lib/core/utils/helpers.dart

import 'dart:async';
import 'dart:math' as math;

/// --------------- Safe parse ---------------

double? tryParseDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int? tryParseInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool? tryParseBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
  }
  return null;
}

/// --------------- String utils ---------------

bool isNullOrEmpty(String? s) => s == null || s.isEmpty;

String? nullIfEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

String truncate(String s, int maxChars, {String ellipsis = '…'}) {
  if (maxChars <= 0) return '';
  if (s.length <= maxChars) return s;
  if (maxChars <= ellipsis.length) return ellipsis.substring(0, maxChars);
  return s.substring(0, maxChars - ellipsis.length) + ellipsis;
}

/// --------------- Collection helpers ---------------

List<T> uniqueBy<T, K>(Iterable<T> items, K Function(T) keyOf) {
  final seen = <K>{};
  final out = <T>[];
  for (final item in items) {
    final k = keyOf(item);
    if (seen.add(k)) out.add(item);
  }
  return out;
}

List<List<T>> chunk<T>(List<T> items, int size) {
  if (size <= 0) return [items];
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, math.min(i + size, items.length)));
  }
  return out;
}

Map<K, V> mergeMaps<K, V>(Map<K, V> a, Map<K, V> b, {bool override = true}) {
  final out = Map<K, V>.from(a);
  b.forEach((k, v) {
    if (override || !out.containsKey(k)) out[k] = v;
  });
  return out;
}

/// --------------- Debounce & Throttle (callback-based) ---------------
/// These are intentionally dependency-free; use RxDart/stream_transform if you need stream transformers. [1][2]

class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isActive => _timer?.isActive == true;
}

class Throttler {
  Throttler({this.interval = const Duration(milliseconds: 300)});

  final Duration interval;
  DateTime? _last;
  Timer? _trailingTimer;

  /// Leading-edge throttle with optional trailing execution if calls arrive during the interval. [5]
  void call(VoidCallback action, {bool trailing = true}) {
    final now = DateTime.now();
    if (_last == null || now.difference(_last!) >= interval) {
      _last = now;
      action();
      _trailingTimer?.cancel();
    } else if (trailing) {
      _trailingTimer?.cancel();
      final wait = interval - now.difference(_last!);
      _trailingTimer = Timer(wait, () {
        _last = DateTime.now();
        action();
      });
    }
  }

  void cancel() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
  }
}

/// --------------- Retry with exponential backoff ---------------
/// Lightweight retry utility without extra packages; for more control, consider a dedicated backoff package. [9][12]

typedef AsyncTask<T> = Future<T> Function();
typedef RetryIf = bool Function(Object error);

Future<T> retryAsync<T>(
  AsyncTask<T> task, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 200),
  double multiplier = 2.0,
  Duration? maxDelay,
  RetryIf? retryIf,
  void Function(int attempt, Object error)? onRetry,
}) async {
  assert(maxAttempts >= 1, 'maxAttempts must be >= 1');
  var attempt = 0;
  var delay = initialDelay;

  while (true) {
    attempt += 1;
    try {
      return await task();
    } catch (e) {
      final shouldRetry = attempt < maxAttempts && (retryIf?.call(e) ?? true);
      if (!shouldRetry) rethrow;

      onRetry?.call(attempt, e);
      await Future<void>.delayed(delay);
      final nextMillis = (delay.inMilliseconds * multiplier).round();
      delay = Duration(milliseconds: nextMillis);
      if (maxDelay != null && delay > maxDelay) delay = maxDelay;
    }
  }
}
