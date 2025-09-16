// lib/features/journey/presentation/activities/widgets/activity_route_info.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/storage/location_cache.dart';

class ActivityRouteInfo extends StatefulWidget {
  const ActivityRouteInfo({
    super.key,
    required this.targetLat,
    required this.targetLng,
    this.targetName,
    this.targetAddress,
    this.startLat,
    this.startLng,
    this.startLabel, // e.g., "Current location" or a saved place name
    this.travelMode = TravelMode.driving,
    this.ttl = const Duration(minutes: 10),
  });

  final double targetLat;
  final double targetLng;
  final String? targetName;
  final String? targetAddress;

  /// If not provided, component will read last known coordinates from LocationCache within ttl.
  final double? startLat;
  final double? startLng;
  final String? startLabel;

  final TravelMode travelMode;
  final Duration ttl;

  @override
  State<ActivityRouteInfo> createState() => _ActivityRouteInfoState();
}

class _ActivityRouteInfoState extends State<ActivityRouteInfo> {
  double? _fromLat;
  double? _fromLng;
  double? _meters;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ActivityRouteInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startLat != widget.startLat ||
        oldWidget.startLng != widget.startLng ||
        oldWidget.targetLat != widget.targetLat ||
        oldWidget.targetLng != widget.targetLng) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (widget.startLat != null && widget.startLng != null) {
      _setFrom(widget.startLat!, widget.startLng!);
      return;
    }
    // Pull last known location from cache within TTL (same infra used by banner/distance chip)
    final snap = await LocationCache.instance.getLast(maxAge: widget.ttl);
    if (!mounted) return;
    if (snap != null) {
      _setFrom(snap.latitude, snap.longitude);
    } else {
      setState(() {
        _fromLat = null;
        _fromLng = null;
        _meters = null;
      });
    }
  }

  void _setFrom(double lat, double lng) {
    final meters = _haversineMeters(lat, lng, widget.targetLat, widget.targetLng);
    setState(() {
      _fromLat = lat;
      _fromLng = lng;
      _meters = meters;
    });
  }

  // Haversine great-circle distance in meters
  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final rLat1 = _toRad(lat1);
    final rLat2 = _toRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * math.pi / 180.0;

  String _formatDistance(double? meters) {
    if (meters == null) return '-';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000.0;
    return km < 100 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  Future<void> _openDirections() async {
    final origin = (_fromLat != null && _fromLng != null) ? '${_fromLat},${_fromLng}' : 'Current+Location';
    final destination = '${widget.targetLat},${widget.targetLng}';
    final mode = switch (widget.travelMode) {
      TravelMode.walking => 'walking',
      TravelMode.transit => 'transit',
      TravelMode.bicycling => 'bicycling',
      _ => 'driving',
    };

    // Universal Google Maps URL works across platforms and falls back to browser when app not present
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=$mode&dir_action=navigate',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Try opening in-browser as fallback
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel = widget.startLabel ?? 'Current location';
    final toLabel = widget.targetName ?? 'Destination';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.my_location),
          title: Text(fromLabel),
          subtitle: (_fromLat != null && _fromLng != null)
              ? Text('${_fromLat!.toStringAsFixed(5)}, ${_fromLng!.toStringAsFixed(5)}')
              : const Text('Not available'),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined),
          title: Text(toLabel),
          subtitle: (widget.targetAddress != null && widget.targetAddress!.isNotEmpty)
              ? Text(widget.targetAddress!)
              : Text('${widget.targetLat.toStringAsFixed(5)}, ${widget.targetLng.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.route, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              'Distance: ${_formatDistance(_meters)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            SegmentedButton<TravelMode>(
              segments: const [
                ButtonSegment(value: TravelMode.driving, icon: Icon(Icons.directions_car), label: Text('Drive')),
                ButtonSegment(value: TravelMode.walking, icon: Icon(Icons.directions_walk), label: Text('Walk')),
                ButtonSegment(value: TravelMode.transit, icon: Icon(Icons.directions_transit), label: Text('Transit')),
              ],
              selected: {widget.travelMode},
              onSelectionChanged: (s) {
                // Ignore: stateless API; parent can rebuild with new travelMode if needed.
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openDirections,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Open directions'),
          ),
        ),
      ],
    );
  }
}

enum TravelMode { driving, walking, transit, bicycling }
