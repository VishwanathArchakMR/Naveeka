// lib/ui/components/skeletons/list_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/theme.dart';

/// A premium shimmering placeholder for list items.
/// - Matches card shapes used in PlaceCard, WishlistCard, Admin cards.
/// - Use for list loading states with theme-aware surfaces and accents.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 6,
    this.cardHeight = 200,
    this.useEmotionAccent = false,
    this.emotion,
    this.borderRadius = 16,
    this.imageRatio = 0.60,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 14,
    this.showActions = false,
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  });

  final int itemCount;
  final double cardHeight;
  final bool useEmotionAccent;
  final EmotionKind? emotion;

  /// Visual tweaks
  final double borderRadius;
  final double imageRatio; // portion of item height for the image placeholder
  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool showActions;

  /// List behavior
  final ScrollPhysics physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color accent = EmotionTheme.of(emotion ?? EmotionKind.peaceful).accent;

    // M3 surfaces + wide-gamut-safe shimmer colors. [surfaceContainerHighest]
    final Color shimmerBase = cs.onSurfaceVariant.withValues(alpha: 0.10);
    final Color shimmerHighlight = useEmotionAccent
        ? accent.withValues(alpha: 0.35)
        : cs.onSurfaceVariant.withValues(alpha: 0.22);

    return ListView.separated(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, __) => _GlassItem(
        height: cardHeight,
        borderRadius: borderRadius,
        imageRatio: imageRatio,
        showActions: showActions,
        shimmerBase: shimmerBase,
        shimmerHighlight: shimmerHighlight,
      ),
    );
  }
}

class _GlassItem extends StatelessWidget {
  const _GlassItem({
    required this.height,
    required this.borderRadius,
    required this.imageRatio,
    required this.showActions,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final double height;
  final double borderRadius;
  final double imageRatio;
  final bool showActions;

  final Color shimmerBase;
  final Color shimmerHighlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color tileBg = cs.surfaceContainerHighest;
    final Color border = cs.outlineVariant;
    final Color block = cs.onSurfaceVariant.withValues(alpha: 0.08);
    final Color blockSoft = cs.onSurfaceVariant.withValues(alpha: 0.06);

    final double imgH = (height * imageRatio).clamp(0, height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        period: const Duration(milliseconds: 1600),
        child: Container(
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
              Container(
                height: imgH,
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    color: blockSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              // Optional action pills (e.g., price/rating tags)
              if (showActions) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: <Widget>[
                      _pill(blockSoft),
                      const SizedBox(width: 6),
                      _pill(blockSoft, w: 48),
                      const SizedBox(width: 6),
                      _pill(blockSoft, w: 36),
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

  Widget _pill(Color c, {double w = 64, double h = 18}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

