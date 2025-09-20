// lib/features/settings/presentation/widgets/privacy_security.dart

import 'package:flutter/material.dart';

/// Privacy & Security settings card:
/// - App Lock: in-app confirmation to “unlock” without external packages
/// - Screen Security: prevent screenshots/casting (hook up via platform integration)
/// - Data Controls: export data, clear histories, sign out all devices
/// - Danger Zone: delete account with confirmation
class PrivacySecurity extends StatefulWidget {
  const PrivacySecurity({
    super.key,
    this.sectionTitle = 'Privacy & security',

    // App lock
    required this.appLockEnabled,
    required this.requireOnLaunch,
    this.onAppLockChanged, // void Function(bool enabled)
    this.onRequireOnLaunchChanged, // void Function(bool require)
    this.onAppUnlockTest, // Future<bool> Function() to test unlock flow (optional)

    // Screen security (FLAG_SECURE on Android; iOS handled separately)
    required this.screenSecurityEnabled,
    this.onScreenSecurityChanged, // void Function(bool enabled)

    // Data controls
    this.onExportData, // Future<void> Function()
    this.onClearSearchHistory, // Future<void> Function()
    this.onClearLocationHistory, // Future<void> Function()
    this.onSignOutAllDevices, // Future<void> Function()

    // Danger zone
    this.onDeleteAccount, // Future<void> Function(String reason)
  });

  final String sectionTitle;

  // App lock
  final bool appLockEnabled;
  final bool requireOnLaunch;
  final ValueChanged<bool>? onAppLockChanged;
  final ValueChanged<bool>? onRequireOnLaunchChanged;
  final Future<bool> Function()? onAppUnlockTest;

  // Screen security
  final bool screenSecurityEnabled;
  final ValueChanged<bool>? onScreenSecurityChanged;

  // Data controls
  final Future<void> Function()? onExportData;
  final Future<void> Function()? onClearSearchHistory;
  final Future<void> Function()? onClearLocationHistory;
  final Future<void> Function()? onSignOutAllDevices;

  // Danger zone
  final Future<void> Function(String reason)? onDeleteAccount;

  @override
  State<PrivacySecurity> createState() => _PrivacySecurityState();
}

class _PrivacySecurityState extends State<PrivacySecurity> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Replaces local_auth with a simple confirmation sheet to simulate device auth.
  Future<bool> _authenticateBiometric() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirm identity', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Simulated device authentication'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).maybePop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).maybePop(true),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return res == true;
  }

  void _openAppLockSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AppLockSheet(
        enabled: widget.appLockEnabled,
        requireOnLaunch: widget.requireOnLaunch,
        onToggleEnabled: (v) async {
          setState(() => _busy = true);
          try {
            bool ok = true;
            if (v) {
              ok = await _authenticateBiometric();
            }
            if (ok) widget.onAppLockChanged?.call(v);
            if (ok && v && widget.onAppUnlockTest != null) {
              await widget.onAppUnlockTest!.call();
            }
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
        onToggleRequire: widget.onRequireOnLaunchChanged,
      ),
    );
  }

  void _openDeleteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DeleteAccountSheet(
        onConfirm: widget.onDeleteAccount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

            // App lock
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App lock', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const _LeadingIcon(icon: Icons.lock_outline),
                    title: Text(widget.appLockEnabled ? 'Enabled' : 'Disabled', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      'Use a confirmation to simulate device authentication',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: _busy ? null : _openAppLockSheet,
                      icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Configure'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Screen security
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Screen security', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Block screenshots & casting'),
                    subtitle: Text(
                      'Helps protect sensitive content in the app',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    value: widget.screenSecurityEnabled,
                    onChanged: widget.onScreenSecurityChanged,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'On Android, toggle FLAG_SECURE in platform code; iOS requires a different approach.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Data controls
            Text('Data controls', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _ActionTile(
              icon: Icons.download_outlined,
              title: 'Export my data',
              subtitle: 'Get a copy of account data via email',
              onTap: widget.onExportData,
            ),
            _ActionTile(
              icon: Icons.history_toggle_off,
              title: 'Clear search history',
              subtitle: 'Remove search suggestions and recent queries',
              onTap: widget.onClearSearchHistory,
            ),
            _ActionTile(
              icon: Icons.location_off_outlined,
              title: 'Clear location history',
              subtitle: 'Remove saved locations and traces',
              onTap: widget.onClearLocationHistory,
            ),
            _ActionTile(
              icon: Icons.logout,
              title: 'Sign out from all devices',
              subtitle: 'Invalidate all active sessions',
              onTap: widget.onSignOutAllDevices,
            ),

            const SizedBox(height: 12),

            // Danger zone
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.delete_forever_outlined, color: cs.error),
                ),
                title: const Text('Delete account', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Permanently remove account and data', style: TextStyle(color: cs.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openDeleteSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: cs.primary),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _LeadingIcon(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap == null
          ? null
          : () async {
              final messenger = ScaffoldMessenger.maybeOf(context); // capture before await
              await onTap!.call();
              messenger?.showSnackBar(SnackBar(content: Text('$title completed')));
            },
    );
  }
}

class _AppLockSheet extends StatefulWidget {
  const _AppLockSheet({
    required this.enabled,
    required this.requireOnLaunch,
    required this.onToggleEnabled,
    required this.onToggleRequire,
  });

  final bool enabled;
  final bool requireOnLaunch;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<bool>? onToggleRequire;

  @override
  State<_AppLockSheet> createState() => _AppLockSheetState();
}

class _AppLockSheetState extends State<_AppLockSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                const Expanded(child: Text('App lock', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable lock'),
              subtitle: Text('Require confirmation to unlock the app', style: TextStyle(color: cs.onSurfaceVariant)),
              trailing: Switch.adaptive(
                value: widget.enabled,
                onChanged: (v) => widget.onToggleEnabled(v),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require on launch'),
              subtitle: Text('Ask to unlock every time the app opens', style: TextStyle(color: cs.onSurfaceVariant)),
              trailing: Switch.adaptive(
                value: widget.requireOnLaunch,
                onChanged: widget.onToggleRequire,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This demo uses an in-app confirmation instead of biometrics to keep code dependency-free.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.onConfirm});
  final Future<void> Function(String reason)? onConfirm;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _reason = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                const Expanded(child: Text('Delete account', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: _busy || _confirm.text.trim().toUpperCase() != 'DELETE'
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        bool success = false;
                        try {
                          if (widget.onConfirm != null) {
                            await widget.onConfirm!.call(_reason.text.trim());
                          }
                          success = true;
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                            if (success) {
                              // Use State.context under a mounted check, not the captured build() context.
                              Navigator.maybePop(this.context);
                            }
                          }
                        }
                      },
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_forever),
                label: const Text('Delete account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
