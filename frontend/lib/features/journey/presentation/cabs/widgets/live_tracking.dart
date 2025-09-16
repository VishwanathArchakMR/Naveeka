// lib/features/journey/presentation/cabs/widgets/live_tracking.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTracking extends StatefulWidget {
  const LiveTracking({
    super.key,
    // Required trip endpoints (for initial bounds and context)
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,

    // One of the following must be provided
    this.positionStream, // yields {lat, lng, heading?, speedKph?, etaSec?, status?}
    this.pollInterval = const Duration(seconds: 5),
    this.fetchTick, // Future<Map> Function(), same shape as stream item

    // Visual config
    this.height = 320,
    this.initialZoom = 14,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],

    // Driver info / quick actions
    this.driverName,
    this.vehiclePlate,
    this.driverPhone,
    this.onTick, // optional observer for each position item
  }) : assert(positionStream != null || fetchTick != null,
            'Provide either positionStream or fetchTick for updates');

  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;

  final Stream<Map<String, dynamic>>? positionStream;
  final Future<Map<String, dynamic>> Function()? fetchTick;
  final Duration pollInterval;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;

  final String? driverName;
  final String? vehiclePlate;
  final String? driverPhone;

  final void Function(Map<String, dynamic> data)? onTick;

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  final MapController _map = MapController();

  LatLng? _vehicle;
  double _headingRad = 0.0;
  int? _etaSec;
  String? _status;

  // Drawn path (trail)
  final List<LatLng> _trail = <LatLng>[];
  static const int _trailMax = 300;

  // Follow camera toggle
  bool _follow = true;

  // Subscriptions
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startUpdates();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startUpdates() {
    if (widget.positionStream != null) {
      _sub = widget.positionStream!.listen(_ingest, onError: (_) {});
    } else if (widget.fetchTick != null) {
      _timer = Timer.periodic(widget.pollInterval, (_) async {
        try {
          final data = await widget.fetchTick!();
          _ingest(data);
        } catch (_) {
          // swallow polling error; next tick will try again
        }
      });
    }
  }

  void _ingest(Map<String, dynamic> data) {
    // Parse inputs
    double? _d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = _d(data['lat']);
    final lng = _d(data['lng']);
    if (lat == null || lng == null) return;

    final headingDeg = _d(data['heading']) ?? 0.0;
    final etaSec = (data['etaSec'] is num) ? (data['etaSec'] as num).toInt() : null;
    final status = (data['status'] ?? '').toString();

    widget.onTick?.call(data);

    setState(() {
      _vehicle = LatLng(lat, lng);
      _headingRad = headingDeg * math.pi / 180.0;
      _etaSec = etaSec;
      _status = status.isEmpty ? null : status;

      _trail.add(_vehicle!);
      if (_trail.length > _trailMax) {
        _trail.removeRange(0, _trail.length - _trailMax);
      }

      if (_follow) {
        // Move camera to vehicle keeping current zoom
        final z = _map.camera.zoom;
        _map.move(_vehicle!, z);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final drop = LatLng(widget.dropLat, widget.dropLng);

    // Build bounds for initial fit if we have no vehicle yet
    final initialBounds = _vehicle == null
        ? LatLngBounds.fromPoints([pickup, drop])
        : LatLngBounds.fromPoints([pickup, drop, _vehicle!]);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                // Auto-fit on first paint; thereafter we manually follow using move()
                cameraFit: CameraFit.bounds(
                  bounds: initialBounds,
                  padding: const EdgeInsets.all(28),
                  maxZoom: 16,
                ),
                initialZoom: widget.initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.tileUrl,
                  subdomains: widget.tileSubdomains,
                  userAgentPackageName: 'com.example.app',
                ),
                // Trail polyline + planned straight line
                PolylineLayer(
                  polylines: [
                    if (_trail.length >= 2)
                      Polyline(
                        points: _trail,
                        strokeWidth: 4,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    // Optional visual of pickup->drop if trail absent
                    if (_trail.length < 2)
                      Polyline(
                        points: [pickup, drop],
                        strokeWidth: 2,
                        color: Colors.black26,
                        isDotted: true,
                      ),
                  ],
                  polylineCulling: true,
                ),
                // Markers: pickup, vehicle (if any), drop
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickup,
                      width: 40,
                      height: 40,
                      child: const _Pin(color: Colors.green, icon: Icons.radio_button_checked, tooltip: 'Pickup'),
                    ),
                    if (_vehicle != null)
                      Marker(
                        point: _vehicle!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: _headingRad,
                          child: const _Pin(color: Colors.blue, icon: Icons.local_taxi, tooltip: 'Cab'),
                        ),
                      ),
                    Marker(
                      point: drop,
                      width: 40,
                      height: 40,
                      child: const _Pin(color: Colors.red, icon: Icons.place_outlined, tooltip: 'Drop'),
                    ),
                  ],
                ),
              ],
            ),

            // Info bar
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _StatusBar(
                driverName: widget.driverName,
                vehiclePlate: widget.vehiclePlate,
                etaSec: _etaSec,
                status: _status,
                onCall: widget.driverPhone == null ? null : () => _call(widget.driverPhone!),
              ),
            ),

            // Controls
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Follow toggle
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      tooltip: _follow ? 'Following' : 'Follow vehicle',
                      icon: Icon(_follow ? Icons.center_focus_strong : Icons.center_focus_weak),
                      onPressed: () => setState(() => _follow = !_follow),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Open directions
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      tooltip: 'Open in Maps',
                      icon: const Icon(Icons.navigation_outlined),
                      onPressed: () => _openDirections(pickup, drop),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDirections(LatLng origin, LatLng dest) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving&dir_action=navigate',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, required this.tooltip});
  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.driverName,
    required this.vehiclePlate,
    required this.etaSec,
    required this.status,
    required this.onCall,
  });

  final String? driverName;
  final String? vehiclePlate;
  final int? etaSec;
  final String? status;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    String etaLabel() {
      if (etaSec == null) return '--';
      final m = (etaSec! / 60).floor();
      final s = etaSec! % 60;
      if (m <= 0) return '${s}s';
      if (m < 60) return '${m}m';
      final h = (m / 60).floor();
      final mm = m % 60;
      return mm == 0 ? '${h}h' : '${h}h ${mm}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_taxi, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName ?? 'Driver assigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) ...[
                      Text('Vehicle: ${vehiclePlate!}', style: const TextStyle(color: Colors.black54)),
                      const SizedBox(width: 12),
                    ],
                    Text('ETA: ${etaLabel()}', style: const TextStyle(color: Colors.black54)),
                    if (status != null && status!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text('• ${status!}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onCall != null)
            IconButton(
              tooltip: 'Call driver',
              onPressed: onCall,
              icon: const Icon(Icons.call_outlined),
            ),
        ],
      ),
    );
  }
}
