// lib/ui/components/skeletons/card_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/theme.dart';

/// Premium shimmer skeleton for a single card widget.
/// Works for grid/list cards like PlaceCard and WishlistCard.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({
    super.key,
    this.width = 160,
    this.height = 200,
    this.useEmotionAccent = false,
    this.emotion,
    this.borderRadius = 16,
    this.showActions = false,
    this.imageRatio = 0.62, // portion of height used by image placeholder
  });

  final double width;
  final double height;
  final bool useEmotionAccent;
  final EmotionKind? emotion;

  /// Corner radius for the skeleton card.
  final double borderRadius;

  /// Show a small row of pill placeholders at the bottom.
  final bool showActions;

  /// Image height ratio relative to total card height.
  final double imageRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = EmotionTheme.of(emotion ?? EmotionKind.peaceful).accent;

    // Use modern M3 surfaces and wide‑gamut‑safe alpha values.
    final Color baseColor = cs.onSurfaceVariant.withValues(alpha: 0.10);
    final Color highlightColor = useEmotionAccent
        ? accent.withValues(alpha: 0.35)
        : cs.onSurfaceVariant.withValues(alpha: 0.22);

    final Color tileBg = cs.surfaceContainerHighest;
    final Color block = cs.onSurfaceVariant.withValues(alpha: 0.08);
    final Color blockSoft = cs.onSurfaceVariant.withValues(alpha: 0.06);
    final Color border = cs.outlineVariant;

    final double imgH = (height * imageRatio).clamp(0, height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1600),
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
              // Image placeholder with rounded top corners
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  height: 14,
                  width: width * 0.6,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  height: 12,
                  width: width * 0.4,
                  decoration: BoxDecoration(
                    color: blockSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              // Optional action chips (e.g., price/rating tags)
              if (showActions) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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

