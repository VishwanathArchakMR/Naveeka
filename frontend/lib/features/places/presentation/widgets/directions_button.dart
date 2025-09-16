// lib/features/places/presentation/widgets/directions_button.dart

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/place.dart';

/// Supported travel modes recognized by Google Maps URLs and Apple/Google schemes. [1]
enum TravelMode { driving, walking, transit, bicycling }

/// A primary button to open directions in the native maps app (Google/Apple), with sensible fallbacks to universal Maps URLs. [1][12]
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

  /// Convenience factory to use with your app's Place model. [12]
  factory DirectionsButton.fromPlace(
    Place p, {
    Key? key,
    TravelMode mode = TravelMode.driving,
    String label = 'Directions',
    bool expanded = true,
    bool showPicker = false,
  }) {
    return DirectionsButton(
      key: key,
      lat: p.lat,
      lng: p.lng,
      destinationLabel: p.name,
      mode: mode,
      label: label,
      expanded: expanded,
      showPicker: showPicker,
    );
  }

  final double? lat;
  final double? lng;

  /// Optional text label for the origin/destination if not using coordinates. [1]
  final String? originLabel;
  final String? destinationLabel;

  final TravelMode mode;

  /// Button label/icon and layout. [21]
  final String label;
  final IconData icon;
  final bool expanded;

  /// If true, shows a bottom-sheet to choose app (Apple/Google/Browser) before launching. [22]
  final bool showPicker;

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) return const SizedBox.shrink(); // Defensive early-return for missing coordinates. [10]

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
          ); // Material buttons provide clear affordances and accessibility for actions like opening directions. [21]

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
    ); // A shaped modal bottom-sheet gives a focused app selection surface and returns choice via Navigator.pop. [22]

    if (choice == null) return;
    switch (choice) {
      case _TargetApp.apple:
        await _launchApple(context);
        break;
      case _TargetApp.google:
        await _launchGoogle(context, preferAppScheme: true);
        break;
      case _TargetApp.browser:
        await _launchGoogle(context, preferAppScheme: false);
        break;
    }
  }

  Future<void> _launchPreferred(BuildContext context) async {
    // On iOS: prefer comgooglemaps:// if installed; else Apple Maps (maps.apple.com). [2][12]
    // On other platforms: universal Google Maps URLs; fall back to web if needed. [1]
    if (Platform.isIOS) {
      final ok = await _launchGoogle(context, preferAppScheme: true);
      if (ok) return;
      final ok2 = await _launchApple(context);
      if (ok2) return;
      final ok3 = await _launchGoogle(context, preferAppScheme: false);
      if (ok3) return;
    } else {
      final ok = await _launchGoogle(context, preferAppScheme: false);
      if (ok) return;
      final ok2 = await _launchGeoFallback(context);
      if (ok2) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open directions'))); // Graceful fallback message if all attempts fail. [21]
    }
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

  Future<bool> _launchGoogle(BuildContext context, {required bool preferAppScheme}) async {
    final dest = destinationLabel?.trim().isNotEmpty == true
        ? destinationLabel!.trim()
        : '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}'; // Google Maps URLs accept text or coordinates for destination. [1]

    final origin = originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : null; // Optional origin lets Maps infer current location if omitted. [1]

    // App scheme (iOS): comgooglemaps://?saddr=...&daddr=...&directionsmode=... [2]
    final appUri = Uri.parse(
      'comgooglemaps://?${origin != null ? 'saddr=${Uri.encodeComponent(origin)}&' : ''}'
      'daddr=${Uri.encodeComponent(dest)}&directionsmode=${_modeParam()}',
    );

    // Universal web URL (cross-platform): https://www.google.com/maps/dir/?api=1&destination=...&origin=...&travelmode=... [1]
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(dest)}'
      '${origin != null ? '&origin=${Uri.encodeComponent(origin)}' : ''}'
      '&travelmode=${_modeParam()}',
    );

    final candidates = <Uri>[
      if (preferAppScheme) appUri,
      webUri,
    ]; // Ordered attempts: app scheme (iOS), then universal web URL. [2][1]

    for (final u in candidates) {
      if (await canLaunchUrl(u)) {
        final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    }
    return false;
  }

  // --------- Apple Maps (web URL usable on iOS/macOS) ---------

  Future<bool> _launchApple(BuildContext context) async {
    final dest = destinationLabel?.trim().isNotEmpty == true
        ? destinationLabel!.trim()
        : '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}'; // Apple Maps web URL accepts address text or "lat,lng". [12][6]

    final origin = originLabel?.trim().isNotEmpty == true ? originLabel!.trim() : null; // If omitted, Maps can default to current location. [12]

    // Apple Maps web URL (documented map links): https://maps.apple.com/?daddr=...&saddr=...&dirflg=... [12]
    final modeFlag = _appleModeFlag(); // Convert to Apple dirflg param.
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
    // Apple dirflg values are often b (bus/transit), d (driving), w (walking); bicycling may not be supported via dirflg everywhere. [12][18]
    switch (mode) {
      case TravelMode.driving:
        return 'd';
      case TravelMode.walking:
        return 'w';
      case TravelMode.transit:
        return 'r'; // Some docs use 'r' for transit in older references; Apple’s web links accept transport hints via args. [12]
      case TravelMode.bicycling:
        return null; // Not consistently supported; fallback without flag. [12]
    }
  }

  // --------- Geo URI fallback ---------

  Future<bool> _launchGeoFallback(BuildContext context) async {
    // geo:lat,lng — generic mapping URI some Android apps handle; not universal, but a reasonable last fallback. [10][13]
    final geo = Uri.parse('geo:${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}');
    if (await canLaunchUrl(geo)) {
      return await launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

enum _TargetApp { apple, google, browser }
