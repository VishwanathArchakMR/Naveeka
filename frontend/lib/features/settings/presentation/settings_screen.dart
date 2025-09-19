// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';

// Widgets (already implemented in your project)
import 'widgets/profile_header.dart';
import 'widgets/settings_side_sheet.dart';
import 'widgets/language_theme_settings.dart';
import 'widgets/notification_settings.dart';
import 'widgets/location_settings.dart';
import 'widgets/offline_downloads.dart';
import 'widgets/help_support.dart';
import 'widgets/privacy_security.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mocked state to demonstrate wiring; replace with real app state/providers.
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en', 'US');
  final _locales = const <Locale>[
    Locale('en', 'US'),
    Locale('hi', 'IN'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
  ];

  bool _notifMessages = true;
  bool _notifPlanning = true;
  bool _notifRecs = true;
  bool _notifGroup = true;
  bool _notifSounds = true;
  bool _notifBadges = true;
  bool _notifPreviews = true;

  final bool _locationServiceEnabled = false; // display only; managed by Geolocator externally
  bool _appLockEnabled = false;
  bool _appLockRequireOnLaunch = false;
  bool _screenSecure = false;

  bool _wifiOnly = true;
  bool _autoUpdate = true;

  // Storage mock
  int _bytesUsed = 280 * 1024 * 1024; // 280 MB
  final int _bytesCap = 8 * 1024 * 1024 * 1024; // 8 GB

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            children: [
              // Header
              ProfileHeader(
                displayName: 'Navee Traveler',
                handleOrEmail: '@navee_traveler',
                avatarUrl: null,
                verified: true,
                followersCount: 1240,
                followingCount: 310,
                favoritesCount: 86,
                onEditProfile: () => _openSideSheet(
                  title: 'Edit profile',
                  child: _placeholder('Connect your profile editor here.'),
                ),
                onOpenFollowers: () => _openSideSheet(
                  title: 'Followers',
                  child: _placeholder('Show followers list here.'),
                ),
                onOpenFollowing: () => _openSideSheet(
                  title: 'Following',
                  child: _placeholder('Show following list here.'),
                ),
                onOpenFavorites: () => _openSideSheet(
                  title: 'Favorites',
                  child: _placeholder('Show favorites here.'),
                ),
                onPickFromCamera: () async {},
                onPickFromGallery: () async {},
                onRemovePhoto: () async {},
              ),

              const SizedBox(height: 12),

              // Sections opener card
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _SectionTile(
                      icon: Icons.color_lens_outlined,
                      title: 'Language & theme',
                      subtitle: 'App language, light/dark mode',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Language & theme',
                        builder: (_) => LanguageThemeSettings(
                          currentThemeMode: _themeMode,
                          onThemeModeChanged: (m) => setState(() => _themeMode = m),
                          supportedLocales: _locales,
                          currentLocale: _locale,
                          onLocaleChanged: (l) => setState(() => _locale = l),
                          localeDisplayName: (l) => _localeName(l),
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    _SectionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notifications',
                      subtitle: 'Permissions, categories, sounds',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Notifications',
                        builder: (_) => NotificationSettings(
                          messagesEnabled: _notifMessages,
                          planningEnabled: _notifPlanning,
                          recommendationsEnabled: _notifRecs,
                          groupActivityEnabled: _notifGroup,
                          soundsEnabled: _notifSounds,
                          badgesEnabled: _notifBadges,
                          previewsEnabled: _notifPreviews,
                          onMessagesChanged: (v) => setState(() => _notifMessages = v),
                          onPlanningChanged: (v) => setState(() => _notifPlanning = v),
                          onRecommendationsChanged: (v) => setState(() => _notifRecs = v),
                          onGroupActivityChanged: (v) => setState(() => _notifGroup = v),
                          onSoundsChanged: (v) => setState(() => _notifSounds = v),
                          onBadgesChanged: (v) => setState(() => _notifBadges = v),
                          onPreviewsChanged: (v) => setState(() => _notifPreviews = v),
                          onRequestPermission: () async {
                            // Wire to FirebaseMessaging.instance.requestPermission or permission_handler.
                            return true;
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    _SectionTile(
                      icon: Icons.my_location,
                      title: 'Location',
                      subtitle: 'Permissions, accuracy, services',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Location',
                        builder: (_) => LocationSettings(
                          onPermissionChanged: (_) async {
                            // Reconfigure listeners after changes.
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    _SectionTile(
                      icon: Icons.https_outlined,
                      title: 'Privacy & security',
                      subtitle: 'App lock, screen security, data controls',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Privacy & security',
                        builder: (_) => PrivacySecurity(
                          appLockEnabled: _appLockEnabled,
                          requireOnLaunch: _appLockRequireOnLaunch,
                          onAppLockChanged: (v) => setState(() => _appLockEnabled = v),
                          onRequireOnLaunchChanged: (v) => setState(() => _appLockRequireOnLaunch = v),
                          onAppUnlockTest: () async => true,
                          screenSecurityEnabled: _screenSecure,
                          onScreenSecurityChanged: (v) => setState(() => _screenSecure = v),
                          onExportData: () async {},
                          onClearSearchHistory: () async {},
                          onClearLocationHistory: () async {},
                          onSignOutAllDevices: () async {},
                          onDeleteAccount: (reason) async {},
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    _SectionTile(
                      icon: Icons.download_for_offline_outlined,
                      title: 'Offline downloads',
                      subtitle: 'Wi‑Fi only, auto‑update, manage items',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Offline downloads',
                        builder: (_) => OfflineDownloads(
                          totalBytesUsed: _bytesUsed,
                          totalBytesCapacity: _bytesCap,
                          wifiOnly: _wifiOnly,
                          autoUpdate: _autoUpdate,
                          items: const <OfflineItem>[],
                          onToggleWifiOnly: (v) => setState(() => _wifiOnly = v),
                          onToggleAutoUpdate: (v) => setState(() => _autoUpdate = v),
                          onAddNew: () {},
                          onRemoveAll: () async {
                            setState(() => _bytesUsed = 0);
                          },
                          onPickQuality: (q) async {},
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    _SectionTile(
                      icon: Icons.support_agent,
                      title: 'Help & support',
                      subtitle: 'Contact, FAQs, policies',
                      onTap: () => SettingsSideSheet.showAdaptive(
                        context: context,
                        title: 'Help & support',
                        builder: (_) => HelpSupport(
                          supportEmail: 'support@navee.app',
                          supportPhone: '+1 555 0100',
                          faqs: const [
                            (q: 'How to plan a trip?', a: 'Use Plan with Navee AI or Planning search.'),
                            (q: 'How to invite friends?', a: 'Open a trip group and tap Invite.'),
                          ],
                          privacyUrl: Uri.parse('https://example.com/privacy'),
                          termsUrl: Uri.parse('https://example.com/terms'),
                          onSubmitReport: (title, desc, includeDiag) async {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About card
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.info_outline, color: cs.primary),
                  ),
                  title: const Text('About'),
                  subtitle: Text('Version 1.0.0 (100)', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localeName(Locale l) {
    final lang = l.languageCode.toUpperCase();
    final c = (l.countryCode ?? '').toUpperCase();
    return c.isEmpty ? lang : '$lang – $c';
  }

  Future<void> _openSideSheet({required String title, required Widget child}) {
    return SettingsSideSheet.showAdaptive(
      context: context,
      title: title,
      builder: (_) => child,
    );
  }

  Widget _placeholder(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: cs.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
