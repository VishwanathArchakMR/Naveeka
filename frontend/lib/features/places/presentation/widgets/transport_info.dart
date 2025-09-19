// lib/features/places/presentation/widgets/transport_info.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/place.dart';

/// Compact transport section for a place:
/// - Quick actions: Transit, Walk, Cycle, Ride (Uber)
/// - Optional facts: nearest metro/bus, taxi stand, notes
/// - Chips for transport amenities (e.g., metro nearby, shuttle)
/// - Safe external launches via url_launcher
class TransportInfo extends StatelessWidget {
  const TransportInfo({
    super.key,
    required this.title,
    this.showTitle = true,
    this.lat,
    this.lng,
    this.destinationLabel,
    this.nearestMetro,
    this.nearestBus,
    this.taxiStand,
    this.shuttleAvailable,
    this.bikeParking,
    this.scooterParking,
    this.transitNotes,
    this.countryCode,
  });

  /// Convenience factory from Place (all fields optional in your model).
  factory TransportInfo.fromPlace(
    Place p, {
    Key? key,
    String title = 'Getting there',
    bool showTitle = true,
    String? countryCode,
  }) {
    Map<String, dynamic> m = const <String, dynamic>{};
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) m = j;
    } catch (_) {
      // ignore
    }

    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is T) return v;
        if (T == double && v is num) return v.toDouble() as T;
        if (T == double && v is String) {
          final d = double.tryParse(v);
          if (d != null) return d as T;
        }
        if (T == String && v != null) return v.toString() as T;
        if (T == bool && v is String) {
          final s = v.toLowerCase();
          if (s == 'true') return true as T;
          if (s == 'false') return false as T;
        }
      }
      return null;
    }

    return TransportInfo(
      key: key,
      title: title,
      showTitle: showTitle,
      lat: pick<double>(['lat', 'latitude', 'coord_lat', 'location_lat']),
      lng: pick<double>(['lng', 'lon', 'longitude', 'coord_lng', 'location_lng']),
      destinationLabel: pick<String>(['name', 'title', 'label']),
      nearestMetro: pick<String>(['nearestMetro', 'metro', 'nearest_metro']),
      nearestBus: pick<String>(['nearestBus', 'bus', 'nearest_bus']),
      taxiStand: pick<String>(['taxiStand', 'nearest_taxi', 'taxi']),
      shuttleAvailable: pick<bool>(['shuttleAvailable', 'shuttle', 'hasShuttle']),
      bikeParking: pick<bool>(['bikeParking', 'bike_parking']),
      scooterParking: pick<bool>(['scooterParking', 'scooter_parking']),
      transitNotes: pick<String>([
        'transitNotes',
        'transportNotes',
        'gettingThereNotes',
        'notes_transport'
      ]),
      countryCode: countryCode,
    );
  }

  final String title;
  final bool showTitle;

  final double? lat;
  final double? lng;
  final String? destinationLabel;

  // Contextual tips/facts
  final String? nearestMetro;
  final String? nearestBus;
  final String? taxiStand;
  final bool? shuttleAvailable;
  final bool? bikeParking;
  final bool? scooterParking;
  final String? transitNotes;

  /// Optional ISO country code (can refine ride links later if needed).
  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    final hasCoords = lat != null && lng != null;
    final hasAnyTips = _hasAnyTips();
    final chips = _chips();

    if (!hasCoords && !hasAnyTips) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.directions_outlined),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),

            // Quick actions row
            if (hasCoords)
              _QuickActions(
                lat: lat!,
                lng: lng!,
                label: destinationLabel,
              ),

            if (hasCoords) const SizedBox(height: 8),

            // Tips: nearest stops, taxi stand
            if (nearestMetro != null && nearestMetro!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subway_outlined),
                title: const Text('Nearest metro'),
                subtitle: Text(nearestMetro!.trim()),
              ),
            if (nearestBus != null && nearestBus!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.directions_bus_outlined),
                title: const Text('Nearest bus'),
                subtitle: Text(nearestBus!.trim()),
              ),
            if (taxiStand != null && taxiStand!.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_taxi_outlined),
                title: const Text('Taxi stand'),
                subtitle: Text(taxiStand!.trim()),
              ),

            // Amenity chips
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],

            // Notes
            if (transitNotes != null && transitNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _Notes(text: transitNotes!.trim()),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasAnyTips() {
    return (nearestMetro ?? '').trim().isNotEmpty ||
        (nearestBus ?? '').trim().isNotEmpty ||
        (taxiStand ?? '').trim().isNotEmpty ||
        shuttleAvailable == true ||
        bikeParking == true ||
        scooterParking == true ||
        (transitNotes ?? '').trim().isNotEmpty;
  }

  List<Widget> _chips() {
    final out = <Widget>[];
    if (shuttleAvailable == true) {
      out.add(const Chip(
        avatar: Icon(Icons.airport_shuttle, size: 16),
        label: Text('Shuttle'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (bikeParking == true) {
      out.add(const Chip(
        avatar: Icon(Icons.pedal_bike_outlined, size: 16),
        label: Text('Bike parking'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (scooterParking == true) {
      out.add(const Chip(
        avatar: Icon(Icons.electric_scooter_outlined, size: 16),
        label: Text('Scooter parking'),
        visualDensity: VisualDensity.compact,
      ));
    }
    return out;
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.lat,
    required this.lng,
    this.label,
  });

  final double lat;
  final double lng;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: OutlinedButton.icon(
          onPressed: _openTransit,
          icon: const Icon(Icons.train_outlined),
          label: const Text('Transit'),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
          onPressed: _openWalk,
          icon: const Icon(Icons.directions_walk_outlined),
          label: const Text('Walk'),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
          onPressed: _openCycle,
          icon: const Icon(Icons.directions_bike_outlined),
          label: const Text('Cycle'),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
          onPressed: _openUber,
          icon: const Icon(Icons.local_taxi_outlined),
          label: const Text('Ride'),
        )),
      ],
    );
  }

  Future<void> _openTransit() async {
    // Google Maps universal URL with travelmode=transit.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent('${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}')}'
      '&travelmode=transit',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWalk() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent('${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}')}'
      '&travelmode=walking',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCycle() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent('${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}')}'
      '&travelmode=bicycling',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openUber() async {
    // Uber universal deep link (m.uber.com) with pickup=my_location and destination lat/lng.
    final q = {
      'action': 'setPickup',
      'pickup': 'my_location',
      'dropoff[latitude]': lat.toStringAsFixed(6),
      'dropoff[longitude]': lng.toStringAsFixed(6),
      if (label != null && label!.trim().isNotEmpty) 'dropoff[nickname]': label!.trim(),
    };
    final uri = Uri.https('m.uber.com', '/ul/', q);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Notes extends StatefulWidget {
  const _Notes({required this.text});
  final String text;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> with TickerProviderStateMixin {
  bool _open = false;
  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _open ? null : 3,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(_open ? 'Show less' : 'Show more'),
          ),
        ),
      ],
    );
  }
}
