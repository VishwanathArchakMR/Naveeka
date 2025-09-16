// lib/features/quick_actions/presentation/planning/widgets/location_picker.dart

import 'package:flutter/material.dart';

/// Minimal point representation for selection results.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Optional address label for the selected location.
class LocationPickResult {
  const LocationPickResult({
    required this.point,
    this.label,
    this.radiusKm,
  });

  final GeoPoint point;
  final String? label;
  final double? radiusKm;
}

/// Pluggable map contract (Google/Mapbox) reused across the app.
/// If a central definition already exists, import that instead of redefining here.
typedef NearbyMapBuilder = Widget Function(BuildContext context, NearbyMapConfig config);

class NearbyMapConfig {
  const NearbyMapConfig({
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    this.initialZoom = 13,
    this.onMarkerTap,
    this.onRecenter,
  });

  final double centerLat;
  final double centerLng;
  final List<NearbyMarker> markers;
  final double initialZoom;
  final void Function(String id)? onMarkerTap;
  final VoidCallback? onRecenter;
}

class NearbyMarker {
  const NearbyMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.selected = false,
    this.icon,
  });

  final String id;
  final double lat;
  final double lng;
  final bool selected;
  final String? icon;
}

/// A compact button that opens a location picker sheet.
class LocationPickerButton extends StatelessWidget {
  const LocationPickerButton({
    super.key,
    required this.onPick, // Future<void> Function(LocationPickResult)
    this.label = 'Pick location',
    this.icon = Icons.add_location_alt_outlined,
    this.initialCenter,
    this.mapBuilder,
    this.onResolveCurrent, // Future<GeoPoint?> Function()
    this.onSearch, // Future<List<LocationSuggestion>> Function(String query)
    this.showRadius = false,
    this.initialRadiusKm = 2.0,
  });

  final Future<void> Function(LocationPickResult result) onPick;
  final String label;
  final IconData icon;

  final GeoPoint? initialCenter;
  final NearbyMapBuilder? mapBuilder;

  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onSearch;

  final bool showRadius;
  final double initialRadiusKm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: () async {
        final res = await LocationPickerSheet.show(
          context,
          initialCenter: initialCenter,
          mapBuilder: mapBuilder,
          onResolveCurrent: onResolveCurrent,
          onSearch: onSearch,
          showRadius: showRadius,
          initialRadiusKm: initialRadiusKm,
        );
        if (res != null) {
          await onPick(res);
        }
      },
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

/// A suggestion row returned from onSearch.
class LocationSuggestion {
  const LocationSuggestion({
    required this.title,
    required this.point,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final GeoPoint point;
}

/// The rounded modal sheet location picker with map + search + radius.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    this.initialCenter,
    this.mapBuilder,
    this.onResolveCurrent,
    this.onSearch,
    this.showRadius = false,
    this.initialRadiusKm = 2.0,
  });

  final GeoPoint? initialCenter;
  final NearbyMapBuilder? mapBuilder;

  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onSearch;

  final bool showRadius;
  final double initialRadiusKm;

  static Future<LocationPickResult?> show(
    BuildContext context, {
    GeoPoint? initialCenter,
    NearbyMapBuilder? mapBuilder,
    Future<GeoPoint?> Function()? onResolveCurrent,
    Future<List<LocationSuggestion>> Function(String q)? onSearch,
    bool showRadius = false,
    double initialRadiusKm = 2.0,
  }) {
    return showModalBottomSheet<LocationPickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LocationPickerSheet(
          initialCenter: initialCenter,
          mapBuilder: mapBuilder,
          onResolveCurrent: onResolveCurrent,
          onSearch: onSearch,
          showRadius: showRadius,
          initialRadiusKm: initialRadiusKm,
        ),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _q = TextEditingController();
  final _scroll = ScrollController();

  GeoPoint? _center; // map camera center (selection)
  String? _label;

  bool _busyCurrent = false;
  bool _busySearch = false;
  List<LocationSuggestion> _results = const [];

  double _radiusKm = 2.0;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _useCurrent() async {
    if (widget.onResolveCurrent == null) return;
    setState(() => _busyCurrent = true);
    try {
      final p = await widget.onResolveCurrent!.call();
      if (p != null && mounted) {
        setState(() {
          _center = p;
          _label = 'Current location';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location captured')));
      }
    } finally {
      if (mounted) setState(() => _busyCurrent = false);
    }
  }

  Future<void> _runSearch(String q) async {
    if (widget.onSearch == null) return;
    setState(() {
      _busySearch = true;
      _results = const [];
    });
    try {
      final items = await widget.onSearch!.call(q.trim());
      if (mounted) setState(() => _results = items);
    } finally {
      if (mounted) setState(() => _busySearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Pick a location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _runSearch(v),
                decoration: InputDecoration(
                  hintText: 'Search for a place or address',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busySearch
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_q.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _q.clear();
                                setState(() => _results = const []);
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surface.withValues(alpha: 1.0),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Map area (pluggable)
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildMapOrPlaceholder(context),
                  ),
                  // Center pin overlay
                  if (_center != null)
                    const IgnorePointer(
                      child: Center(
                        child: Icon(Icons.location_pin, size: 40, color: Colors.red),
                      ),
                    ),
                  // Controls: current & recenter
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        Material(
                          color: cs.surface.withValues(alpha: 1.0),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Use current location',
                            icon: _busyCurrent
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location),
                            onPressed: _busyCurrent ? null : _useCurrent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Optional radius
            if (widget.showRadius) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    const Text('Radius', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _radiusKm >= 10 ? '${_radiusKm.toStringAsFixed(0)} km' : '${_radiusKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Slider(
                  value: _radiusKm,
                  min: 0.5,
                  max: 50,
                  divisions: 495,
                  label: '${_radiusKm.toStringAsFixed(_radiusKm >= 10 ? 0 : 1)} km',
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
              ),
            ],

            // Results list (tap to set center)
            if (_results.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final r = _results[i];
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
                        child: Icon(Icons.place_outlined, color: cs.primary),
                      ),
                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: (r.subtitle ?? '').trim().isEmpty ? null : Text(r.subtitle!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        setState(() {
                          _center = r.point;
                          _label = r.title;
                        });
                        // Also scroll map into view
                        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                      },
                    );
                  },
                ),
              )
            else
              const SizedBox(height: 8),

            // Confirm bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _center == null
                          ? 'No location selected'
                          : (_label?.trim().isNotEmpty == true
                              ? _label!.trim()
                              : '${_center!.lat.toStringAsFixed(5)}, ${_center!.lng.toStringAsFixed(5)}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _center == null ? cs.onSurfaceVariant : cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _center == null
                        ? null
                        : () {
                            Navigator.of(context).maybePop(
                              LocationPickResult(
                                point: _center!,
                                label: _label,
                                radiusKm: widget.showRadius ? _radiusKm : null,
                              ),
                            );
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Use'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapOrPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.mapBuilder == null) {
      return Container(
        color: cs.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, size: 40, color: Colors.black26),
            SizedBox(height: 8),
            Text('Map unavailable', style: TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }

    final c = _center ?? const GeoPoint(20.0, 0.0); // default world-ish center
    final markers = <NearbyMarker>[
      if (_center != null)
        NearbyMarker(
          id: 'sel',
          lat: _center!.lat,
          lng: _center!.lng,
          selected: true,
        ),
    ];

    return widget.mapBuilder!(
      context,
      NearbyMapConfig(
        centerLat: c.lat,
        centerLng: c.lng,
        markers: markers,
        initialZoom: 13,
        onMarkerTap: (id) {
          // No-op in picker; selection is driven by results/current pin
        },
        onRecenter: () {
          // If your map builder exposes camera target readbacks, wire it here to update _center.
          // For this abstract builder, keep as a no-op.
        },
      ),
    );
  }
}
