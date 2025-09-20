// lib/ui/components/cards/neumorphic_card.dart

import 'package:flutter/material.dart';

/// A premium "soft UI" card with neumorphic depth, ripple, and optional header/tags/actions.
/// - Twin shadows create raised depth on neutral surfaces
/// - Uses Material + Ink + InkWell so ripples render over custom backgrounds
/// - Wide‑gamut safe: uses Color.withValues for alpha, not withOpacity
class NeumorphicCard extends StatefulWidget {
  const NeumorphicCard({
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
    this.surfaceColor, // override base surface (defaults from theme)
    this.lightShadowColor, // override light shadow
    this.darkShadowColor, // override dark shadow
    this.heroTag,
    this.dense = false,
  });

  final VoidCallback? onTap;

  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<String> tags;

  final Widget? child;

  final String? primaryLabel;
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final EdgeInsetsGeometry padding;
  final double borderRadius;

  final Color? surfaceColor;
  final Color? lightShadowColor;
  final Color? darkShadowColor;

  final Object? heroTag;
  final bool dense;

  @override
  State<NeumorphicCard> createState() => _NeumorphicCardState();
}

class _NeumorphicCardState extends State<NeumorphicCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    // Base surface for soft UI, defaults to a high surface container.
    final Color base = widget.surfaceColor ?? cs.surfaceContainerHighest; // soft neutral base [20]

    // Light and dark shadow tones; withValues for alpha (wide-gamut safe).
    final Color lightShadow = (widget.lightShadowColor ?? Colors.white)
        .withValues(alpha: t.brightness == Brightness.light ? 0.90 : 0.20); // top-left highlight [7]
    final Color darkShadow =
        (widget.darkShadowColor ?? cs.shadow).withValues(alpha: t.brightness == Brightness.light ? 0.22 : 0.45); // bottom-right shade [7][1]

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius),
    );

    final header = _buildHeader(context);
    final tags = _buildTags(context);
    final actions = _buildActions(context);

    final children = <Widget>[
      if (header != null) header,
      if (header != null && (widget.tags.isNotEmpty || widget.child != null)) SizedBox(height: widget.dense ? 8 : 10),
      if (tags != null) tags,
      if (tags != null && widget.child != null) SizedBox(height: widget.dense ? 8 : 12),
      if (widget.child != null) widget.child!,
      if ((widget.primaryLabel != null && widget.onPrimary != null) ||
          (widget.secondaryLabel != null && widget.onSecondary != null)) ...[
        SizedBox(height: widget.dense ? 10 : 12),
        actions!,
      ],
    ];

    final body = AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: <BoxShadow>[
            // Light source top-left
            BoxShadow(
              color: lightShadow,
              offset: const Offset(-4, -4),
              blurRadius: 10,
              spreadRadius: 0.6,
            ),
            // Dark shadow bottom-right
            BoxShadow(
              color: darkShadow,
              offset: const Offset(5, 6),
              blurRadius: 12,
              spreadRadius: 0.8,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (h) => setState(() => _pressed = h),
              customBorder: shape,
              child: Padding(
                padding: widget.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
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
      child: body,
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: card);
    }
    return card;
  }

  Widget? _buildHeader(BuildContext context) {
    if (widget.title == null && widget.subtitle == null && widget.leading == null) return null;
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final titleStyle = widget.dense
        ? t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)
        : t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface);

    final subtitleStyle = t.textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.80),
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
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: subtitle),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.leading != null) ...[
          IconTheme(
            data: IconThemeData(color: cs.onSurface, size: widget.dense ? 20 : 22),
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
            color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            t,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget? _buildActions(BuildContext context) {
    final hasPrimary = widget.primaryLabel != null && widget.onPrimary != null;
    final hasSecondary = widget.secondaryLabel != null && widget.onSecondary != null;
    if (!hasPrimary && !hasSecondary) return null;

    final v = widget.dense ? VisualDensity.compact : VisualDensity.standard;

    final buttons = <Widget>[];
    if (hasSecondary) {
      buttons.add(OutlinedButton(
        onPressed: widget.onSecondary,
        style: OutlinedButton.styleFrom(visualDensity: v),
        child: Text(widget.secondaryLabel!),
      ));
      buttons.add(const SizedBox(width: 8));
    }
    if (hasPrimary) {
      buttons.add(FilledButton.tonal(
        onPressed: widget.onPrimary,
        style: FilledButton.styleFrom(visualDensity: v),
        child: Text(widget.primaryLabel!),
      ));
    }

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons);
  }
}
