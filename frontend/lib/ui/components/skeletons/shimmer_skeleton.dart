// lib/ui/components/skeletons/shimmer_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A theme-aware wrapper around Shimmer.fromColors that picks sensible
/// base/highlight colors from ColorScheme and supports an optional accent.
/// All translucency uses Color.withValues for wide-gamut safety. [M3]
class ShimmerSkeleton extends StatelessWidget {
  const ShimmerSkeleton({
    super.key,
    required this.child,
    this.useAccent = false,
    this.accentColor,
    this.period = const Duration(milliseconds: 1600),
    this.enabled = true,
  });

  /// The content to shimmer (usually skeleton primitives).
  final Widget child;

  /// If true, uses the provided accentColor (or theme primary) for highlight.
  final bool useAccent;

  /// Optional accent override; falls back to theme.colorScheme.primary.
  final Color? accentColor;

  /// Shimmer cycle duration.
  final Duration period;

  /// Enable/disable shimmer animation.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color base = cs.onSurfaceVariant.withValues(alpha: 0.10);
    final Color highlight = (useAccent ? (accentColor ?? cs.primary) : cs.onSurfaceVariant)
        .withValues(alpha: useAccent ? 0.35 : 0.22);

    if (!enabled) return child;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: period,
      child: child,
    );
  }
}

/// A rounded rectangle block for skeleton UIs.
/// Defaults to a subtle block color from onSurfaceVariant with radius.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.intensity = 0.08, // 0..1 relative alpha on onSurfaceVariant
  });

  final double width;
  final double height;
  final double borderRadius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color c = cs.onSurfaceVariant.withValues(alpha: intensity.clamp(0.0, 1.0));
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A single line skeleton with optional maxWidth factor.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.height = 12,
    this.maxWidth = 1.0, // fraction of the available width
    this.borderRadius = 6,
    this.intensity = 0.06,
  });

  final double height;
  final double maxWidth;
  final double borderRadius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final double full = MediaQuery.sizeOf(context).width;
    final double w = (full * maxWidth).clamp(0.0, double.infinity);
    return SkeletonBox(
      width: w,
      height: height,
      borderRadius: borderRadius,
      intensity: intensity,
    );
  }
}

/// A circular skeleton (e.g., avatar/marker).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    required this.diameter,
    this.intensity = 0.08,
  });

  final double diameter;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: diameter,
      height: diameter,
      borderRadius: diameter / 2,
      intensity: intensity,
    );
  }
}

/// A convenience paragraph: N lines with variable widths.
class SkeletonParagraph extends StatelessWidget {
  const SkeletonParagraph({
    super.key,
    this.lines = 3,
    this.gap = 8,
    this.minWidthFactor = 0.45,
    this.maxWidthFactor = 0.90,
    this.height = 12,
    this.intensity = 0.06,
  });

  final int lines;
  final double gap;
  final double minWidthFactor;
  final double maxWidthFactor;
  final double height;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (int i = 0; i < lines; i++) {
      // Taper the last line shorter for realism.
      final double factor = i == lines - 1
          ? (minWidthFactor + (maxWidthFactor - minWidthFactor) * 0.6)
          : (minWidthFactor + (maxWidthFactor - minWidthFactor) * 0.9);
      widgets.add(SkeletonLine(height: height, maxWidth: factor, intensity: intensity));
      if (i != lines - 1) widgets.add(SizedBox(height: gap));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

/// A ready-to-use card skeleton template using the primitives above.
class GenericCardSkeleton extends StatelessWidget {
  const GenericCardSkeleton({
    super.key,
    this.width = 160,
    this.height = 200,
    this.borderRadius = 16,
    this.imageRatio = 0.62,
    this.showActions = false,
    this.useAccent = false,
    this.accentColor,
  });

  final double width;
  final double height;
  final double borderRadius;
  final double imageRatio;
  final bool showActions;
  final bool useAccent;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color tileBg = cs.surfaceContainerHighest;
    final Color border = cs.outlineVariant;

    final double imgH = (height * imageRatio).clamp(0, height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ShimmerSkeleton(
        useAccent: useAccent,
        accentColor: accentColor,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Image placeholder
              SkeletonBox(width: width, height: imgH, borderRadius: 0, intensity: 0.08),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SkeletonLine(height: 14, maxWidth: 0.60, intensity: 0.08),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SkeletonLine(height: 12, maxWidth: 0.40, intensity: 0.06),
              ),
              if (showActions) ...<Widget>[
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: <Widget>[
                      _Pill(),
                      SizedBox(width: 6),
                      _Pill(w: 48),
                      SizedBox(width: 6),
                      _Pill(w: 36),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({this.w = 64});
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
