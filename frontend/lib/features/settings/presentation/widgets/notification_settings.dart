// lib/features/settings/presentation/widgets/notification_settings.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// A compact settings card for notifications:
/// - Shows OS permission status and opens app notification settings if required
/// - Requests permission with permission_handler (Android 13+/iOS/macOS)
/// - Per-category switches: Messages, Planning, Recommendations, Group activity
/// - Preference toggles: Sounds, Badges, Previews
/// - Uses Color.withValues (no withOpacity) and const where possible
class NotificationSettings extends StatefulWidget {
  const NotificationSettings({
    super.key,
    this.sectionTitle = 'Notifications',

    // Current values (bind to app state)
    this.messagesEnabled = true,
    this.planningEnabled = true,
    this.recommendationsEnabled = true,
    this.groupActivityEnabled = true,
    this.soundsEnabled = true,
    this.badgesEnabled = true,
    this.previewsEnabled = true,

    // Callbacks to persist changes
    this.onMessagesChanged,
    this.onPlanningChanged,
    this.onRecommendationsChanged,
    this.onGroupActivityChanged,
    this.onSoundsChanged,
    this.onBadgesChanged,
    this.onPreviewsChanged,

    // Optional custom permission/request handlers if app uses FCM or another SDK
    this.onRequestPermission, // Future<bool> Function()
    this.onOpenAppSettings,   // Future<void> Function()
  });

  final String sectionTitle;

  final bool messagesEnabled;
  final bool planningEnabled;
  final bool recommendationsEnabled;
  final bool groupActivityEnabled;

  final bool soundsEnabled;
  final bool badgesEnabled;
  final bool previewsEnabled;

  final ValueChanged<bool>? onMessagesChanged;
  final ValueChanged<bool>? onPlanningChanged;
  final ValueChanged<bool>? onRecommendationsChanged;
  final ValueChanged<bool>? onGroupActivityChanged;

  final ValueChanged<bool>? onSoundsChanged;
  final ValueChanged<bool>? onBadgesChanged;
  final ValueChanged<bool>? onPreviewsChanged;

  final Future<bool> Function()? onRequestPermission;
  final Future<void> Function()? onOpenAppSettings;

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> with WidgetsBindingObserver {
  bool _busy = false;
  PermissionStatus _status = PermissionStatus.denied;

  // Local mirrors for UI switches
  late bool _messages;
  late bool _planning;
  late bool _recs;
  late bool _group;
  late bool _sounds;
  late bool _badges;
  late bool _previews;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messages = widget.messagesEnabled;
    _planning = widget.planningEnabled;
    _recs = widget.recommendationsEnabled;
    _group = widget.groupActivityEnabled;
    _sounds = widget.soundsEnabled;
    _badges = widget.badgesEnabled;
    _previews = widget.previewsEnabled;
    _refreshPermission();
  }

  @override
  void didUpdateWidget(covariant NotificationSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep switches in sync with upstream changes
    _messages = widget.messagesEnabled;
    _planning = widget.planningEnabled;
    _recs = widget.recommendationsEnabled;
    _group = widget.groupActivityEnabled;
    _sounds = widget.soundsEnabled;
    _badges = widget.badgesEnabled;
    _previews = widget.previewsEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When coming back from system settings, re-check permission
    if (state == AppLifecycleState.resumed) {
      _refreshPermission();
    }
  }

  Future<void> _refreshPermission() async {
    final s = await Permission.notification.status;
    if (!mounted) return;
    setState(() => _status = s);
  } // permission_handler exposes a cross-platform API to query notification permission status. [13][19]

  Future<void> _openAppSettings() async {
    if (widget.onOpenAppSettings != null) {
      await widget.onOpenAppSettings!.call();
    } else {
      await openAppSettings();
    }
  } // openAppSettings deep-links to the app’s settings screen for notifications where users can manually enable permissions. [13][16]

  Future<bool> _requestPermission() async {
    setState(() => _busy = true);
    try {
      if (widget.onRequestPermission != null) {
        final ok = await widget.onRequestPermission!.call();
        await _refreshPermission();
        return ok;
      }
      // Native permission dialog on iOS/macOS and Android 13+, or immediate grant on older Android if not disabled
      final res = await Permission.notification.request();
      await _refreshPermission();
      return res.isGranted;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  } // Requesting notifications permission is required on iOS/macOS and Android 13+, and permission_handler can perform this request. [13][7]

  void _openWhySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WhyNotificationsSheet(
        status: _status,
        onRequest: _requestPermission,
        onOpenSettings: _openAppSettings,
      ),
    );
  } // Rounded modal bottom sheets are the Material pattern for focused, transient permission rationale flows. [21]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final granted = _status.isGranted;
    final permanentlyDenied = _status.isPermanentlyDenied;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),

            // Permission status block
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  _StatusRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Permission',
                    value: _labelFor(_status),
                    valueColor: granted
                        ? Colors.green
                        : (permanentlyDenied ? Colors.orange : cs.onSurfaceVariant),
                    onTap: permanentlyDenied ? _openAppSettings : _openWhySheet,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Categories
            const _SectionHeader(text: 'Categories'),
            _SwitchTile(
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              value: _messages,
              onChanged: (v) {
                setState(() => _messages = v);
                widget.onMessagesChanged?.call(v);
              },
            ),
            _SwitchTile(
              icon: Icons.event_note_outlined,
              title: 'Planning',
              value: _planning,
              onChanged: (v) {
                setState(() => _planning = v);
                widget.onPlanningChanged?.call(v);
              },
            ),
            _SwitchTile(
              icon: Icons.thumb_up_off_alt,
              title: 'Recommendations',
              value: _recs,
              onChanged: (v) {
                setState(() => _recs = v);
                widget.onRecommendationsChanged?.call(v);
              },
            ),
            _SwitchTile(
              icon: Icons.groups_outlined,
              title: 'Group activity',
              value: _group,
              onChanged: (v) {
                setState(() => _group = v);
                widget.onGroupActivityChanged?.call(v);
              },
            ),

            const SizedBox(height: 12),

            // Preferences
            const _SectionHeader(text: 'Preferences'),
            _SwitchTile(
              icon: Icons.volume_up_outlined,
              title: 'Sounds',
              value: _sounds,
              onChanged: (v) {
                setState(() => _sounds = v);
                widget.onSoundsChanged?.call(v);
              },
            ),
            _SwitchTile(
              icon: Icons.circle_notifications_outlined,
              title: 'Badges',
              value: _badges,
              onChanged: (v) {
                setState(() => _badges = v);
                widget.onBadgesChanged?.call(v);
              },
            ),
            _SwitchTile(
              icon: Icons.visibility_outlined,
              title: 'Show previews',
              value: _previews,
              onChanged: (v) {
                setState(() => _previews = v);
                widget.onPreviewsChanged?.call(v);
              },
            ),

            const SizedBox(height: 12),

            // Footer actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _refreshPermission,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            if (permanentlyDenied) {
                              _openAppSettings();
                            } else {
                              _openWhySheet();
                            }
                          },
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.notifications_active),
                    label: Text(granted ? 'Manage settings' : 'Enable notifications'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(PermissionStatus s) {
    if (s.isGranted) return 'Allowed';
    if (s.isDenied) return 'Denied';
    if (s.isPermanentlyDenied) return 'Denied forever';
    if (s.isLimited) return 'Limited';
    if (s.isRestricted) return 'Restricted';
    return 'Unknown';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700)),
      ),
      onTap: onTap,
    );
  }
}

class _WhyNotificationsSheet extends StatelessWidget {
  const _WhyNotificationsSheet({
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final PermissionStatus status;
  final Future<bool> Function() onRequest;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isForever = status.isPermanentlyDenied;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Turn on notifications', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Get message alerts, planning updates, and important reminders directly on the device.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isForever ? null : () async {
                      final ok = await onRequest();
                      if (ok && context.mounted) Navigator.maybePop(context);
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Allow'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('App settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
