// lib/ui/components/maps/user_location_marker.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Simple lat/lng model for context when needed (e.g., computing metersPerPixel externally).
@immutable
class UserLatLng {
  const UserLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Converts a real-world radius in meters into pixels at the current zoom/latitude.
/// Host map should compute using its projection (e.g., Web Mercator resolution). 
typedef MetersToPixels = double Function(double meters);

/// Visual style variants for the user marker.
enum UserMarkerStyle { primary, neutral }

/// A plugin-agnostic user location marker (blue dot) with:
/// - Optional pulsing halo for “recent fix”
/// - Optional heading wedge (bearing) 
/// - Accuracy circle sized via meters→pixels callback
/// - Wide-gamut safe colors with Color.withValues (no withOpacity)
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({
    super.key,
    this.style = UserMarkerStyle.primary,
    this.accuracyMeters,
    this.metersToPixels,
    this.headingDegrees,
    this.stale = false,
    this.pulsing = true,
    this.compact = false,
  });

  /// Color styling for dot/halo.
  final UserMarkerStyle style;

  /// Horizontal accuracy radius in meters (68% confidence on Android/iOS).
  final double? accuracyMeters;

  /// Callback that converts meters to pixels at current camera/latitude.
  final MetersToPixels? metersToPixels;

  /// Bearing in degrees for the device heading (0 = north, clockwise).
  final double? headingDegrees;

  /// Gray out when the fix is stale (e.g., not updated recently).
  final bool stale;

  /// Show subtle pulsing halo to indicate a live fix.
  final bool pulsing;

  /// Slightly smaller visuals when true.
  final bool compact;

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool compact = widget.compact;

    final (Color dot, Color ring, Color halo, Color accuracy, Color heading) =
        _colorsForStyle(cs, widget.style, widget.stale);

    final double dotSize = compact ? 10 : 12;
    final double ringSize = compact ? 22 : 26;

    final Widget accuracyCircle = (widget.accuracyMeters != null && widget.metersToPixels != null)
        ? _AccuracyCircle(
            radiusPx: widget.metersToPixels!(widget.accuracyMeters!.clamp(0, 1000000)),
            color: accuracy,
          )
        : const SizedBox.shrink();

    final Widget wedge = (widget.headingDegrees != null)
        ? _HeadingWedge(
            size: ringSize,
            angleDeg: widget.headingDegrees!,
            color: heading,
            compact: compact,
          )
        : const SizedBox.shrink();

    final Widget dotRing = _DotWithRing(
      dotColor: dot,
      ringColor: ring,
      dotSize: dotSize,
      ringSize: ringSize,
    );

    final Widget pulsing = widget.pulsing
        ? AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value; // 0..1
              final double scale = 1.0 + 0.25 * (1 - (2 * (t - 0.5)).abs()); // soft in-out
              final double alpha = 0.28 * (1 - t);
              return Transform.scale(
                scale: scale,
                child: _Halo(
                  size: ringSize * 1.6,
                  color: halo.withValues(alpha: alpha),
                ),
              );
            },
          )
        : const SizedBox.shrink();

    // Build stack: accuracy -> pulsing -> wedge -> ring/dot
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          accuracyCircle,
          pulsing,
          wedge,
          dotRing,
        ],
      ),
    );
  }

  (Color, Color, Color, Color, Color) _colorsForStyle(ColorScheme cs, UserMarkerStyle s, bool stale) {
    switch (s) {
      case UserMarkerStyle.primary:
        final base = cs.primary;
        final dot = stale ? cs.surfaceTint.withValues(alpha: 1.0) : base;
        final ring = cs.surface.withValues(alpha: stale ? 0.80 : 0.95);
        final halo = base;
        final accuracy = base.withValues(alpha: stale ? 0.12 : 0.16);
        final heading = cs.onPrimaryContainer;
        return (dot, ring, halo, accuracy, heading);
      case UserMarkerStyle.neutral:
        final base = cs.surfaceTint;
        final dot = stale ? cs.onSurface.withValues(alpha: 0.80) : cs.onSurface;
        final ring = cs.surface.withValues(alpha: stale ? 0.80 : 0.95);
        final halo = base;
        final accuracy = base.withValues(alpha: stale ? 0.10 : 0.14);
        final heading = cs.onSurface;
        return (dot, ring, halo, accuracy, heading);
    }
  }
}

class _AccuracyCircle extends StatelessWidget {
  const _AccuracyCircle({required this.radiusPx, required this.color});
  final double radiusPx;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (radiusPx <= 0 || !radiusPx.isFinite) return const SizedBox.shrink();
    return CustomPaint(
      painter: _AccuracyPainter(radiusPx: radiusPx, color: color, border: Theme.of(context).colorScheme.outlineVariant),
      size: Size(radiusPx * 2, radiusPx * 2),
    );
  }
}

class _AccuracyPainter extends CustomPainter {
  _AccuracyPainter({required this.radiusPx, required this.color, required this.border});
  final double radiusPx;
  final Color color;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radiusPx, fill);
    canvas.drawCircle(center, radiusPx, stroke);
  }

  @override
  bool shouldRepaint(covariant _AccuracyPainter old) {
    return old.radiusPx != radiusPx || old.color != color || old.border != border;
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DotWithRing extends StatelessWidget {
  const _DotWithRing({
    required this.dotColor,
    required this.ringColor,
    required this.dotSize,
    required this.ringSize,
  });

  final Color dotColor;
  final Color ringColor;
  final double dotSize;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: ringSize,
          height: ringSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 2),
          ),
        ),
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
          ),
        ),
      ],
    );
  }
}

class _HeadingWedge extends StatelessWidget {
  const _HeadingWedge({required this.size, required this.angleDeg, required this.color, required this.compact});
  final double size;
  final double angleDeg;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double r = size * 0.60;
    final double w = compact ? 36 : 44;
    final double h = compact ? 36 : 44;

    return Transform.rotate(
      angle: angleDeg * math.pi / 180.0,
      child: CustomPaint(
        size: Size(w, h),
        painter: _WedgePainter(radius: r, color: color),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  _WedgePainter({required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final path = Path();
    final double a = 38 * math.pi / 180.0; // wedge spread
    path.moveTo(center.dx, center.dy - radius);
    path.lineTo(center.dx - radius * math.sin(a), center.dy - radius * math.cos(a));
    path.arcToPoint(
      Offset(center.dx + radius * math.sin(a), center.dy - radius * math.cos(a)),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.close();

    final p = Paint()..color = color.withValues(alpha: 0.92);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _WedgePainter old) => old.radius != radius || old.color != color;
}

/// Canvas renderer to generate PNG bytes for bitmap-only map SDKs (e.g., google_maps_flutter).
/// Includes dot, ring, wedge (if heading provided), and a light accuracy aura (optional).
class UserLocationIcon {
  static Future<Uint8List> generatePng({
    required ColorScheme colorScheme,
    double devicePixelRatio = 3.0,
    double? headingDegrees,
    bool stale = false,
    bool compact = false,
    double? accuracyMeters, // Only for adding a faint aura, not exact pixel circle
  }) async {
    final cs = colorScheme;
    final (Color dot, Color ring, Color halo, Color accuracy, Color heading) =
        _colorsFor(cs, stale);

    final (double dotDp, double ringDp) = compact ? (10.0, 22.0) : (12.0, 26.0);
    final double dpr = devicePixelRatio.clamp(1.0, 4.0);

    // Canvas bounds: include halo/aura margin
    final double margin = (compact ? 10 : 12) + (accuracyMeters != null ? 2 : 0);
    final double w = (ringDp + margin) * dpr;
    final double h = (ringDp + margin) * dpr;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    final Offset center = Offset(w / 2, h / 2);

    // Soft halo (pulsed look frozen)
    paint.color = halo.withValues(alpha: 0.20);
    canvas.drawCircle(center, (ringDp * dpr) * 0.85, paint);

    // Optional faint “accuracy” aura (not a true circle in meters here)
    if (accuracyMeters != null) {
      paint.color = accuracy.withValues(alpha: 0.18);
      canvas.drawCircle(center, (ringDp * dpr), paint);
    }

    // Heading wedge
    if (headingDegrees != null) {
      final double r = ringDp * dpr * 0.60;
      final double a = 38 * math.pi / 180.0;
      final double rot = headingDegrees * math.pi / 180.0;

      canvas.save();
      canvas.translate(center.dx, center.dy + 2);
      canvas.rotate(rot);
      final Path path = Path()
        ..moveTo(0, -r)
        ..lineTo(-r * math.sin(a), -r * math.cos(a))
        ..arcToPoint(Offset(r * math.sin(a), -r * math.cos(a)),
            radius: Radius.circular(r), clockwise: true)
        ..close();
      paint.color = heading.withValues(alpha: 0.92);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // Ring
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * dpr
      ..color = ring;
    canvas.drawCircle(center, (ringDp * dpr) / 2, paint);

    // Dot
    paint
      ..style = PaintingStyle.fill
      ..color = dot;
    canvas.drawCircle(center, (dotDp * dpr) / 2, paint);

    // Dot inner stroke for contrast
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * dpr
      ..color = cs.surface;
    canvas.drawCircle(center, (dotDp * dpr) / 2, paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(w.toInt(), h.toInt());
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static (Color, Color, Color, Color, Color) _colorsFor(ColorScheme cs, bool stale) {
    final base = cs.primary;
    final dot = stale ? cs.surfaceTint.withValues(alpha: 1.0) : base;
    final ring = cs.surface.withValues(alpha: stale ? 0.80 : 0.95);
    final halo = base;
    final accuracy = base.withValues(alpha: stale ? 0.12 : 0.16);
    final heading = cs.onPrimaryContainer;
    return (dot, ring, halo, accuracy, heading);
  }
}
