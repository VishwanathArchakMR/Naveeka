// lib/ui/components/location/location_permission.dart

import 'package:flutter/material.dart';

/// High-level, UI-focused permission status for location.
/// Map plugin results (permission_handler/geolocator) into this model externally.
enum LocationPermissionUiStatus {
  notDetermined, // first-run, hasn't asked yet
  denied, // denied but can ask again
  deniedForever, // "Don't ask again" / iOS permanently denied
  restricted, // parental or device restrictions (iOS)
  servicesOff, // device location services disabled
  whileInUse, // foreground only
  always, // background allowed
}

/// Compact or full-size presentation.
enum LocationPermissionVariant { card, banner }

/// A Material 3 location permission component that shows the current state,
/// explains next steps, and offers actions to request or open settings.
/// - UI-only: callers provide callbacks to request and open settings
/// - Modern surfaces (surfaceContainerHighest) and Color.withValues for alpha
/// - Precise vs approximate hints supported via flags
class LocationPermissionView extends StatelessWidget {
  const LocationPermissionView({
    super.key,
    required this.status,
    this.preciseEnabled, // iOS 14+ precise toggle or Android 12+ approx
    this.backgroundNeeded = false,
    this.variant = LocationPermissionVariant.card,
    this.compact = false,
    this.onRequestWhileInUse,
    this.onRequestAlways,
    this.onOpenAppSettings,
    this.onOpenLocationServices,
    this.explanation,
  });

  /// Current UI-level status to render.
  final LocationPermissionUiStatus status;

  /// Whether precise location is enabled (if known).
  final bool? preciseEnabled;

  /// Whether the app feature needs background access (Always).
  final bool backgroundNeeded;

  /// Card or banner layout.
  final LocationPermissionVariant variant;

  /// Denser paddings and sizes for compact UIs.
  final bool compact;

  /// Callbacks to wire to permission flow in the app layer.
  final Future<void> Function()? onRequestWhileInUse;
  final Future<void> Function()? onRequestAlways;
  final Future<void> Function()? onOpenAppSettings;
  final Future<void> Function()? onOpenLocationServices;

  /// Optional additional explanation string.
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (IconData icon, String title, String message) = _copy(context);
    final List<Widget> actions = _actions(context);

    if (variant == LocationPermissionVariant.banner) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: cs.onSurfaceVariant, size: compact ? 18 : 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actions,
            ),
          ],
        ),
      );
    }

    // Card variant
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: cs.onSurfaceVariant, size: compact ? 18 : 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (explanation != null && explanation!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    explanation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, String) _copy(BuildContext context) {
    final bool? precise = preciseEnabled;

    switch (status) {
      case LocationPermissionUiStatus.servicesOff:
        return (
          Icons.location_disabled_rounded,
          'Turn on location services',
          'Device location is off; turn it on in system settings to enable map and nearby features.',
        );
      case LocationPermissionUiStatus.notDetermined:
        return (
          Icons.location_searching_rounded,
          'Allow location access',
          _needText(precise),
        );
      case LocationPermissionUiStatus.denied:
        return (
          Icons.lock_rounded,
          'Location permission needed',
          'Grant location while using the app to see nearby places and accurate distances.',
        );
      case LocationPermissionUiStatus.deniedForever:
        return (
          Icons.report_problem_rounded,
          'Permission blocked',
          'Location is blocked for this app; open App settings to enable access.',
        );
      case LocationPermissionUiStatus.restricted:
        return (
          Icons.shield_rounded,
          'Location restricted',
          'Location use is restricted by device policy; adjust settings or contact administrator.',
        );
      case LocationPermissionUiStatus.whileInUse:
        if (backgroundNeeded) {
          return (
            Icons.my_location_rounded,
            'Background access recommended',
            'Allow “Always” to keep routes and trip tracking updated even when the app is not open.',
          );
        }
        if (precise == false) {
          return (
            Icons.my_location_rounded,
            'Approximate location in use',
            'Enable precise location in App settings for better accuracy on maps and search.',
          );
        }
        return (
          Icons.my_location_rounded,
          'Location enabled',
          'Foreground access is granted; precise accuracy is active for best results.',
        );
      case LocationPermissionUiStatus.always:
        if (precise == false) {
          return (
            Icons.gps_fixed_rounded,
            'Always on (approximate)',
            'Background access is on; enable precise location in App settings for best accuracy.',
          );
        }
        return (
          Icons.gps_fixed_rounded,
          'Always on',
          'Background and precise access are enabled; location features are fully available.',
        );
    }
  }

  String _needText(bool? precise) {
    if (precise == false) {
      return 'Select precise location in the prompt to improve accuracy on maps and nearby places.';
    }
    return 'Allow location while using the app to show nearby places and accurate distances.';
  }

  List<Widget> _actions(BuildContext context) {
    final v = compact ? VisualDensity.compact : VisualDensity.standard;
    final List<Widget> buttons = <Widget>[];

    switch (status) {
      case LocationPermissionUiStatus.servicesOff:
        if (onOpenLocationServices != null) {
          buttons.add(FilledButton.tonalIcon(
            onPressed: onOpenLocationServices,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Location settings'),
            style: FilledButton.styleFrom(visualDensity: v),
          ));
        }
        break;

      case LocationPermissionUiStatus.notDetermined:
        if (onRequestWhileInUse != null) {
          buttons.add(FilledButton.tonal(
            onPressed: onRequestWhileInUse,
            style: FilledButton.styleFrom(visualDensity: v),
            child: const Text('Allow while using app'),
          ));
        }
        if (backgroundNeeded && onRequestAlways != null) {
          buttons.add(OutlinedButton(
            onPressed: onRequestAlways,
            style: OutlinedButton.styleFrom(visualDensity: v),
            child: const Text('Allow always'),
          ));
        }
        break;

      case LocationPermissionUiStatus.denied:
        if (onRequestWhileInUse != null) {
          buttons.add(FilledButton.tonal(
            onPressed: onRequestWhileInUse,
            style: FilledButton.styleFrom(visualDensity: v),
            child: const Text('Allow while using app'),
          ));
        }
        if (onOpenAppSettings != null) {
          buttons.add(OutlinedButton(
            onPressed: onOpenAppSettings,
            style: OutlinedButton.styleFrom(visualDensity: v),
            child: const Text('App settings'),
          ));
        }
        break;

      case LocationPermissionUiStatus.deniedForever:
        if (onOpenAppSettings != null) {
          buttons.add(FilledButton.tonalIcon(
            onPressed: onOpenAppSettings,
            icon: const Icon(Icons.app_settings_alt_rounded, size: 18),
            label: const Text('Open settings'),
            style: FilledButton.styleFrom(visualDensity: v),
          ));
        }
        break;

      case LocationPermissionUiStatus.restricted:
        if (onOpenAppSettings != null) {
          buttons.add(OutlinedButton(
            onPressed: onOpenAppSettings,
            style: OutlinedButton.styleFrom(visualDensity: v),
            child: const Text('App settings'),
          ));
        }
        break;

      case LocationPermissionUiStatus.whileInUse:
        if (backgroundNeeded && onRequestAlways != null) {
          buttons.add(FilledButton.tonal(
            onPressed: onRequestAlways,
            style: FilledButton.styleFrom(visualDensity: v),
            child: const Text('Allow always'),
          ));
        }
        if (preciseEnabled == false && onOpenAppSettings != null) {
          buttons.add(OutlinedButton(
            onPressed: onOpenAppSettings,
            style: OutlinedButton.styleFrom(visualDensity: v),
            child: const Text('Enable precise'),
          ));
        }
        break;

      case LocationPermissionUiStatus.always:
        if (preciseEnabled == false && onOpenAppSettings != null) {
          buttons.add(OutlinedButton(
            onPressed: onOpenAppSettings,
            style: OutlinedButton.styleFrom(visualDensity: v),
            child: const Text('Enable precise'),
          ));
        }
        break;
    }

    // Already applied visualDensity via styleFrom above.
    return buttons;
  }
}
