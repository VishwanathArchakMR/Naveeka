// lib/ui/components/cards/gradient_card.dart

import 'package:flutter/material.dart';

/// A premium gradient card with ripple, soft glow, and optional header/tags/actions.
/// - Proper Ink ripple over custom backgrounds (Material + InkWell)
/// - Wide-gamut safe: uses Color.withValues instead of withOpacity
/// - Material 3 friendly spacing, shapes, and text styles
class GradientCard extends StatefulWidget {
  const GradientCard({
    super.key,
    this.onTap,
    this.leading,
    this.title,
    this.subtitle,
    this.tags = const <String>[],
    this.child,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.gradient,
    this.overlayAlpha = 0.0, // optional dim overlay on gradient (0..1)
    this.glowAlpha = 0.18,    // subtle box shadow alpha (0..1)
    this.heroTag,
    this.dense = false,
  });

  /// Card tap handler; enables ripple if not null.
  final VoidCallback? onTap;

  /// Optional header leading widget (e.g., icon/avatar).
  final Widget? leading;

  /// Optional header title.
  final String? title;

  /// Optional header subtitle shown under title.
  final String? subtitle;

  /// Optional tags shown under header.
  final List<String> tags;

  /// Optional custom body content; when null, card shows only header/tags/actions.
  final Widget? child;

  /// Primary action button label and handler.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Secondary action button label and handler.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Inner padding for card content.
  final EdgeInsetsGeometry padding;

  /// Card border radius.
  final double borderRadius;

  /// Optional gradient override; if null, derives from ColorScheme.
  final Gradient? gradient;

  /// Extra dim overlay alpha over gradient (useful for legibility).
  final double overlayAlpha;

  /// Glow alpha for the soft shadow around the card.
  final double glowAlpha;

  /// Optional hero tag for shared element transitions.
  final Object? heroTag;

  /// Denser layout for list contexts if true.
  final bool dense;

  @override
  State<GradientCard> createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Gradient gradient = widget.gradient ?? _defaultGradient(cs);
    final Color overlay = cs.surface.withValues(alpha: widget.overlayAlpha.clamp(0.0, 1.0));
    final Color glow = cs.primary.withValues(alpha: widget.glowAlpha.clamp(0.0, 1.0));

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius));

    final header = _buildHeader(context);
    final tags = _buildTags(context);
    final actions = _buildActions(context);

    final List<Widget> column = <Widget>[
      if (header != null) header,
      if (header != null && (widget.tags.isNotEmpty || widget.child != null)) SizedBox(height: widget.dense ? 8 : 10),
      if (tags != null) tags,
      if (tags != null && widget.child != null) SizedBox(height: widget.dense ? 8 : 12),
      if (widget.child != null) widget.child!,
      if ((widget.primaryLabel != null && widget.onPrimary != null) ||
          (widget.secondaryLabel != null && widget.onSecondary != null))
        SizedBox(height: widget.dense ? 10 : 12),
      if (actions != null) actions,
    ];

    final decorated = AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: glow,
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: overlay, // optional dim overlay on top of gradient
            ),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (h) => setState(() => _pressed = h),
              customBorder: shape,
              child: Padding(
                padding: widget.padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: column,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = Semantics(
      button: widget.onTap != null,
      label: widget.title ?? 'Card',
      child: decorated,
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: card);
    }
    return card;
  }

  Widget? _buildHeader(BuildContext context) {
    if (widget.title == null && widget.subtitle == null && widget.leading == null) return null;
    final t = Theme.of(context);
    final titleStyle = widget.dense
        ? t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.onPrimary)
        : t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.onPrimary);
    final subtitleStyle = t.textTheme.bodySmall?.copyWith(
      color: t.colorScheme.onPrimary.withValues(alpha: 0.88),
    );

    final title = widget.title != null
        ? Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)
        : null;
    final subtitle = widget.subtitle != null
        ? Text(widget.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: subtitleStyle)
        : null;

    final textCol = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) title,
          if (subtitle != null) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: subtitle,
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.leading != null) ...[
          IconTheme(
            data: IconThemeData(
              color: Theme.of(context).colorScheme.onPrimary,
              size: widget.dense ? 20 : 22,
            ),
            child: widget.leading!,
          ),
          const SizedBox(width: 10),
        ],
        textCol,
      ],
    );
  }

  Widget? _buildTags(BuildContext context) {
    if (widget.tags.isEmpty) return null;
    final cs = Theme.of(context).colorScheme;
    final padH = widget.dense ? 6.0 : 8.0;
    final padV = widget.dense ? 3.0 : 4.0;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.tags.map((t) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: cs.onPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.onPrimary.withValues(alpha: 0.22)),
          ),
          child: Text(
            t,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget? _buildActions(BuildContext context) {
    final hasPrimary = widget.primaryLabel != null && widget.onPrimary != null;
    final hasSecondary = widget.secondaryLabel != null && widget.onSecondary != null;
    if (!hasPrimary && !hasSecondary) return null;

    final t = Theme.of(context);
    final vDensity = widget.dense ? VisualDensity.compact : VisualDensity.standard;

    final buttons = <Widget>[];
    if (hasSecondary) {
      buttons.add(OutlinedButton(
        onPressed: widget.onSecondary,
        style: OutlinedButton.styleFrom(
          foregroundColor: t.colorScheme.onPrimary,
          side: BorderSide(color: t.colorScheme.onPrimary.withValues(alpha: 0.6)),
          visualDensity: vDensity,
        ),
        child: Text(widget.secondaryLabel!),
      ));
      buttons.add(const SizedBox(width: 8));
    }
    if (hasPrimary) {
      buttons.add(FilledButton(
        onPressed: widget.onPrimary,
        style: FilledButton.styleFrom(
          backgroundColor: t.colorScheme.onPrimary.withValues(alpha: 0.16),
          foregroundColor: t.colorScheme.onPrimary,
          visualDensity: vDensity,
        ),
        child: Text(widget.primaryLabel!),
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
    );
  }

  Gradient _defaultGradient(ColorScheme cs) {
    // A simple three-stop gradient derived from the theme’s primary hues for brand consistency.
    final a = cs.primary;
    final b = cs.primaryContainer;
    final mid = Color.lerp(a, b, 0.35) ?? a;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[a, mid, b],
    );
  }
}
