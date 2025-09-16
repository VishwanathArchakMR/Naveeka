// lib/ui/components/common/floating_button.dart

import 'package:flutter/material.dart';

/// Variants mirroring Material 3 FAB constructors. [regular|small|large|extended]
enum FloatingButtonKind { regular, small, large, extended }

/// A flexible FAB wrapper:
/// - Supports M3 variants (regular/small/large/extended)
/// - Loading state swaps icon/label with a spinner
/// - Optional badge count
/// - Animated show/hide with scale+fade
/// - Wide-gamut safe (uses Color.withValues)
class FloatingButton extends StatelessWidget {
  const FloatingButton({
    super.key,
    required this.onPressed,
    this.kind = FloatingButtonKind.regular,
    this.icon,
    this.label,
    this.tooltip,
    this.heroTag,
    this.loading = false,
    this.enabled = true,
    this.badgeCount,
    this.show = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.extendedPadding,
  });

  /// Primary action callback; disabled when loading=false and enabled=false.
  final VoidCallback onPressed;

  /// FAB visual variant.
  final FloatingButtonKind kind;

  /// Icon for regular/small/large; also shown on extended when provided.
  final Widget? icon;

  /// Label for extended variant; ignored otherwise.
  final String? label;

  /// Tooltip text for accessibility.
  final String? tooltip;

  /// Hero tag pass-through for FAB transitions.
  final Object? heroTag;

  /// If true, shows a CircularProgressIndicator in place of content.
  final bool loading;

  /// Global enabled/disabled flag.
  final bool enabled;

  /// Optional small numeric badge over the FAB.
  final int? badgeCount;

  /// Animated visibility; when false, button shrinks/fades out but keeps layout outside of Scaffold FAB slot.
  final bool show;

  /// Optional background and foreground color overrides (prefer theme defaults).
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Optional elevation override (Material 3 supports lower elevations by default).
  final double? elevation;

  /// Optional padding for extended variant content.
  final EdgeInsetsGeometry? extendedPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final bool isEnabled = enabled && !loading;
    final Color bg = backgroundColor ?? cs.primaryContainer;
    final Color fg = foregroundColor ?? cs.onPrimaryContainer;

    final Widget spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(fg),
      ),
    );

    final Widget iconWidget = loading
        ? spinner
        : (icon ??
            Icon(
              Icons.add_rounded,
              color: fg,
              size: kind == FloatingButtonKind.small ? 20 : 24,
            ));

    final Widget? labelWidget = (kind == FloatingButtonKind.extended && label != null && label!.trim().isNotEmpty)
        ? (loading
            ? Text(
                'Please wait',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
              )
            : Text(
                label!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ))
        : null;

    final Widget fabCore = _buildFab(
      context: context,
      bg: bg,
      fg: fg,
      icon: iconWidget,
      label: labelWidget,
      isEnabled: isEnabled,
    );

    final Widget withBadge = _BadgeOverlay(
      count: badgeCount,
      child: fabCore,
      fg: fg,
      cs: cs,
    );

    final Widget withTooltip = (tooltip != null && tooltip!.trim().isNotEmpty)
        ? Tooltip(message: tooltip!, child: withBadge)
        : withBadge;

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: show ? 1.0 : 0.85,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        opacity: show ? 1.0 : 0.0,
        child: withTooltip,
      ),
    );
  }

  Widget _buildFab({
    required BuildContext context,
    required Color bg,
    required Color fg,
    required Widget icon,
    required Widget? label,
    required bool isEnabled,
  }) {
    final onTap = isEnabled ? onPressed : null;

    // Apply elevation override via theme extension on the widget when provided.
    final Widget fab;
    switch (kind) {
      case FloatingButtonKind.small:
        fab = FloatingActionButton.small(
          heroTag: heroTag,
          tooltip: tooltip,
          onPressed: onTap,
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          child: icon,
        );
        break;
      case FloatingButtonKind.large:
        fab = FloatingActionButton.large(
          heroTag: heroTag,
          tooltip: tooltip,
          onPressed: onTap,
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          child: icon,
        );
        break;
      case FloatingButtonKind.extended:
        // When label is null, fall back to a regular FAB.
        if (label == null) {
          fab = FloatingActionButton(
            heroTag: heroTag,
            tooltip: tooltip,
            onPressed: onTap,
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: elevation,
            child: icon,
          );
        } else {
          fab = FloatingActionButton.extended(
            heroTag: heroTag,
            tooltip: tooltip,
            onPressed: onTap,
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: elevation,
            extendedPadding: extendedPadding ??
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
            icon: icon,
            label: label!,
          );
        }
        break;
      case FloatingButtonKind.regular:
      default:
        fab = FloatingActionButton(
          heroTag: heroTag,
          tooltip: tooltip,
          onPressed: onTap,
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          child: icon,
        );
        break;
    }
    return fab;
  }
}

class _BadgeOverlay extends StatelessWidget {
  const _BadgeOverlay({
    required this.count,
    required this.child,
    required this.fg,
    required this.cs,
  });

  final int? count;
  final Widget child;
  final Color fg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (count == null || count! <= 0) return child;

    final String text = count! > 99 ? '99+' : '$count';
    final Color badgeBg = fg.withValues(alpha: 0.12); // wide-gamut safe alpha
    final Color border = cs.surface; // creates a halo to separate from content

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
