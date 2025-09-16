// lib/ui/components/buttons/gradient_button.dart

import 'package:flutter/material.dart';

/// A premium gradient call-to-action button with loading state, ripple,
/// and subtle press animation; no external theme dependencies. [12]
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.width,
    this.height = 50,
    this.borderRadius = 14,
    this.fontSize = 15,
    this.icon,
    this.gradient,
    this.textColor,
    this.glowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.tooltip,
    this.semanticLabel,
    this.enabled = true,
    this.elevation = 0,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;

  final Widget? icon;

  /// Optional override gradient. If null, a brand-like gradient is created
  /// from the current ColorScheme seed/primary. [6]
  final Gradient? gradient;

  /// Optional text color (defaults to a readable on-primary). [9]
  final Color? textColor;

  /// Optional glow color for box shadow (defaults to primary with low alpha, using withValues). [1]
  final Color? glowColor;

  final EdgeInsetsGeometry padding;

  final String? tooltip;
  final String? semanticLabel;
  final bool enabled;

  final double elevation;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    lowerBound: 0.98,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Gradient gradient = widget.gradient ?? _defaultGradient(cs);
    final Color fg = widget.textColor ?? _bestOnGradientText(cs);
    final Color glow = widget.glowColor ?? cs.primary.withValues(alpha: 0.22); // no withOpacity [1]

    final content = _buildContent(fg);

    final buttonCore = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.98 : 1.0,
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow,
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: (widget.enabled && !widget.loading) ? widget.onPressed : null,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: widget.width,
                height: widget.height,
              ),
              child: Padding(
                padding: widget.padding,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );

    final semantics = Semantics(
      button: true,
      enabled: widget.enabled && !widget.loading,
      label: widget.semanticLabel ?? widget.label,
      child: buttonCore,
    );

    if (widget.tooltip != null && widget.tooltip!.trim().isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: semantics);
    }
    return semantics;
  }

  Widget _buildContent(Color fg) {
    if (widget.loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }

    final children = <Widget>[];
    if (widget.icon != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconTheme(
          data: IconThemeData(color: fg, size: widget.fontSize + 2),
          child: widget.icon!,
        ),
      ));
    }
    children.add(Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    ));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  // Build a pleasant brand-like gradient from ColorScheme values. [12]
  Gradient _defaultGradient(ColorScheme cs) {
    final Color a = cs.primary;
    final Color b = cs.primaryContainer;
    // Mix withValues for a subtle light stop (no withOpacity). [1]
    final Color mid = Color.lerp(a, b, 0.35) ?? a;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[a, mid, b],
    );
  }

  // Choose readable text color for gradients (simple heuristic). [9]
  Color _bestOnGradientText(ColorScheme cs) {
    // Prefer onPrimary as a general readable choice on brand gradients.
    return cs.onPrimary;
  }
}
