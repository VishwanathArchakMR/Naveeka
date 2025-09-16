// lib/ui/components/buttons/chip_button.dart

import 'package:flutter/material.dart';

/// A compact, tappable chip-style button that supports Material 3 states,
/// icons, badges, and selected/disabled variants without using withOpacity.
class ChipButton extends StatefulWidget {
  const ChipButton({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.icon,
    this.trailing,
    this.badgeCount,
    this.tooltip,
    this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.elevation = 0,
    this.selectedElevation = 1,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final bool enabled;

  final Widget? icon;
  final Widget? trailing;
  final int? badgeCount;

  final String? tooltip;
  final String? semanticLabel;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  final double elevation;
  final double selectedElevation;

  /// If true, reduces height/spacing for dense lists.
  final bool dense;

  @override
  State<ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<ChipButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textStyle = (widget.dense ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)
        ?.copyWith(fontWeight: FontWeight.w600);

    // Colors per state (Material 3–inspired)
    final bool isSelected = widget.selected;
    final bool isEnabled = widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    // Base container/fallbacks
    final Color baseBg = isSelected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final Color baseFg = isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    // State overlays (pressed/hover/focus) – use withValues(alpha: ...) instead of withOpacity.
    final Color overlay = cs.primary.withValues(alpha: 0.08);
    final bool showOverlay = (_pressed || _hovered || _focused) && isEnabled;

    final Color bgColor = showOverlay
        ? Color.alphaBlend(overlay, baseBg)
        : baseBg;

    // Disabled styles
    final Color disabledBg = cs.surfaceContainerHighest.withValues(alpha: 0.38);
    final Color disabledFg = cs.onSurface.withValues(alpha: 0.38);

    final Color fgColor = isEnabled ? baseFg : disabledFg;

    final double effectiveElevation = isEnabled
        ? (isSelected ? widget.selectedElevation : widget.elevation)
        : 0;

    final Widget content = _buildContent(context, fgColor);

    final child = Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      selected: widget.selected,
      enabled: isEnabled,
      child: Material(
        color: isEnabled ? bgColor : disabledBg,
        elevation: effectiveElevation,
        shadowColor: theme.shadowColor,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
        child: InkWell(
          onTap: isEnabled ? widget.onTap : null,
          onLongPress: isEnabled ? widget.onLongPress : null,
          customBorder: RoundedRectangleBorder(borderRadius: widget.borderRadius),
          onHover: (h) => setState(() => _hovered = h),
          onHighlightChanged: (p) => setState(() => _pressed = p),
          child: FocusableActionDetector(
            onShowFocusHighlight: (f) => setState(() => _focused = f),
            child: Padding(
              padding: widget.dense
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                  : widget.padding,
              child: DefaultTextStyle(
                style: (textStyle ?? const TextStyle()).copyWith(color: fgColor),
                child: IconTheme(
                  data: IconThemeData(color: fgColor, size: widget.dense ? 18 : 20),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.trim().isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }

  Widget _buildContent(BuildContext context, Color fg) {
    final children = <Widget>[];

    if (widget.icon != null) {
      children.add(Padding(
        padding: EdgeInsets.only(right: widget.dense ? 6 : 8),
        child: widget.icon!,
      ));
    }

    children.add(Flexible(
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ));

    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      children.add(Padding(
        padding: EdgeInsets.only(left: widget.dense ? 6 : 8),
        child: _ChipBadge(count: widget.badgeCount!, foreground: fg),
      ));
    }

    if (widget.trailing != null) {
      children.add(Padding(
        padding: EdgeInsets.only(left: widget.dense ? 4 : 6),
        child: widget.trailing!,
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({required this.count, required this.foreground});

  final int count;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = foreground.withValues(alpha: 0.12);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        );

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}
