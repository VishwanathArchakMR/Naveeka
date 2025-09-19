// lib/features/places/presentation/widgets/directions_button.dart

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported travel modes recognized by Google Maps URLs and Apple/Google schemes.
enum TravelMode { driving, walking, transit, bicycling }

/// A primary button to open directions in the native maps app (Google/Apple),
/// with sensible fallbacks to universal Maps URLs.
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({
    super.key,
    required this.lat,
    required this.lng,
    this.originLabel,
    this.destinationLabel,
    this.mode = TravelMode.driving,
    this.label = 'Directions',
    this.icon = Icons.directions_outlined,
    this.expanded = true,
    this.showPicker = false,
  });

  /// Convenience factory to use with any place-like model or Map.
  /// Tries common field names to extract lat/lng and name.
  factory DirectionsButton.fromPlace(
    dynamic p, {
    Key? key,
    TravelMode mode = TravelMode.driving,
    String label = 'Directions',
    bool expanded = true,
    bool showPicker = false,
  }) {
    String? _str(dynamic v) => v == null ? null : v.toString();
    double? _num(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    T? _get<T>(List<String> names) {
      for (final n in names) {
        // property access
        try {
          final v = (p as dynamic).noSuchMethod ? null : (p as dynamic).__getattr__ ; // placeholder to satisfy analyzer
        } catch (_) {}
        // map access
        if (p is Map) {
          final v = p[n];
          if (v is T) return v;
          if (T == String && v != null) return _str(v) as T?;
          if (T == double && v != null) return _num(v) as T?;
        }
      }
      return null;
    }

    // Since using reflection-like property access isn’t available, prefer map keys and typical fields via try/catch.
    double? lat;
    double? lng;
    String? name;

    try {
      lat = _num((p as dynamic).lat);
    } catch (_) {}
    try {
      lng = _num((p as dynamic).lng);
    } catch (_) {}
    try {
      name = _str((p as dynamic).name);
    } catch (_) {}

    lat ??= _get<double>(['lat', 'latitude']);
    lng ??= _get<double>(['lng', 'long', 'longitude', 'lon']);
    name ??= _get<String>(['name', 'title', 'label']);

    return DirectionsButton(
      key: key,
      lat: lat,
      lng: lng,
      destinationLabel: name,
      mode: mode,
      label: label,
      expanded: expanded,
      showPicker: showPicker,
    );
  }

  final double? lat;
  final double? lng;

  /// Optional text label for the origin/destination if not using coordinates.
  final String? originLabel;
  final String? destinationLabel;

  final TravelMode mode;

  /// Button label/icon and layout.
  final String label;
  final IconData icon;
  final bool expanded;

  /// If true, shows a bottom-sheet to choose app (Apple/Google/Browser) before launching.
  final bool showPicker;

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) return const SizedBox.shrink();

    final button = expanded
        ? FilledButton.icon(
            onPressed: () => _go(context),
            icon: Icon(icon),
            label: Text(label),
          )
        : IconButton(
            tooltip: label,
            onPressed: () => _go(context),
            icon: Icon(icon),
          );

    return button;
  }

  Future<void> _go(BuildContext context) async {
    if (showPicker) {
      await _pickAppAndLaunch(context);
      return;
    }
    await _launchPreferred(context);
  }

  Future<void> _pickAppAndLaunch(BuildContext context) async {
    final choice = await showModalBottomSheet<_TargetApp>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Apple Maps'),
                onTap: () => Navigator.of(ctx).maybePop(_TargetApp.apple),
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Google Maps'),
                onTap: () => Navigator.of(ctx).maybePop(_TargetApp.google),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Open in browser'),
                onTap: () => Navigator.of(ctx).maybePop(_TargetApp.browser),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (choice == null) return;
    switch (choice) {
      case _TargetApp.apple:
        await _launchApple();
        break;
      case _TargetApp.google:
        await _launchGoogle(preferAppScheme: true);
        break;
      case _TargetApp.browser:
        await _launchGoogle(preferAppScheme: false);
        break;
    }
  }

  Future<void> _launchPreferred(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // On iOS: prefer comgooglemaps:// if installed; else Apple Maps; else web Google Maps.
    // On other platforms: web Google Maps; else geo: fallback.
    if (Platform.isIOS) {
      final ok = await _launchGoogle(preferAppScheme: true);
      if (ok) return;
      final ok2 = await _launchApple();
      if (ok2) return;
      final ok3 = await _launchGoogle(preferAppScheme: false);
      if (ok3) return;
    } else {
      final ok = await _launchGoogle(preferAppScheme: false);
      if (ok) return;
      final ok2 = await _launchGeoFallback();
      if (ok2) return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Could not open directions'))); // Use captured messenger, no context after awaits. [web:5680][web:5873]
  }

  String _modeParam() {
    switch (mode) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'walking';
      case TravelMode.transit:
        return 'transit';
      case TravelMode.bicycling:
        return 'bicycling';
    }
  }

  // --------- Google Maps (iOS scheme + universal URLs) ---------

  Future<bool> _launchGoogle({required bool preferAppScheme}) async {
    final dest = destinationLabel?.trim().isNotEmpty == true
        ? destinationLabel!.trim()
        : '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}';

    final origin = originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : null;

    // App scheme (iOS): comgooglemaps://?saddr=...&daddr=...&directionsmode=...
    final appUri = Uri.parse(
      'comgooglemaps://?${origin != null ? 'saddr=${Uri.encodeComponent(origin)}&' : ''}'
      'daddr=${Uri.encodeComponent(dest)}&directionsmode=${_modeParam()}',
    );

    // Universal web URL: https://www.google.com/maps/dir/?api=1&destination=...&origin=...&travelmode=...
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(dest)}'
      '${origin != null ? '&origin=${Uri.encodeComponent(origin)}' : ''}'
      '&travelmode=${_modeParam()}',
    );

    final candidates = <Uri>[
      if (preferAppScheme) appUri,
      webUri,
    ];

    for (final u in candidates) {
      if (await canLaunchUrl(u)) {
        final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    }
    return false;
  }

  // --------- Apple Maps (web URL usable on iOS/macOS) ---------

  Future<bool> _launchApple() async {
    final dest = destinationLabel?.trim().isNotEmpty == true
        ? destinationLabel!.trim()
        : '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}';

    final origin = originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : null;

    // Apple Maps web URL: https://maps.apple.com/?daddr=...&saddr=...&dirflg=...
    final modeFlag = _appleModeFlag();
    final appleWeb = Uri.parse(
      'https://maps.apple.com/?daddr=${Uri.encodeComponent(dest)}'
      '${origin != null ? '&saddr=${Uri.encodeComponent(origin)}' : ''}'
      '${modeFlag != null ? '&dirflg=$modeFlag' : ''}',
    );

    if (await canLaunchUrl(appleWeb)) {
      return await launchUrl(appleWeb, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  String? _appleModeFlag() {
    // Apple dirflg: d (driving), w (walking), r (transit); bicycling not consistently supported.
    switch (mode) {
      case TravelMode.driving:
        return 'd';
      case TravelMode.walking:
        return 'w';
      case TravelMode.transit:
        return 'r';
      case TravelMode.bicycling:
        return null;
    }
  }

  // --------- Geo URI fallback ---------

  Future<bool> _launchGeoFallback() async {
    // geo:lat,lng — generic mapping URI some Android apps handle.
    final geo = Uri.parse('geo:${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}');
    if (await canLaunchUrl(geo)) {
      return await launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

enum _TargetApp { apple, google, browser }
