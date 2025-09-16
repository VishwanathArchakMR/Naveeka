// lib/ui/components/cards/glass_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable frosted-glass style card container with ripple and press scale.
/// - Uses BackdropFilter + ClipRRect to constrain the blur
/// - Material + InkWell overlay ensures proper ripple on tap
/// - AnimatedScale provides lightweight press feedback
/// - Wide-gamut safe alpha via Color.withValues (no withOpacity)
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 16,
    this.blur = 12,
    this.overlayAlpha = 0.08, // background tint over blur (0..1)
    this.borderAlpha = 0.15,  // subtle glass border alpha (0..1)
    this.tintColor,           // optional tint color; defaults to theme surface
    this.heroTag,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  /// Alpha for the frosted tint overlay (replaces old "opacity").
  final double overlayAlpha;

  /// Alpha for the glass border line.
  final double borderAlpha;

  /// Optional tint color; when null, uses theme surface color.
  final Color? tintColor;

  /// Optional Hero tag for shared element transitions of the whole card.
  final Object? heroTag;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color baseTint = widget.tintColor ?? cs.surface;

    final Widget frosted = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseTint.withValues(alpha: widget.overlayAlpha), // wide-gamut safe
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: widget.borderAlpha), // subtle glass edge
              width: 1,
            ),
          ),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    final Widget core = Stack(
      children: <Widget>[
        // Frosted glass content
        frosted,
        // Ripple overlay spans entire card bounds
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onHighlightChanged: (h) => setState(() => _pressed = h),
              onTap: widget.onTap,
            ),
          ),
        ),
      ],
    );

    final Widget scaled = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: core,
    );

    final Widget card = Semantics(
      button: widget.onTap != null,
      label: 'Card',
      child: scaled,
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: card);
    }
    return card;
  }
}

