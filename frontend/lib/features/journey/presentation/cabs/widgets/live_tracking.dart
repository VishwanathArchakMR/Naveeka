// lib/features/journey/presentation/cabs/widgets/live_tracking.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
    this.initialZoom = 14, // kept for API compatibility

    // Driver info / quick actions
    this.driverName,
    this.vehiclePlate,
    this.driverPhone,
    this.onTick, // optional observer for each position item
  }) : assert(
          positionStream != null || fetchTick != null,
          'Provide either positionStream or fetchTick for updates',
        );

  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;

  final Stream<Map<String, dynamic>>? positionStream;
  final Future<Map<String, dynamic>> Function()? fetchTick;
  final Duration pollInterval;

  final double height;
  final double initialZoom;

  final String? driverName;
  final String? vehiclePlate;
  final String? driverPhone;

  final void Function(Map<String, dynamic> data)? onTick;

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  LatLng? _vehicle;
  double _headingRad = 0.0;
  int? _etaSec;
  String? _status;

  // Drawn path (trail)
  final List<LatLng> _trail = <LatLng>[];
  static const int _trailMax = 300;

  // Follow camera toggle (placeholder flag; painter auto-fits to bounds)
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
    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = d(data['lat']);
    final lng = d(data['lng']);
    if (lat == null || lng == null) return;

    final headingDeg = d(data['heading']) ?? 0.0;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final drop = LatLng(widget.dropLat, widget.dropLng);

    // Points to fit: pickup, drop, trail, vehicle
    final fitPoints = <LatLng>[
      pickup,
      drop,
      if (_vehicle != null) _vehicle!,
      ..._trail,
    ];

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final projector = _Projector.fromPoints(fitPoints, Size(w, widget.height));

          final pickupOffset = projector.toOffset(pickup);
          final dropOffset = projector.toOffset(drop);
          final vehicleOffset = _vehicle == null ? null : projector.toOffset(_vehicle!);

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Route/trail painter
                CustomPaint(
                  size: Size(w, widget.height),
                  painter: _LiveTrackingPainter(
                    projector: projector,
                    trail: _trail,
                    pickup: pickup,
                    drop: drop,
                    primary: Theme.of(context).colorScheme.primary,
                  ),
                ),

                // Pins
                // Pickup
                Positioned(
                  left: pickupOffset.dx - 14,
                  top: pickupOffset.dy - 14,
                  width: 28,
                  height: 28,
                  child: const _Pin(color: Colors.green, icon: Icons.radio_button_checked, tooltip: 'Pickup'),
                ),
                // Vehicle (if present)
                if (vehicleOffset != null)
                  Positioned(
                    left: vehicleOffset.dx - 16,
                    top: vehicleOffset.dy - 16,
                    width: 32,
                    height: 32,
                    child: Transform.rotate(
                      angle: _headingRad,
                      child: const _Pin(color: Colors.blue, icon: Icons.local_taxi, tooltip: 'Cab'),
                    ),
                  ),
                // Drop
                Positioned(
                  left: dropOffset.dx - 14,
                  top: dropOffset.dy - 14,
                  width: 28,
                  height: 28,
                  child: const _Pin(color: Colors.red, icon: Icons.place_outlined, tooltip: 'Drop'),
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
                      // Follow toggle (visual only)
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
                      // Open directions (pickup -> drop)
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
          );
        },
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
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},'
      '${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving&dir_action=navigate',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

// Minimal LatLng type to avoid external dependency
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

// Projects geo bounds to canvas coordinates with padding
class _Projector {
  final double minLat, maxLat, minLng, maxLng;
  final double sx, sy;
  final double pad;
  final Size size;

  _Projector({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.sx,
    required this.sy,
    required this.pad,
    required this.size,
  });

  factory _Projector.fromPoints(List<LatLng> pts, Size size, {double pad = 16}) {
    if (pts.isEmpty) {
      return _Projector(
        minLat: 0,
        maxLat: 1,
        minLng: 0,
        maxLng: 1,
        sx: 1,
        sy: 1,
        pad: pad,
        size: size,
      );
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Avoid degenerate scale if bounds collapse
    if ((maxLat - minLat).abs() < 1e-9) {
      minLat -= 0.0001;
      maxLat += 0.0001;
    }
    if ((maxLng - minLng).abs() < 1e-9) {
      minLng -= 0.0001;
      maxLng += 0.0001;
    }
    final dx = (maxLng - minLng).abs();
    final dy = (maxLat - minLat).abs();
    final sx = (size.width - 2 * pad) / dx;
    final sy = (size.height - 2 * pad) / dy;
    return _Projector(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      sx: sx,
      sy: sy,
      pad: pad,
      size: size,
    );
  }

  Offset toOffset(LatLng p) {
    final w = size.width, h = size.height;
    final x = pad + (p.longitude - minLng) * sx;
    final y = h - pad - (p.latitude - minLat) * sy; // invert Y for canvas
    return Offset(x.clamp(0, w), y.clamp(0, h));
  }
}

class _LiveTrackingPainter extends CustomPainter {
  _LiveTrackingPainter({
    required this.projector,
    required this.trail,
    required this.pickup,
    required this.drop,
    required this.primary,
  });

  final _Projector projector;
  final List<LatLng> trail;
  final LatLng pickup;
  final LatLng drop;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient + subtle grid
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          Colors.grey.shade100,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const pad = 16.0;
    for (var x = pad; x < size.width - pad; x += 24) {
      canvas.drawLine(Offset(x, pad), Offset(x, size.height - pad), gridPaint);
    }
    for (var y = pad; y < size.height - pad; y += 24) {
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), gridPaint);
    }

    // Planned straight line (pickup -> drop) if trail is short
    if (trail.length < 2) {
      final p1 = projector.toOffset(pickup);
      final p2 = projector.toOffset(drop);
      final planned = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy);
      canvas.drawPath(path, planned);
    }

    // Trail polyline
    if (trail.length >= 2) {
      final routePaint = Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final first = projector.toOffset(trail.first);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < trail.length; i++) {
        final o = projector.toOffset(trail[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveTrackingPainter oldDelegate) {
    return trail != oldDelegate.trail ||
        pickup != oldDelegate.pickup ||
        drop != oldDelegate.drop ||
        primary != oldDelegate.primary ||
        projector.size != oldDelegate.projector.size;
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
