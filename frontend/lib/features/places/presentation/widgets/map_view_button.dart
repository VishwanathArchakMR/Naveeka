// lib/features/places/presentation/widgets/map_view_button.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/place.dart';

/// A button that opens a full-screen map page (Navigator.push) or, if no builder
/// is provided, launches the location in an external maps app/browser. [1][6]
class MapViewButton extends StatelessWidget {
  const MapViewButton({
    super.key,
    required this.lat,
    required this.lng,
    this.title = 'Map view',
    this.label = 'Map view',
    this.icon = Icons.map_outlined,
    this.extended = false,
    this.mapBuilder,
  });

  /// Convenience factory for your Place model.
  factory MapViewButton.fromPlace(
    Place place, {
    Key? key,
    String title = 'Map view',
    String label = 'Map view',
    IconData icon = Icons.map_outlined,
    bool extended = false,
    WidgetBuilder? mapBuilder,
  }) {
    // Try to obtain a JSON map view of the model for flexible field access.
    Map<String, dynamic> j = const <String, dynamic>{};
    try {
      final dyn = place as dynamic;
      final m = dyn.toJson();
      if (m is Map) {
        j = Map<String, dynamic>.from(m);
      }
    } catch (_) {
      // ignore if toJson isn't present
    }

    double? parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final double? lat = parseDouble(j['lat'] ?? j['latitude']);
    final double? lng = parseDouble(j['lng'] ?? j['long'] ?? j['longitude'] ?? j['lon']);

    return MapViewButton(
      key: key,
      lat: lat,
      lng: lng,
      title: title,
      label: label,
      icon: icon,
      extended: extended,
      mapBuilder: mapBuilder,
    );
  }

  final double? lat;
  final double? lng;

  /// AppBar title for the pushed map page.
  final String title;

  /// Button label and icon.
  final String label;
  final IconData icon;
  final bool extended;

  /// Optional builder to render a map widget inside the pushed page.
  /// If null, the button will open an external maps URL as fallback. [6]
  final WidgetBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) return const SizedBox.shrink();

    Future<void> onPress() => _openMap(context);

    return extended
        ? FilledButton.icon(
            onPressed: onPress,
            icon: Icon(icon),
            label: Text(label),
          )
        : IconButton(
            tooltip: label,
            onPressed: onPress,
            icon: Icon(icon),
          );
  }

  Future<void> _openMap(BuildContext context) async {
    // Prefer an in-app map page if a builder is provided, else open maps URL. [1][6]
    if (mapBuilder != null) {
      // Push a full-screen page that hosts the provided map widget. [1][2]
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapViewPage(
            title: title,
            builder: mapBuilder!,
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map')));
    }
  }
}

/// A simple full-screen page with an AppBar that hosts a provided map widget.
/// Use any map widget inside (e.g., GoogleMap, MapboxMap, or a custom map). [2]
class MapViewPage extends StatelessWidget {
  const MapViewPage({
    super.key,
    required this.title,
    required this.builder,
    this.fab,
  });

  final String title;
  final WidgetBuilder builder;

  /// Optional floating action button (e.g., recenter, layers).
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    // Standard Navigator push target with AppBar + body content. [1][2]
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Builder(builder: builder),
      floatingActionButton: fab,
    );
  }
}
