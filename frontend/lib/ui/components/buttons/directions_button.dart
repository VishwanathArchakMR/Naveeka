// lib/ui/components/buttons/directions_button.dart

import 'package:flutter/material.dart';

import '../../../models/coordinates.dart';

/// Preferred mapping app strategy when generating direction links. [3]
enum DirectionsAppPreference {
  system,     // try Google, then Apple, then geo
  google,     // use Google Maps URL first
  apple,      // use Apple Maps URL first
  geoOnly,    // only build geo: URI
}

/// Travel mode mapping to URL parameters for Google/Apple. [3][15]
enum DirectionsMode { driving, walking, bicycling, transit }

/// A compact Material 3 button that opens turn-by-turn directions
/// in an external maps app using platform-friendly URL schemes. [3]
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({
    super.key,
    required this.destination,
    this.origin,
    this.mode = DirectionsMode.driving,
    this.label = 'Directions',
    this.icon,
    this.tooltip,
    this.appPreference = DirectionsAppPreference.system,
    this.onLaunchUri, // plug url_launcher or a custom launcher
    this.onResolveUris, // observe or customize which URIs are generated
    this.style,
    this.compact = false,
  });

  /// Required destination coordinate. [3]
  final Coordinates destination;

  /// Optional origin coordinate; if null, the maps app may use “current location”. [3]
  final Coordinates? origin;

  /// Travel mode for the route. [3][15]
  final DirectionsMode mode;

  /// Visible label text. [3]
  final String label;

  /// Optional leading icon; defaults to directions icon. [3]
  final Widget? icon;

  /// Optional tooltip when long-pressing or hovering. [3]
  final String? tooltip;

  /// Preferred app strategy for building URIs. [3][15]
  final DirectionsAppPreference appPreference;

  /// Provide a launcher callback like `launchUrl` to keep UI decoupled from plugins. [1]
  final Future<bool> Function(Uri uri)? onLaunchUri;

  /// Observe or override the generated URI list before launching. [2]
  final void Function(List<Uri> uris)? onResolveUris;

  /// Optional button style. [3]
  final ButtonStyle? style;

  /// If true, renders a denser button variant. [3]
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon ??
            const Icon(
              Icons.directions_rounded,
              size: 20,
            ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final btn = FilledButton(
      style: style ??
          FilledButton.styleFrom(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: compact
                ? Theme.of(context).textTheme.labelLarge
                : Theme.of(context).textTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      onPressed: () async {
        final uris = _buildUris(appPreference, origin, destination, mode);
        onResolveUris?.call(uris);
        // If a launcher is provided, attempt in order; stop on first success.
        if (onLaunchUri != null && uris.isNotEmpty) {
          for (final u in uris) {
            try {
              final ok = await onLaunchUri!(u);
              if (ok) break;
            } catch (_) {
              // try next URI
            }
          }
        }
      },
      child: buttonChild,
    );

    if (tooltip != null && tooltip!.trim().isNotEmpty) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }

  // ---------- URI builders (Google, Apple, geo) ----------

  List<Uri> _buildUris(
    DirectionsAppPreference pref,
    Coordinates? from,
    Coordinates to,
    DirectionsMode mode,
  ) {
    final google = _googleDirections(from: from, to: to, mode: mode);
    final apple = _appleDirections(from: from, to: to, mode: mode);
    final geo = _geoUri(to);

    switch (pref) {
      case DirectionsAppPreference.system:
        // A pragmatic order: Google universal URL, Apple Maps URL, then geo: scheme.
        return <Uri>[google, apple, geo];
      case DirectionsAppPreference.google:
        return <Uri>[google, apple, geo];
      case DirectionsAppPreference.apple:
        return <Uri>[apple, google, geo];
      case DirectionsAppPreference.geoOnly:
        return <Uri>[geo];
    }
  }

  // Google universal URL: https://www.google.com/maps/dir/?api=1&origin=lat,lng&destination=lat,lng&travelmode=driving [3]
  Uri _googleDirections({
    Coordinates? from,
    required Coordinates to,
    required DirectionsMode mode,
  }) {
    final params = <String, String>{
      'api': '1',
      'destination': '${to.latitude},${to.longitude}',
      'travelmode': _googleMode(mode),
    };
    if (from != null) {
      params['origin'] = '${from.latitude},${from.longitude}';
    }
    return Uri.https('www.google.com', '/maps/dir/', params);
  }

  String _googleMode(DirectionsMode m) {
    switch (m) {
      case DirectionsMode.driving:
        return 'driving';
      case DirectionsMode.walking:
        return 'walking';
      case DirectionsMode.bicycling:
        return 'bicycling';
      case DirectionsMode.transit:
        return 'transit';
    }
  }

  // Apple Maps unified URL: https://maps.apple.com/?daddr=lat,lng&saddr=lat,lng&dirflg=d|w|r [15]
  Uri _appleDirections({
    Coordinates? from,
    required Coordinates to,
    required DirectionsMode mode,
  }) {
    final params = <String, String>{
      'daddr': '${to.latitude},${to.longitude}',
      'dirflg': _appleFlag(mode),
    };
    if (from != null) {
      params['saddr'] = '${from.latitude},${from.longitude}';
    }
    return Uri.https('maps.apple.com', '/', params);
  }

  String _appleFlag(DirectionsMode m) {
    // Apple dirflg: d=driving, w=walking, r=transit. [15]
    switch (m) {
      case DirectionsMode.driving:
        return 'd';
      case DirectionsMode.walking:
        return 'w';
      case DirectionsMode.transit:
        return 'r';
      case DirectionsMode.bicycling:
        // Apple Maps may not support bicycling flag; fall back to driving.
        return 'd';
    }
  }

  // geo URI fallback: geo:lat,lng?q=lat,lng (labels optional, support varies) [10][7]
  Uri _geoUri(Coordinates to) {
    // Example: geo:12.34,56.78?q=12.34,56.78
    final query = '${to.latitude},${to.longitude}';
    return Uri.parse('geo:${to.latitude},${to.longitude}?q=$query');
  }
}
