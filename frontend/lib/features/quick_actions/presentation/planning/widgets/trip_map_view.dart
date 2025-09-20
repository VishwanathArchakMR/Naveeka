// lib/features/quick_actions/presentation/planning/widgets/trip_map_view.dart

import 'package:flutter/material.dart';

// Reuse the shared pluggable map contract from the location picker to keep integrations consistent.
import './location_picker.dart'; // NearbyMapBuilder, NearbyMapConfig, NearbyMarker, GeoPoint

/// A waypoint/stop in the trip shown on the map.
class TripMapStop {
  const TripMapStop({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    this.subtitle,
    this.dayIndex, // 1-based day index; null = unassigned
    this.icon, // optional semantic icon name for your map style
  });

  final String id;
  final double lat;
  final double lng;
  final String title;
  final String? subtitle;
  final int? dayIndex;
  final String? icon;
}

/// A full-bleed trip map view with:
/// - Pluggable map (Google/Mapbox) via NearbyMapBuilder
/// - Day filter chips
/// - Tappable markers that show a bottom peek card
/// - Top-right actions (recenter, toggle path hint)
/// - Uses Color.withValues (no withOpacity) and const where possible
class TripMapView extends StatefulWidget {
  const TripMapView({
    super.key,
    required this.stops,
    this.mapBuilder,
    this.center,
    this.height = 420,
    this.onOpenStop, // void Function(TripMapStop)
    this.onDirections, // Future<void> Function(TripMapStop)
    this.polylinesSupported = false, // if mapBuilder supports path lines externally
    this.dayFilter, // initial selected day; null = All
  });

  final List<TripMapStop> stops;
  final NearbyMapBuilder? mapBuilder;

  /// Optional camera center override; defaults to centroid of stops.
  final GeoPoint? center;

  final double height;

  final void Function(TripMapStop stop)? onOpenStop;
  final Future<void> Function(TripMapStop stop)? onDirections;

  /// If true, the host map builder draws path polylines (e.g., via directions API) outside this widget.
  final bool polylinesSupported;

  /// Initial selected day; null = All.
  final int? dayFilter;

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  String? _selectedId;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.dayFilter;
  }

  @override
  void didUpdateWidget(covariant TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayFilter != widget.dayFilter) {
      _selectedDay = widget.dayFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final stops = widget.stops.where((s) => s.lat.isFinite && s.lng.isFinite).toList(growable: false);
    final days = _distinctDays(stops);
    final filtered = _selectedDay == null ? stops : stops.where((s) => s.dayIndex == _selectedDay).toList(growable: false);
    final center = widget.center ?? _centerOf(filtered.isNotEmpty ? filtered : stops);

    final markers = filtered
        .map((s) => NearbyMarker(
              id: s.id,
              lat: s.lat,
              lng: s.lng,
              selected: s.id == _selectedId,
              icon: s.icon,
            ))
        .toList(growable: false);

    final map = (widget.mapBuilder != null && center != null)
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.lat,
              centerLng: center.lng,
              markers: markers,
              initialZoom: 12,
              onMarkerTap: (id) => setState(() => _selectedId = id),
              onRecenter: () => setState(() {}),
            ),
          )
        : _placeholderMap(context);

    // Compute selected safely: only call firstWhere when filtered is non-empty; otherwise keep null
    final TripMapStop? selected = (_selectedId != null && filtered.isNotEmpty)
        ? filtered.firstWhere((e) => e.id == _selectedId, orElse: () => filtered.first)
        : null;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Map
            Positioned.fill(child: map),

            // Day filter row
            if (days.isNotEmpty)
              Positioned(
                left: 8,
                top: 8,
                right: 72,
                child: _DayFilterChips(
                  days: days,
                  selected: _selectedDay,
                  onChanged: (d) => setState(() {
                    _selectedDay = d;
                    _selectedId = null;
                  }),
                ),
              ),

            // Top-right controls
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: cs.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: widget.polylinesSupported ? 'Toggle path' : 'Path drawing requires map integration',
                      onPressed: widget.polylinesSupported ? () {} : null,
                      icon: const Icon(Icons.alt_route),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: cs.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Recenter',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom peek card
            if (selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _PeekCard(
                  stop: selected,
                  onClose: () => setState(() => _selectedId = null),
                  onOpen: widget.onOpenStop,
                  onDirections: widget.onDirections,
                ),
              ),
          ],
        ),
      ),
    );
  }

  GeoPoint? _centerOf(List<TripMapStop> pts) {
    if (pts.isEmpty) return null;
    final lat = pts.map((e) => e.lat).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((e) => e.lng).reduce((a, b) => a + b) / pts.length;
    return GeoPoint(lat, lng);
  }

  List<int> _distinctDays(List<TripMapStop> src) {
    final set = <int>{};
    for (final s in src) {
      if (s.dayIndex != null) set.add(s.dayIndex!);
    }
    final out = set.toList()..sort();
    return out;
  }

  Widget _placeholderMap(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text('Map unavailable', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _DayFilterChips extends StatelessWidget {
  const _DayFilterChips({required this.days, required this.selected, required this.onChanged});

  final List<int> days;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allOn = selected == null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: allOn,
            onSelected: (_) => onChanged(null),
            selectedColor: cs.primary.withValues(alpha: 0.18),
            backgroundColor: cs.surface.withValues(alpha: 1.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            side: BorderSide(color: allOn ? cs.primary : cs.outlineVariant),
          ),
          const SizedBox(width: 6),
          ...days.map((d) {
            final on = selected == d;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('Day $d'),
                selected: on,
                onSelected: (_) => onChanged(d),
                selectedColor: cs.primary.withValues(alpha: 0.18),
                backgroundColor: cs.surface.withValues(alpha: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                side: BorderSide(color: on ? cs.primary : cs.outlineVariant),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({required this.stop, required this.onClose, this.onOpen, this.onDirections});

  final TripMapStop stop;
  final VoidCallback onClose;
  final void Function(TripMapStop stop)? onOpen;
  final Future<void> Function(TripMapStop stop)? onDirections;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    stop.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (stop.dayIndex != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Day ${stop.dayIndex}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                  ),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),

            // Subtitle
            if ((stop.subtitle ?? '').trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  stop.subtitle!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpen == null ? null : () => onOpen!(stop),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDirections == null ? null : () => onDirections!(stop),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
