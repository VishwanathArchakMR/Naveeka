// lib/features/quick_actions/presentation/history/widgets/history_map_view.dart

import 'package:flutter/material.dart';

/// Pluggable map contract reused across the app (Google/Mapbox).
typedef NearbyMapBuilder = Widget Function(BuildContext context, NearbyMapConfig config);

class NearbyMapConfig {
  const NearbyMapConfig({
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    this.initialZoom = 12,
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
    this.icon, // optional custom icon name for your map layer
  });

  final String id;
  final double lat;
  final double lng;
  final bool selected;
  final String? icon;
}

/// Minimal presentation model for a history point on the map.
class HistoryPoint {
  const HistoryPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type, // viewed | searched | booked | shared | custom
    required this.at,
    this.placeName,
    this.thumbnailUrl,
    this.address,
    this.distanceLabel, // e.g., "2.1 km away"
  });

  final String id;
  final double lat;
  final double lng;
  final String type;
  final DateTime at;

  final String? placeName;
  final String? thumbnailUrl;
  final String? address;
  final String? distanceLabel;
}

/// A full-bleed map for history events with:
/// - Pluggable mapBuilder (Google/Mapbox)
/// - Tappable markers with selection state
/// - Bottom peek card showing event details
/// - Top-right Filters/Recenter overlay
/// - Uses Color.withValues (no withOpacity) and const where possible
class HistoryMapView extends StatefulWidget {
  const HistoryMapView({
    super.key,
    required this.points,
    this.mapBuilder,
    this.centerLat,
    this.centerLng,
    this.height = 420,
    this.onOpenFilters,
    this.onOpenPoint,
    this.onDirections,
    this.iconForType, // optional icon resolver for marker style
  });

  final List<HistoryPoint> points;
  final NearbyMapBuilder? mapBuilder;

  /// Optional preferred camera center; defaults to average of point coordinates.
  final double? centerLat;
  final double? centerLng;

  final double height;

  /// Open the filter sheet (type/date).
  final VoidCallback? onOpenFilters;

  /// Open the full detail for a history event or its place.
  final void Function(HistoryPoint p)? onOpenPoint;

  /// Request directions for the underlying place of the event.
  final Future<void> Function(HistoryPoint p)? onDirections;

  /// Optional: resolve an icon name for marker based on type.
  final String Function(String type)? iconForType;

  @override
  State<HistoryMapView> createState() => _HistoryMapViewState();
}

class _HistoryMapViewState extends State<HistoryMapView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final items = widget.points.where((p) => p.lat.isFinite && p.lng.isFinite).toList(growable: false);
    final center = _centerOf(
      items,
      fallback: (widget.centerLat, widget.centerLng),
    );

    final markers = items
        .map((p) => NearbyMarker(
              id: p.id,
              lat: p.lat,
              lng: p.lng,
              selected: p.id == _selectedId,
              icon: widget.iconForType?.call(p.type),
            ))
        .toList(growable: false);

    final map = (widget.mapBuilder != null && center != null)
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.$1,
              centerLng: center.$2,
              markers: markers,
              initialZoom: 12,
              onMarkerTap: (id) => setState(() => _selectedId = id),
              onRecenter: () => setState(() {}),
            ),
          )
        : _placeholderMap(context);

    final selected = _selectedId == null
        ? null
        : items.firstWhere(
            (e) => e.id == _selectedId,
            orElse: () => items.isEmpty ? null : items.first,
          );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Map
            Positioned.fill(child: map),

            // Top-right actions: Filters + Recenter
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Filters',
                      icon: const Icon(Icons.tune),
                      onPressed: widget.onOpenFilters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Recenter',
                      icon: const Icon(Icons.my_location),
                      onPressed: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom peek card when a marker is selected
            if (selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _PeekCard(
                  point: selected,
                  onClose: () => setState(() => _selectedId = null),
                  onOpen: widget.onOpenPoint,
                  onDirections: widget.onDirections,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (double, double)? _centerOf(List<HistoryPoint> pts, { (double?, double?)? fallback }) {
    if (pts.isNotEmpty) {
      final valid = pts.where((e) => e.lat.isFinite && e.lng.isFinite).toList();
      if (valid.isNotEmpty) {
        final lat = valid.map((e) => e.lat).reduce((a, b) => a + b) / valid.length;
        final lng = valid.map((e) => e.lng).reduce((a, b) => a + b) / valid.length;
        return (lat, lng);
      }
    }
    final (fl, fn) = fallback ?? (null, null);
    if (fl != null && fn != null) return (fl, fn);
    return null;
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

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.point,
    required this.onClose,
    this.onOpen,
    this.onDirections,
  });

  final HistoryPoint point;
  final VoidCallback onClose;
  final void Function(HistoryPoint p)? onOpen;
  final Future<void> Function(HistoryPoint p)? onDirections;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (point.placeName ?? '').trim().isEmpty ? 'History item' : point.placeName!.trim();
    final when = _fmtDateTime(context, point.at);

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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    point.type,
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),

            // Subtitle: when + distance/address
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _metaLine(when, point.distanceLabel, point.address),
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
                  onPressed: onOpen == null ? null : () => onOpen!(point),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDirections == null ? null : () => onDirections!(point),
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

  String _metaLine(String when, String? distance, String? address) {
    final parts = <String>[when];
    if ((distance ?? '').trim().isNotEmpty) parts.add(distance!.trim());
    if ((address ?? '').trim().isNotEmpty) parts.add(address!.trim());
    return parts.join(' · ');
  }

  String _fmtDateTime(BuildContext context, DateTime dt) {
    final local = dt.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }
}
