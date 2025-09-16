// lib/features/home/presentation/widgets/distance_indicator.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/storage/location_cache.dart';

/// A small chip showing the distance from the user's last known location to a target. [1]
class DistanceIndicator extends StatefulWidget {
  const DistanceIndicator({
    super.key,
    required this.targetLat,
    required this.targetLng,
    this.icon = const Icon(Icons.place_outlined, size: 16),
    this.compact = true,
    this.ttl = const Duration(minutes: 10), // last-location freshness window
    this.cacheKey, // optional stable cache key like "place/<id>"
  });

  final double targetLat;
  final double targetLng;
  final Widget icon;
  final bool compact;
  final Duration ttl;
  final String? cacheKey;

  @override
  State<DistanceIndicator> createState() => _DistanceIndicatorState();
}

class _DistanceIndicatorState extends State<DistanceIndicator> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DistanceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetLat != widget.targetLat ||
        oldWidget.targetLng != widget.targetLng ||
        oldWidget.cacheKey != widget.cacheKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final cache = LocationCache.instance;

    // 1) If a cached derived distance is fresh, use it.
    if (widget.cacheKey != null) {
      final v = cache.getDistance(widget.cacheKey!, maxAge: widget.ttl);
      if (v != null) {
        setState(() => _label = _formatDistance(v));
        return;
      }
    }

    // 2) Get last known location (fresh under ttl), compute distance if available. [21]
    final snap = await cache.getLast(maxAge: widget.ttl);
    if (snap == null) {
      // No location yet
      setState(() => _label = null);
      return;
    }

    final meters = _haversineMeters(
      snap.latitude,
      snap.longitude,
      widget.targetLat,
      widget.targetLng,
    ); // Haversine great-circle distance approximation [6][15]

    // Save derived distance to ephemeral memory cache for list reuse.
    if (widget.cacheKey != null) {
      cache.putDistance(widget.cacheKey!, meters);
    }

    setState(() => _label = _formatDistance(meters));
  }

  // Haversine formula returning meters. [6][20]
  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final rLat1 = _toRad(lat1);
    final rLat2 = _toRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 1000.0; // meters [7]
  }

  double _toRad(double deg) => deg * math.pi / 180.0; // degrees -> radians [15]

  // Simple human-readable formatting: <1000 m uses meters, else km with 1 decimal. [7]
  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000.0;
    // One decimal up to 100km; after that, round to int km
    return km < 100 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    // Hide if distance unavailable (no location yet).
    if (_label == null) return const SizedBox.shrink();

    return Chip(
      visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: widget.compact ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.symmetric(horizontal: 10),
      avatar: widget.icon,
      label: Text(_label!),
    ); // Material Chip is ideal for compact info like distances [1][2]
  }
}
