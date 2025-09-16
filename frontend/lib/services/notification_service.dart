// lib/services/notification_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// High-level categories for routing and analytics.
enum NotificationKind {
  system,
  chat,
  message,
  trip,
  booking,
  review,
  place,
  restaurant,
  landmark,
  hotel,
  flight,
  train,
  bus,
  trailPost,
  user,
  other,
}

/// Permission states kept generic across Android/iOS.
enum NotificationPermissionStatus {
  granted,
  provisional, // iOS provisional
  denied,
  deniedForever, // Android "blocked" / iOS "notAllowed"
  unknown,
}

/// Android channel importance abstraction.
enum NotificationImportance {
  none,
  min,
  low,
  defaultImportance,
  high,
}

/// Configure an Android notification channel (API 26+).
@immutable
class NotificationChannelConfig {
  const NotificationChannelConfig({
    required this.id,
    required this.name,
    this.description,
    this.importance = NotificationImportance.defaultImportance,
    this.showBadge = true,
    this.sound = true,
    this.vibrate = true,
  });

  final String id;
  final String name;
  final String? description;
  final NotificationImportance importance;
  final bool showBadge;
  final bool sound;
  final bool vibrate;
}

/// Immutable push token model for server registration.
@immutable
class PushToken {
  const PushToken({
    required this.value,
    required this.platform, // 'android' | 'ios' | 'web'
    required this.updatedAt,
  });

  final String value;
  final String platform;
  final DateTime updatedAt;

  PushToken copyWith({String? value, String? platform, DateTime? updatedAt}) {
    return PushToken(
      value: value ?? this.value,
      platform: platform ?? this.platform,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A normalized notification payload used throughout the app.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    this.title,
    this.body,
    this.kind = NotificationKind.other,
    this.topic,
    this.channelId,
    this.imageUrl,
    this.badge,
    this.sound,
    this.deepLink,
    this.data = const <String, String>{},
    required this.receivedAt,
  });

  final String id;
  final String? title;
  final String? body;
  final NotificationKind kind;
  final String? topic;
  final String? channelId;
  final String? imageUrl;
  final int? badge;
  final String? sound;
  final String? deepLink; // e.g., myapp://place/123 or https://...
  final Map<String, String> data;
  final DateTime receivedAt;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationKind? kind,
    String? topic,
    String? channelId,
    String? imageUrl,
    int? badge,
    String? sound,
    String? deepLink,
    Map<String, String>? data,
    DateTime? receivedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      topic: topic ?? this.topic,
      channelId: channelId ?? this.channelId,
      imageUrl: imageUrl ?? this.imageUrl,
      badge: badge ?? this.badge,
      sound: sound ?? this.sound,
      deepLink: deepLink ?? this.deepLink,
      data: data ?? this.data,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}

/// Remote push provider contract (e.g., Firebase Messaging).
abstract class PushProvider {
  Future<void> initialize({Future<void> Function(AppNotification message)? backgroundHandler});

  Future<NotificationPermissionStatus> checkPermission();

  Future<NotificationPermissionStatus> requestPermission({bool provisional = false});

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> deleteToken();

  Future<void> subscribeTopic(String topic);

  Future<void> unsubscribeTopic(String topic);

  /// Foreground messages while the app is visible.
  Stream<AppNotification> get onMessage;

  /// Taps when the app is opened from a notification.
  Stream<AppNotification> get onMessageOpenedApp;
}

/// Local notifications provider contract (e.g., flutter_local_notifications).
abstract class LocalNotificationsProvider {
  Future<void> initialize({
    List<NotificationChannelConfig> androidChannels = const <NotificationChannelConfig>[],
    Future<void> Function(AppNotification message)? onSelectNotification,
  });

  Future<void> showNow({
    required int id,
    required AppNotification message,
    String? androidChannelId,
  });

  Future<void> scheduleAt({
    required int id,
    required AppNotification message,
    required DateTime when,
    String? androidChannelId,
    bool allowWhileIdle = true,
    String? timeZone, // optional TZ database name if supported by adapter
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

/// High-level notification service that composes push + local providers.
class NotificationService {
  // Simple singleton for app-wide access
  static final NotificationService instance = NotificationService();

  NotificationService({
    PushProvider? pushProvider,
    LocalNotificationsProvider? localProvider,
  })  : _push = pushProvider,
        _local = localProvider;

  final PushProvider? _push;
  final LocalNotificationsProvider? _local;

  /// Optional top-level initializer used by the app bootstrap.
  /// If using specific providers, prefer calling initPush/initLocal instead.
  Future<void> init() async {
    // No-op by default. Hook up providers here if desired.
  }

  // ------------- Push (remote) -------------

  Future<void> initPush({Future<void> Function(AppNotification message)? backgroundHandler}) async {
    if (_push == null) return;
    await _push!.initialize(backgroundHandler: backgroundHandler);
  }

  Future<NotificationPermissionStatus> checkPushPermission() async {
    if (_push == null) return NotificationPermissionStatus.unknown;
    return _push!.checkPermission();
  }

  Future<NotificationPermissionStatus> requestPushPermission({bool provisional = false}) async {
    if (_push == null) return NotificationPermissionStatus.unknown;
    return _push!.requestPermission(provisional: provisional);
  }

  Future<String?> getPushToken() async {
    if (_push == null) return null;
    return _push!.getToken();
  }

  Stream<String> get onPushTokenRefresh => _push?.onTokenRefresh ?? const Stream.empty();

  Future<void> deletePushToken() async {
    if (_push == null) return;
    await _push!.deleteToken();
  }

  Future<void> subscribeTopic(String topic) async {
    if (_push == null) return;
    await _push!.subscribeTopic(topic);
  }

  Future<void> unsubscribeTopic(String topic) async {
    if (_push == null) return;
    await _push!.unsubscribeTopic(topic);
  }

  Stream<AppNotification> get onForegroundMessage => _push?.onMessage ?? const Stream.empty();

  Stream<AppNotification> get onOpenedAppMessage => _push?.onMessageOpenedApp ?? const Stream.empty();

  // ------------- Local (device) -------------

  Future<void> initLocal({
    List<NotificationChannelConfig> androidChannels = const <NotificationChannelConfig>[],
    Future<void> Function(AppNotification message)? onSelectNotification,
  }) async {
    if (_local == null) return;
    await _local!.initialize(androidChannels: androidChannels, onSelectNotification: onSelectNotification);
  }

  Future<void> showLocalNow({
    required int id,
    required AppNotification message,
    String? androidChannelId,
  }) async {
    if (_local == null) return;
    await _local!.showNow(id: id, message: message, androidChannelId: androidChannelId ?? message.channelId);
  }

  Future<void> scheduleLocalAt({
    required int id,
    required AppNotification message,
    required DateTime when,
    String? androidChannelId,
    bool allowWhileIdle = true,
    String? timeZone,
  }) async {
    if (_local == null) return;
    await _local!.scheduleAt(
      id: id,
      message: message,
      when: when,
      androidChannelId: androidChannelId ?? message.channelId,
      allowWhileIdle: allowWhileIdle,
      timeZone: timeZone,
    );
  }

  Future<void> cancelLocal(int id) async {
    if (_local == null) return;
    await _local!.cancel(id);
  }

  Future<void> cancelAllLocal() async {
    if (_local == null) return;
    await _local!.cancelAll();
  }
}

/// Convenience mappers for Android importance to numeric levels if adapters need them.
extension NotificationImportanceX on NotificationImportance {
  int get androidLevel {
    switch (this) {
      case NotificationImportance.none:
        return 0;
      case NotificationImportance.min:
        return 1;
      case NotificationImportance.low:
        return 2;
      case NotificationImportance.defaultImportance:
        return 3;
      case NotificationImportance.high:
        return 4;
    }
  }
}

