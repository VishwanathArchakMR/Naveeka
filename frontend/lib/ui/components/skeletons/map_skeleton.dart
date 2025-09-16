// lib/ui/components/skeletons/map_skeleton.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer map skeleton with optional overlays that matches M3 surfaces.
/// - Tile-like background pattern
/// - Optional center dot and faint route hint
/// - Optional control chips (top and bottom)
class MapSkeleton extends StatelessWidget {
  const MapSkeleton({
    super.key,
    this.width,
    this.height = 200,
    this.borderRadius = 16,
    this.showOverlays = true,
    this.showCenterDot = true,
    this.showRouteHint = false,
    this.padding = const EdgeInsets.all(8),
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool showOverlays;
  final bool showCenterDot;
  final bool showRouteHint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Shimmer palette derived from onSurfaceVariant and applied to child. [M3]
    final Color base = cs.onSurfaceVariant.withValues(alpha: 0.10);
    final Color highlight = cs.onSurfaceVariant.withValues(alpha: 0.22);

    // Container background uses modern M3 surfaceContainerHighest. [M3]
    final Color tileBg = cs.surfaceContainerHighest;

    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Stack(
        children: <Widget>[
          // Tile-like backdrop pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _MapTilesPainter(
                tileColor1: cs.onSurfaceVariant.withValues(alpha: 0.06),
                tileColor2: cs.onSurfaceVariant.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Optional faint route hint
          if (showRouteHint)
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteHintPainter(
                  color: cs.primary.withValues(alpha: 0.16),
                  outline: cs.surface.withValues(alpha: 0.95),
                ),
              ),
            ),

          // Optional center dot for selection
          if (showCenterDot)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _CenterDot(
                    primary: cs.primary,
                    border: cs.surface,
                    ring: cs.outlineVariant,
                  ),
                ),
              ),
            ),

          // Overlay chips (top and bottom)
          if (showOverlays)
            Positioned.fill(
              child: Padding(
                padding: padding,
                child: _OverlayChips(),
              ),
            ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: const Duration(milliseconds: 1600),
        child: child,
      ),
    );
  }
}

class _MapTilesPainter extends CustomPainter {
  _MapTilesPainter({
    required this.tileColor1,
    required this.tileColor2,
    this.tile = 56,
    this.gap = 2,
  });

  final Color tileColor1;
  final Color tileColor2;
  final double tile;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..isAntiAlias = false;

    // Draw alternating rectangles to simulate subtle tiles.
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final bool alt = (((x / tile).floor() + (y / tile).floor()) % 2) == 0;
        p.color = (alt ? tileColor1 : tileColor2);
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, math.min(tile - gap, size.width - x), math.min(tile - gap, size.height - y)),
          const Radius.circular(2),
        );
        canvas.drawRRect(r, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapTilesPainter oldDelegate) {
    return oldDelegate.tileColor1 != tileColor1 ||
        oldDelegate.tileColor2 != tileColor2 ||
        oldDelegate.tile != tile ||
        oldDelegate.gap != gap;
  }
}

class _RouteHintPainter extends CustomPainter {
  _RouteHintPainter({required this.color, required this.outline});

  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    // A soft bezier route from left-bottom to right-top with gentle waves.
    path.moveTo(w * 0.05, h * 0.85);
    path.cubicTo(w * 0.25, h * 0.65, w * 0.35, h * 0.95, w * 0.50, h * 0.70);
    path.cubicTo(w * 0.65, h * 0.45, w * 0.75, h * 0.75, w * 0.92, h * 0.20);

    final Paint pOutline = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint pMain = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outline underlay for contrast; main color on top.
    canvas.drawPath(path, pOutline);
    canvas.drawPath(path, pMain);
  }

  @override
  bool shouldRepaint(covariant _RouteHintPainter old) {
    return old.color != color || old.outline != outline;
  }
}

class _CenterDot extends StatelessWidget {
  const _CenterDot({required this.primary, required this.border, required this.ring});

  final Color primary;
  final Color border;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -1.5),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: ring),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = cs.surfaceContainerHighest.withValues(alpha: 0.92);
    final Color border = cs.outlineVariant;

    return Column(
      children: <Widget>[
        // Top row: a wide pill at left and two square icons at right
        Row(
          children: <Widget>[
            _pill(bg, border, w: 120, h: 28),
            const Spacer(),
            _square(bg, border, 36),
            const SizedBox(width: 6),
            _square(bg, border, 36),
          ],
        ),
        const Spacer(),
        // Bottom row: a legend-like pill at right
        Row(
          children: <Widget>[
            const Spacer(),
            _pill(bg, border, w: 100, h: 28),
          ],
        ),
      ],
    );
  }

  Widget _pill(Color bg, Color border, {required double w, required double h}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: SizedBox(width: w, height: h),
    );
    }

  Widget _square(Color bg, Color border, double s) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: SizedBox(width: s, height: s),
    );
  }
}
