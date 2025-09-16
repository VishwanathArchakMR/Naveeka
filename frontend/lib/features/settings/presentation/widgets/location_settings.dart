// lib/features/settings/presentation/widgets/location_settings.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Compact settings card to manage location access:
/// - Shows service state (GPS on/off) and current permission status
/// - Requests permission and opens system settings when needed
/// - Uses a rounded bottom sheet to explain why location is helpful
/// - Uses Color.withValues (no withOpacity) and const where possible
class LocationSettings extends StatefulWidget {
  const LocationSettings({
    super.key,
    this.sectionTitle = 'Location settings',
    this.onPermissionChanged, // void Function(LocationPermission permission)
  });

  final String sectionTitle;
  final void Function(LocationPermission permission)? onPermissionChanged;

  @override
  State<LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<LocationSettings> {
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final service = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _serviceEnabled = service;
      _permission = perm;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    try {
      // If already denied, request via Geolocator requestPermission
      // Geolocator exposes checkPermission and requestPermission across iOS/Android. [1]
      final next = await Geolocator.requestPermission();
      if (!mounted) return;
      setState(() => _permission = next);
      widget.onPermissionChanged?.call(next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLocationSettings() async {
    // Opens OS location services settings (e.g., enable GPS). [1]
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    // Opens this app's settings page to change permission if permanently denied. [1]
    await Geolocator.openAppSettings();
  }

  void _openWhySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WhyLocationSheet(
        onRequest: _requestPermission,
        onOpenSettings: _openAppSettings,
      ),
    ); // Rounded modal bottom sheets are the Material pattern for focused, transient flows. [10][7]
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final serviceText = _serviceEnabled ? 'On' : 'Off';
    final permText = _permissionLabel(_permission);
    final needsSettings = _permission == LocationPermission.deniedForever;

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

            // Status block
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
                    icon: Icons.location_searching,
                    label: 'Location services',
                    value: serviceText,
                    valueColor: _serviceEnabled ? Colors.green : cs.onSurfaceVariant,
                    onTap: _openLocationSettings,
                  ),
                  const Divider(height: 12),
                  _StatusRow(
                    icon: Icons.my_location,
                    label: 'Permission',
                    value: permText,
                    valueColor: _permColor(cs, _permission),
                    onTap: needsSettings ? _openAppSettings : _requestPermission,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _refreshStatus(),
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
                            if (_permission == LocationPermission.denied || _permission == LocationPermission.deniedForever) {
                              _openWhySheet(context);
                            } else {
                              _openLocationSettings();
                            }
                          },
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.security_update_good),
                    label: Text(
                      (_permission == LocationPermission.denied || _permission == LocationPermission.deniedForever)
                          ? 'Enable access'
                          : 'Improve accuracy',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _permColor(ColorScheme cs, LocationPermission p) {
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return Colors.orange;
    if (p == LocationPermission.whileInUse || p == LocationPermission.always) return Colors.green;
    return cs.onSurfaceVariant;
  }

  String _permissionLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied forever';
      case LocationPermission.whileInUse:
        return 'While in use';
      case LocationPermission.always:
        return 'Always';
      case LocationPermission.unableToDetermine:
        return 'Unknown';
    }
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

class _WhyLocationSheet extends StatelessWidget {
  const _WhyLocationSheet({required this.onRequest, required this.onOpenSettings});

  final Future<void> Function() onRequest;
  final Future<void> Function() onOpenSettings;

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
                const Expanded(child: Text('Enable location', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Location improves nearby suggestions, trip planning, and map accuracy.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Allow access'),
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
    ); // showModalBottomSheet is the standard Material API for modal sheets with safe-area handling. [10][7]
  }
}
