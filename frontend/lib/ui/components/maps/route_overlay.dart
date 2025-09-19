// lib/ui/components/maps/route_overlay.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight lat/lng model used by the overlay (plugin-agnostic).
@immutable
class RouteLatLng {
  const RouteLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Route type to tune default styling.
enum RouteKind { driving, walking, bicycling, transit }

/// Optional traffic severity to tint segments.
enum TrafficSeverity { free, slow, heavy, closed }

/// A contiguous polyline segment with optional traffic severity.
class RouteSegment {
  const RouteSegment({
    required this.points,
    this.severity,
  }) : assert(points.length >= 2, 'Segment needs at least two points');

  final List<RouteLatLng> points;
  final TrafficSeverity? severity;
}

/// Projector from geographic coordinates to screen-space offsets (pixels).
/// Provide this from the hosting map (e.g., GoogleMap/FlutterMap projection).
typedef LatLngProjector = Offset Function(RouteLatLng coord);

/// A plugin-agnostic route overlay that draws styled polylines atop any map.
/// Host must supply a projector and trigger rebuilds on camera changes.
class RouteOverlay extends StatelessWidget {
  const RouteOverlay({
    super.key,
    required this.segments,
    required this.project,
    this.kind = RouteKind.driving,
    this.mainWidth = 6,
    this.outlineWidth = 2,
    this.cornerSmoothing = 0.6,
    this.dashedForWalking = true,
    this.showArrows = true,
    this.arrowSpacing = 48,
    this.arrowSize = 8,
    this.opacity = 1.0,
  });

  /// Polyline segments; order determines drawing order (later on top).
  final List<RouteSegment> segments;

  /// Geo→screen projector from host map.
  final LatLngProjector project;

  /// Default visual style (affects colors/dashing).
  final RouteKind kind;

  /// Main stroke width (px).
  final double mainWidth;

  /// Outline stroke width around the main stroke (px).
  final double outlineWidth;

  /// 0..1 smoothing factor for corners (0 = sharp, 1 = very round).
  final double cornerSmoothing;

  /// If true, walking routes render dashed main stroke.
  final bool dashedForWalking;

  /// Draw small directional arrows along the path.
  final bool showArrows;

  /// Spacing between arrows in logical pixels.
  final double arrowSpacing;

  /// Arrow triangle size in logical pixels.
  final double arrowSize;

  /// Global opacity multiplier 0..1 applied to strokes.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = _paletteForKind(cs, kind);

    return IgnorePointer(
      child: CustomPaint(
        painter: _RoutePainter(
          segments: segments,
          project: project,
          palette: palette,
          mainWidth: mainWidth,
          outlineWidth: outlineWidth,
          cornerSmoothing: cornerSmoothing.clamp(0.0, 1.0),
          dashedForWalking: dashedForWalking,
          showArrows: showArrows,
          arrowSpacing: arrowSpacing,
          arrowSize: arrowSize,
          globalAlpha: opacity.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

/// Internal palette for a route kind; tinted per severity when provided.
class _RoutePalette {
  const _RoutePalette({
    required this.base,
    required this.outline,
    required this.walkPatternAlpha,
    required this.arrow,
  });

  final Color base;
  final Color outline;
  final double walkPatternAlpha;
  final Color arrow;

  Color forSeverity(TrafficSeverity? s) {
    if (s == null) return base;
    switch (s) {
      case TrafficSeverity.free:
        return base;
      case TrafficSeverity.slow:
        return base.blend(const Color(0xFFF6C445), 0.35); // amber-ish
      case TrafficSeverity.heavy:
        return base.blend(const Color(0xFFE57373), 0.45); // red-ish
      case TrafficSeverity.closed:
        return const Color(0xFF9E9E9E); // neutral gray for closures
    }
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.segments,
    required this.project,
    required this.palette,
    required this.mainWidth,
    required this.outlineWidth,
    required this.cornerSmoothing,
    required this.dashedForWalking,
    required this.showArrows,
    required this.arrowSpacing,
    required this.arrowSize,
    required this.globalAlpha,
  });

  final List<RouteSegment> segments;
  final LatLngProjector project;
  final _RoutePalette palette;
  final double mainWidth;
  final double outlineWidth;
  final double cornerSmoothing;
  final bool dashedForWalking;
  final bool showArrows;
  final double arrowSpacing;
  final double arrowSize;
  final double globalAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    // Outline then main strokes so main color sits above.
    for (final seg in segments) {
      final pts = _projected(seg.points);
      if (pts.length < 2) continue;

      final path = _smoothPath(pts, cornerSmoothing);

      // Outline
      if (outlineWidth > 0) {
        final p = Paint()
          ..color = palette.outline.withValues(alpha: (0.85 * globalAlpha))
          ..style = PaintingStyle.stroke
          ..strokeWidth = mainWidth + 2 * outlineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, p);
      }

      // Main stroke (solid or dashed for walking)
      final baseColor = palette.forSeverity(seg.severity).withValues(alpha: (1.0 * globalAlpha));
      final pMain = Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = mainWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (dashedForWalking && _isWalkingStyle()) {
        _drawDashedPath(canvas, path, pMain, dash: 12, gap: 8);
      } else {
        canvas.drawPath(path, pMain);
      }

      // Direction arrows
      if (showArrows) {
        _drawArrowsAlong(canvas, pts, palette.arrow.withValues(alpha: (0.95 * globalAlpha)));
      }
    }
  }

  bool _isWalkingStyle() => dashedForWalking;

  List<Offset> _projected(List<RouteLatLng> coords) {
    return coords.map(project).where((o) => o.dx.isFinite && o.dy.isFinite).toList(growable: false);
  }

  Path _smoothPath(List<Offset> pts, double t) {
    if (pts.length <= 2 || t <= 0) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      return p;
    }
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final next = pts[i + 1];
      final v1 = Offset(cur.dx - prev.dx, cur.dy - prev.dy);
      final v2 = Offset(next.dx - cur.dx, next.dy - cur.dy);
      final len1 = v1.distance;
      final len2 = v2.distance;
      if (len1 == 0 || len2 == 0) {
        p.lineTo(cur.dx, cur.dy);
        continue;
      }
      final d1 = v1 / len1;
      final d2 = v2 / len2;

      final k1 = len1 * t * 0.5;
      final k2 = len2 * t * 0.5;

      final cp1 = cur - d1 * k1;
      final cp2 = cur + d2 * k2;

      p.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
    }
    return p;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dash = 12, double gap = 8}) {
    final metrics = path.computeMetrics(forceClosed: false);
    for (final m in metrics) {
      double dist = 0.0;
      final length = m.length;
      while (dist < length) {
        final next = math.min(dist + dash, length);
        canvas.drawPath(m.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  void _drawArrowsAlong(Canvas canvas, List<Offset> pts, Color color) {
    final p = Paint()..color = color;
    double distanceAcc = 0.0;
    for (int i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final segLen = (b - a).distance;
      if (segLen <= 0) continue;

      double pos = arrowSpacing - distanceAcc;
      while (pos < segLen) {
        final t = pos / segLen;
        final point = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
        final dir = (b - a);
        final angle = math.atan2(dir.dy, dir.dx);

        final path = Path()
          ..moveTo(point.dx, point.dy)
          ..lineTo(
            point.dx - arrowSize * math.cos(angle - math.pi / 6),
            point.dy - arrowSize * math.sin(angle - math.pi / 6),
          )
          ..moveTo(point.dx, point.dy)
          ..lineTo(
            point.dx - arrowSize * math.cos(angle + math.pi / 6),
            point.dy - arrowSize * math.sin(angle + math.pi / 6),
          );

        p.strokeWidth = math.max(1.5, mainWidth * 0.6);
        p.style = PaintingStyle.stroke;
        p.strokeCap = StrokeCap.round;
        canvas.drawPath(path, p);

        pos += arrowSpacing;
      }
      distanceAcc = (segLen - ((segLen - distanceAcc) % arrowSpacing)) % arrowSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) {
    return old.segments != segments ||
        old.mainWidth != mainWidth ||
        old.outlineWidth != outlineWidth ||
        old.cornerSmoothing != cornerSmoothing ||
        old.dashedForWalking != dashedForWalking ||
        old.showArrows != showArrows ||
        old.arrowSpacing != arrowSpacing ||
        old.arrowSize != arrowSize ||
        old.globalAlpha != globalAlpha ||
        old.project != project ||
        old.palette.base != palette.base;
  }
}

_RoutePalette _paletteForKind(ColorScheme cs, RouteKind kind) {
  switch (kind) {
    case RouteKind.driving:
      return _RoutePalette(
        base: cs.primary,
        outline: cs.surface.withValues(alpha: 0.95),
        walkPatternAlpha: 0.0,
        arrow: cs.onPrimaryContainer,
      );
    case RouteKind.walking:
      return _RoutePalette(
        base: cs.tertiary,
        outline: cs.surface.withValues(alpha: 0.95),
        walkPatternAlpha: 0.25,
        arrow: cs.onTertiaryContainer,
      );
    case RouteKind.bicycling:
      return _RoutePalette(
        base: cs.secondary,
        outline: cs.surface.withValues(alpha: 0.95),
        walkPatternAlpha: 0.0,
        arrow: cs.onSecondaryContainer,
      );
    case RouteKind.transit:
      return _RoutePalette(
        base: cs.surfaceTint,
        outline: cs.surface.withValues(alpha: 0.95),
        walkPatternAlpha: 0.0,
        arrow: cs.onSurface,
      );
  }
}

/// Small blending helper since Color.alphaBlend uses src-over; we want a mix.
extension on Color {
  Color blend(Color other, double t) {
    final r = (red + (other.red - red) * t).round();
    final g = (green + (other.green - green) * t).round();
    final b = (blue + (other.blue - blue) * t).round();
    final a = (alpha + (other.alpha - alpha) * t).round();
    return Color.fromARGB(a, r, g, b);
  }
}
