// lib/ui/components/common/loading_spinner.dart

import 'package:flutter/material.dart';

/// Loading spinner variants supported.
enum SpinnerKind { circular, linear }

/// Predefined sizes for circular spinners.
enum SpinnerSize { tiny, small, medium, large }

/// A flexible Material 3 loading indicator:
/// - Circular or Linear
/// - Determinate (value 0..1) or indeterminate (null)
/// - Optional label/subLabel
/// - Optional fullscreen scrim overlay
/// - Wide-gamut safe (Color.withValues), M3 theming by default
class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({
    super.key,
    this.kind = SpinnerKind.circular,
    this.value,
    this.size = SpinnerSize.medium,
    this.strokeWidth,
    this.label,
    this.subLabel,
    this.center = true,
    this.color,
    this.backgroundColor,
    this.linearMinHeight,
    this.linearWidth,
    this.linearBorderRadius = 999,
    this.year2023 = true, // set to false to opt into latest M3 spec updates
  });

  /// Indicator kind (circular or linear).
  final SpinnerKind kind;

  /// Progress value [0..1] for determinate, or null for indeterminate.
  final double? value;

  /// Circular size preset (ignored for linear).
  final SpinnerSize size;

  /// Circular stroke width; defaults per size if null.
  final double? strokeWidth;

  /// Optional primary label under the spinner (for circular) or above (for linear).
  final String? label;

  /// Optional secondary label (e.g., "Downloading map tiles…").
  final String? subLabel;

  /// If true, wraps with Center for convenience (circular only).
  final bool center;

  /// Foreground color override (defaults to ColorScheme.primary).
  final Color? color;

  /// Background track color override (defaults to ColorScheme.surfaceContainerHighest).
  final Color? backgroundColor;

  /// Linear minHeight (thickness); defaults to 6 for M3 feel.
  final double? linearMinHeight;

  /// Linear width constraint; if null, expands.
  final double? linearWidth;

  /// Linear border radius; defaults to pill-like 999.
  final double linearBorderRadius;

  /// Keep true for 2023 spec, set false to adopt latest M3 progress indicator design.
  final bool year2023;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color fg = color ?? cs.primary;
    final Color bg = (backgroundColor ?? cs.surfaceContainerHighest).withValues(alpha: 0.9);

    switch (kind) {
      case SpinnerKind.circular:
        final (double s, double sw) = _circularMetrics();
        final spinner = Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: s,
              height: s,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: strokeWidth ?? sw,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
                backgroundColor: bg,
                year2023: year2023,
              ),
            ),
            if (label != null && label!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (subLabel != null && subLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subLabel!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
        return center ? Center(child: spinner) : spinner;

      case SpinnerKind.linear:
        final bar = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: linearWidth ?? 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (label != null && label!.trim().isNotEmpty) ...[
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(linearBorderRadius),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: linearMinHeight ?? 6,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                  backgroundColor: bg,
                  year2023: year2023,
                ),
              ),
              if (subLabel != null && subLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subLabel!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
        return center ? Center(child: bar) : bar;
    }
  }

  (double, double) _circularMetrics() {
    switch (size) {
      case SpinnerSize.tiny:
        return (18, 2);
      case SpinnerSize.small:
        return (24, 2.5);
      case SpinnerSize.medium:
        return (36, 3);
      case SpinnerSize.large:
        return (56, 4);
    }
  }
}

/// A fullscreen modal barrier with a centered spinner and optional labels.
/// Use this when blocking the whole screen during critical operations.
class FullscreenSpinner extends StatelessWidget {
  const FullscreenSpinner({
    super.key,
    this.label,
    this.subLabel,
    this.dismissible = false,
    this.scrimColor,
    this.spinnerColor,
    this.backgroundColor,
    this.value,
  });

  final String? label;
  final String? subLabel;
  final bool dismissible;
  final Color? scrimColor;
  final Color? spinnerColor;
  final Color? backgroundColor;
  final double? value; // determinate if provided

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Wide-gamut safe alpha scrim (no withOpacity).
    final Color scrim = (scrimColor ?? cs.surface).withValues(alpha: 0.65);
    final Color cardBg = (backgroundColor ?? cs.surfaceContainerHighest).withValues(alpha: 0.95);
    final Color fg = spinnerColor ?? cs.primary;

    return Stack(
      children: <Widget>[
        // Modal barrier
        ModalBarrier(
          color: scrim,
          dismissible: dismissible,
        ),
        // Center card with spinner
        Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.9),
                    year2023: true,
                  ),
                ),
                if (label != null && label!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
                if (subLabel != null && subLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subLabel!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
