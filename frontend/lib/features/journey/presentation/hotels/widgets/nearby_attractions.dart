// lib/features/journey/presentation/hotels/widgets/nearby_attractions.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyAttractions extends StatelessWidget {
  const NearbyAttractions({
    super.key,
    required this.hotelLat,
    required this.hotelLng,
    required this.items,
    this.title = 'Nearby attractions',
    this.maxToShow = 10,
    this.onTapAttraction,
    this.onOpenExternal,
  });

  /// Hotel location to compute distances and build directions.
  final double hotelLat;
  final double hotelLng;

  /// Normalized attraction items:
  /// {
  ///   id, name, type?, lat, lng,
  ///   distanceKm? (num), durationMin? (num),
  ///   rating? (double), openNow? (bool), photoUrl?
  /// }
  final List<Map<String, dynamic>> items;

  final String title;
  final int maxToShow;

  /// Optional tap callback (row tap).
  final void Function(Map<String, dynamic> attraction)? onTapAttraction;

  /// Optional hook when opening external URLs (maps/directions).
  final void Function(Uri uri)? onOpenExternal;

  /// Helper to present as a modal sheet and return the tapped attraction via pop.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double hotelLat,
    required double hotelLng,
    required List<Map<String, dynamic>> items,
    String title = 'Nearby attractions',
    int maxToShow = 10,
  }) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: NearbyAttractions(
          hotelLat: hotelLat,
          hotelLng: hotelLng,
          items: items,
          title: title,
          maxToShow: maxToShow,
          onTapAttraction: (m) => Navigator.of(ctx).maybePop(m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotel = _Pt(hotelLat, hotelLng);

    // Compute/fill distances where missing and sort by distance asc
    final enriched = items.map((m) {
      final lat = _toD(m['lat']);
      final lng = _toD(m['lng']);
      final hasCoords = lat != null && lng != null;
      final dist = (m['distanceKm'] is num)
          ? (m['distanceKm'] as num).toDouble()
          : (hasCoords ? _haversineKm(hotel.lat, hotel.lng, lat!, lng!) : null);
      return {
        ...m,
        'distanceKm': dist,
      };
    }).toList(growable: false);

    enriched.sort((a, b) {
      final da = a['distanceKm'] as double? ?? double.infinity;
      final db = b['distanceKm'] as double? ?? double.infinity;
      return da.compareTo(db);
    });

    final visible = enriched.take(maxToShow).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = visible[i];
            final name = (m['name'] ?? '').toString();
            final type = (m['type'] ?? '').toString();
            final lat = _toD(m['lat']);
            final lng = _toD(m['lng']);
            final dist = m['distanceKm'] as double?;
            final mins = (m['durationMin'] is num) ? (m['durationMin'] as num).toInt() : null;
            final rating = (m['rating'] is num) ? (m['rating'] as num).toDouble() : null;
            final openNow = m['openNow'] == true;

            return ListTile(
              leading: _TypeIcon(type: type),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: _metaLine(dist: dist, mins: mins, rating: rating, openNow: openNow),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Open',
                    onPressed: () => _openPlace(name, lat, lng),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                  IconButton(
                    tooltip: 'Directions',
                    onPressed: () => _openDirections(hotel.lat, hotel.lng, lat, lng),
                    icon: const Icon(Icons.navigation_outlined),
                  ),
                ],
              ),
              onTap: onTapAttraction != null ? () => onTapAttraction!(m) : null,
            );
          },
        ),
      ],
    );
  }

  Widget _metaLine({double? dist, int? mins, double? rating, required bool openNow}) {
    final chips = <Widget>[];

    if (dist != null) {
      final v = dist < 10 ? dist.toStringAsFixed(1) : dist.toStringAsFixed(0);
      chips.add(_Chip(text: '$v km'));
    }
    if (mins != null) {
      chips.add(_Chip(text: '${mins}m'));
    }
    if (rating != null) {
      chips.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rate_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1)),
        ],
      ));
    }
    chips.add(_Chip(text: openNow ? 'Open now' : 'Closed', color: openNow ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.12), fg: openNow ? Colors.green.shade700 : Colors.red.shade700));

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Future<void> _openPlace(String name, double? lat, double? lng) async {
    Uri uri;
    if (lat != null && lng != null) {
      // Query by coordinates with a label
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng(${Uri.encodeComponent(name)})');
    } else {
      // Fallback: query by name
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}');
    }
    onOpenExternal?.call(uri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openDirections(double hLat, double hLng, double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$hLat,$hLng&destination=$lat,$lng&travelmode=walking',
    );
    onOpenExternal?.call(uri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  // Haversine distance in kilometers using mean Earth radius 6371 km.
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  } // Implements the Haversine great-circle distance for accurate near-earth distances [9][6]

  double? _toD(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double _degToRad(double d) => d * math.pi / 180.0;
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final t = type.toLowerCase();
    IconData icon = Icons.place_outlined;
    if (t.contains('museum')) icon = Icons.museum_outlined;
    else if (t.contains('park')) icon = Icons.park_outlined;
    else if (t.contains('temple') || t.contains('church') || t.contains('mosque')) icon = Icons.account_balance_outlined;
    else if (t.contains('mall') || t.contains('market')) icon = Icons.store_mall_directory_outlined;
    else if (t.contains('monument') || t.contains('fort')) icon = Icons.castle_outlined;
    else if (t.contains('zoo') || t.contains('aquarium')) icon = Icons.pets_outlined;
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, color: Colors.black87),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color, this.fg});
  final String text;
  final Color? color;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg ?? Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Pt {
  const _Pt(this.lat, this.lng);
  final double lat;
  final double lng;
}
