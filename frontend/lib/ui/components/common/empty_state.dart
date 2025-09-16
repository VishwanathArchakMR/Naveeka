// lib/ui/components/common/empty_state.dart

import 'package:flutter/material.dart';

/// A reusable empty state for lists and screens with optional illustration/icon,
/// title, message, and primary/secondary actions. [Material 3]
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.illustration,           // large image or Lottie (provided by caller)
    this.icon,                   // fallback icon if no illustration
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,        // tighter spacing for list sections
    this.background,             // optional container background
    this.padding,
    this.actionsAlignment = MainAxisAlignment.center,
    this.slottedBelow,           // optional extra content below actions
  });

  /// Big visual shown above the title. Typically an Image or animated widget.
  final Widget? illustration;

  /// If no illustration is provided, an icon can be used instead.
  final IconData? icon;

  /// Required title (short and action‑oriented).
  final String title;

  /// Optional descriptive message (1–2 lines).
  final String? message;

  /// Primary action.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Secondary action.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Compact layout (less vertical whitespace).
  final bool compact;

  /// Optional container background Color or Decoration (if you wrap externally).
  final Color? background;

  /// Outer padding; defaults to symmetric layout depending on compact.
  final EdgeInsetsGeometry? padding;

  /// Alignment for actions row.
  final MainAxisAlignment actionsAlignment;

  /// Optional extra content below actions (e.g., tips).
  final Widget? slottedBelow;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final EdgeInsetsGeometry pad =
        padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 24 : 40);

    final Color tileBg =
        background ?? cs.surfaceContainerHighest.withValues(alpha: 0.0); // wide‑gamut safe

    final double gapSm = compact ? 8 : 12;
    final double gapMd = compact ? 12 : 16;
    final double gapLg = compact ? 16 : 24;

    final Widget visual = illustration ??
        Icon(
          icon ?? Icons.inbox_rounded,
          size: compact ? 48 : 72,
          color: cs.onSurfaceVariant.withValues(alpha: 0.9),
        );

    final TextStyle? titleStyle = compact
        ? t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)
        : t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface);

    final TextStyle? messageStyle =
        t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    final List<Widget> actions = _buildActions(context);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        visual,
        SizedBox(height: gapLg),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (message != null && message!.trim().isNotEmpty) ...[
          SizedBox(height: gapSm),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: messageStyle,
          ),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: gapMd),
          Wrap(
            alignment: _wrapAlignment(actionsAlignment),
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
        if (slottedBelow != null) ...[
          SizedBox(height: gapMd),
          slottedBelow!,
        ],
      ],
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Empty state',
      child: Padding(
        padding: pad,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(16)),
          child: Align(
            alignment: Alignment.center,
            child: column,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final List<Widget> buttons = <Widget>[];
    final v = compact ? VisualDensity.compact : VisualDensity.standard;

    if (secondaryLabel != null && onSecondary != null) {
      buttons.add(OutlinedButton(
        onPressed: onSecondary,
        style: OutlinedButton.styleFrom(visualDensity: v),
        child: Text(secondaryLabel!),
      ));
    }
    if (primaryLabel != null && onPrimary != null) {
      buttons.add(FilledButton.tonal(
        onPressed: onPrimary,
        style: FilledButton.styleFrom(visualDensity: v),
        child: Text(primaryLabel!),
      ));
    }
    return buttons;
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment main) {
    switch (main) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
    }
  }
}
