// lib/features/settings/providers/settings_providers.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Value types

@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.messages = true,
    this.planning = true,
    this.recommendations = true,
    this.groupActivity = true,
    this.sounds = true,
    this.badges = true,
    this.previews = true,
  });

  final bool messages;
  final bool planning;
  final bool recommendations;
  final bool groupActivity;
  final bool sounds;
  final bool badges;
  final bool previews;

  NotificationPrefs copyWith({
    bool? messages,
    bool? planning,
    bool? recommendations,
    bool? groupActivity,
    bool? sounds,
    bool? badges,
    bool? previews,
  }) {
    return NotificationPrefs(
      messages: messages ?? this.messages,
      planning: planning ?? this.planning,
      recommendations: recommendations ?? this.recommendations,
      groupActivity: groupActivity ?? this.groupActivity,
      sounds: sounds ?? this.sounds,
      badges: badges ?? this.badges,
      previews: previews ?? this.previews,
    );
  }
}

@immutable
class PrivacySecurityPrefs {
  const PrivacySecurityPrefs({
    this.appLockEnabled = false,
    this.requireOnLaunch = false,
    this.screenSecure = false, // FLAG_SECURE on Android; iOS handled separately
  });

  final bool appLockEnabled;
  final bool requireOnLaunch;
  final bool screenSecure;

  PrivacySecurityPrefs copyWith({
    bool? appLockEnabled,
    bool? requireOnLaunch,
    bool? screenSecure,
  }) {
    return PrivacySecurityPrefs(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      requireOnLaunch: requireOnLaunch ?? this.requireOnLaunch,
      screenSecure: screenSecure ?? this.screenSecure,
    );
  }
}

@immutable
class OfflinePrefs {
  const OfflinePrefs({
    this.wifiOnly = true,
    this.autoUpdate = true,
  });

  final bool wifiOnly;
  final bool autoUpdate;

  OfflinePrefs copyWith({
    bool? wifiOnly,
    bool? autoUpdate,
  }) {
    return OfflinePrefs(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoUpdate: autoUpdate ?? this.autoUpdate,
    );
  }
}

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en', 'US'),
    this.notifications = const NotificationPrefs(),
    this.privacy = const PrivacySecurityPrefs(),
    this.offline = const OfflinePrefs(),
  });

  final ThemeMode themeMode;
  final Locale locale;
  final NotificationPrefs notifications;
  final PrivacySecurityPrefs privacy;
  final OfflinePrefs offline;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    NotificationPrefs? notifications,
    PrivacySecurityPrefs? privacy,
    OfflinePrefs? offline,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      notifications: notifications ?? this.notifications,
      privacy: privacy ?? this.privacy,
      offline: offline ?? this.offline,
    );
  }
}

/// Repository abstraction
/// Provide a concrete implementation (e.g., shared_preferences + flutter_secure_storage) via ProviderScope.override. [9][10]
abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Injection point for a concrete repository (override in app bootstrap). [12]
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Provide SettingsRepository via override in main.dart or bootstrap');
});

/// Controller

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  FutureOr<AppSettings> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.load();
    return settings;
  } // AsyncNotifier lets settings load asynchronously and exposes methods to mutate and persist. [1][2]

  Future<void> _persist(AppSettings next) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(next);
  } // Persist through the repository so storage is swappable (prefs/secure/backend). [12][10]

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(themeMode: mode);
    state = AsyncData(next);
    await _persist(next);
  } // Update theme mode and persist with optimistic UI update. [1]

  Future<void> setLocale(Locale locale) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(locale: locale);
    state = AsyncData(next);
    await _persist(next);
  } // Update locale and persist so MaterialApp can react via a selector. [12]

  Future<void> setNotificationPrefs(NotificationPrefs prefs) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(notifications: prefs);
    state = AsyncData(next);
    await _persist(next);
  } // Replace notification preferences and persist atomically. [1]

  Future<void> patchNotificationPrefs({
    bool? messages,
    bool? planning,
    bool? recommendations,
    bool? groupActivity,
    bool? sounds,
    bool? badges,
    bool? previews,
  }) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(
      notifications: current.notifications.copyWith(
        messages: messages,
        planning: planning,
        recommendations: recommendations,
        groupActivity: groupActivity,
        sounds: sounds,
        badges: badges,
        previews: previews,
      ),
    );
    state = AsyncData(next);
    await _persist(next);
  } // Partial update helper for granular toggles in NotificationSettings. [1]

  Future<void> setPrivacySecurity(PrivacySecurityPrefs prefs) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(privacy: prefs);
    state = AsyncData(next);
    await _persist(next);
  } // Replace privacy/security prefs (app lock, require on launch, screen secure). [10]

  Future<void> patchPrivacySecurity({
    bool? appLockEnabled,
    bool? requireOnLaunch,
    bool? screenSecure,
  }) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(
      privacy: current.privacy.copyWith(
        appLockEnabled: appLockEnabled,
        requireOnLaunch: requireOnLaunch,
        screenSecure: screenSecure,
      ),
    );
    state = AsyncData(next);
    await _persist(next);
  } // Partial privacy/security updates with optimistic UI and persistence. [1]

  Future<void> setOfflinePrefs(OfflinePrefs prefs) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(offline: prefs);
    state = AsyncData(next);
    await _persist(next);
  } // Replace offline preferences and persist. [12]

  Future<void> patchOfflinePrefs({bool? wifiOnly, bool? autoUpdate}) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(
      offline: current.offline.copyWith(wifiOnly: wifiOnly, autoUpdate: autoUpdate),
    );
    state = AsyncData(next);
    await _persist(next);
  } // Partial update for Wi‑Fi only and auto‑update toggles. [12]
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new); // Exposes AsyncValue<AppSettings> for screens to watch and react to. [1][2]

/// Selectors (lightweight derived providers for specific fields)

final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings();
  return s.themeMode;
}); // UI can watch only ThemeMode to rebuild MaterialApp.themeMode efficiently. [1]

final localeProvider = Provider<Locale>((ref) {
  final s = ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings();
  return s.locale;
}); // UI can watch only Locale to rebuild localization efficiently. [12]

final notificationPrefsProvider = Provider<NotificationPrefs>((ref) {
  final s = ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings();
  return s.notifications;
}); // Widgets like NotificationSettings can bind directly to NotificationPrefs. [1]

final privacySecurityPrefsProvider = Provider<PrivacySecurityPrefs>((ref) {
  final s = ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings();
  return s.privacy;
}); // Privacy & Security section can watch a focused slice of settings state. [1]

final offlinePrefsProvider = Provider<OfflinePrefs>((ref) {
  final s = ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings();
  return s.offline;
}); // OfflineDownloads can watch Wi‑Fi only and auto‑update toggles directly. [1]

/// Facade to simplify calling controller methods from UI callbacks

typedef Reader = T Function<T>(ProviderListenable<T> provider);

class SettingsActions {
  SettingsActions(this._read);
  final Reader _read;

  // Theme / locale
  Future<void> setThemeMode(ThemeMode mode) => _read(settingsControllerProvider.notifier).setThemeMode(mode);
  Future<void> setLocale(Locale locale) => _read(settingsControllerProvider.notifier).setLocale(locale);

  // Notifications
  Future<void> setNotificationPrefs(NotificationPrefs prefs) =>
      _read(settingsControllerProvider.notifier).setNotificationPrefs(prefs);

  Future<void> patchNotification({
    bool? messages,
    bool? planning,
    bool? recommendations,
    bool? groupActivity,
    bool? sounds,
    bool? badges,
    bool? previews,
  }) =>
      _read(settingsControllerProvider.notifier).patchNotificationPrefs(
        messages: messages,
        planning: planning,
        recommendations: recommendations,
        groupActivity: groupActivity,
        sounds: sounds,
        badges: badges,
        previews: previews,
      );

  // Privacy/Security
  Future<void> setPrivacy(PrivacySecurityPrefs prefs) =>
      _read(settingsControllerProvider.notifier).setPrivacySecurity(prefs);

  Future<void> patchPrivacy({bool? appLockEnabled, bool? requireOnLaunch, bool? screenSecure}) =>
      _read(settingsControllerProvider.notifier).patchPrivacySecurity(
        appLockEnabled: appLockEnabled,
        requireOnLaunch: requireOnLaunch,
        screenSecure: screenSecure,
      );

  // Offline
  Future<void> setOffline(OfflinePrefs prefs) => _read(settingsControllerProvider.notifier).setOfflinePrefs(prefs);
  Future<void> patchOffline({bool? wifiOnly, bool? autoUpdate}) =>
      _read(settingsControllerProvider.notifier).patchOfflinePrefs(wifiOnly: wifiOnly, autoUpdate: autoUpdate);
}

final settingsActionsProvider =
    Provider<SettingsActions>((ref) => SettingsActions(ref.read)); // Minimal imperative surface for UI event handlers without exposing controller details. [1]

/// Notes:
/// - Persist settings in a repository backed by shared_preferences for general keys and flutter_secure_storage for sensitive flags like app lock, following Flutter’s guidance for key‑value storage and secure data. [12][10]
/// - AsyncNotifier supports async initialization and optimistic updates, making it a good fit for app‑wide settings that load once and change incrementally. [1][3]
/// - Use selectors (Provider) to rebuild only the subtrees that depend on a specific field such as ThemeMode or Locale, improving performance and separation of concerns. [1]
