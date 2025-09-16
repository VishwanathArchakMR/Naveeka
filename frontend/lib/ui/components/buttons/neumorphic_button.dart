// lib/ui/components/buttons/neumorphic_button.dart

import 'package:flutter/material.dart';

/// A reusable premium button with a neumorphic "soft UI" depth effect.
/// - Twin shadows create raised depth on neutral surfaces
/// - Optional gradient for subtle sheen
/// - Proper ripple via Ink + InkWell over Material
/// - Wide-gamut safe: uses Color.withValues instead of withOpacity
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.height = 50,
    this.borderRadius = 14,
    this.fontSize = 15,
    this.icon,
    this.expand = true,
    this.gradient,
    this.surfaceColor,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;

  final double height;
  final double borderRadius;
  final double fontSize;

  final IconData? icon;
  final bool expand;

  /// Optional gradient to enhance the soft sheen; if null, a subtle auto gradient is used.
  final Gradient? gradient;

  /// Override base surface color; falls back to theme surface container.
  final Color? surfaceColor;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Base surface chosen from theme, adjustable via prop.
    final Color base = widget.surfaceColor ?? cs.surfaceContainerHighest;

    // Light and dark shadow tones for soft UI; use withValues for alpha. [wide‑gamut safe]
    final Color lightShadow = Colors.white.withValues(alpha: theme.brightness == Brightness.light ? 0.9 : 0.20);
    final Color darkShadow = cs.shadow.withValues(alpha: theme.brightness == Brightness.light ? 0.20 : 0.45);

    // Optional subtle gradient to improve perceived depth.
    final Gradient gradient = widget.gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _tint(base, 0.06), // slightly lighter
            base,
            _shade(base, 0.04), // slightly darker
          ],
        );

    final Widget content = _buildContent(theme);

    final Widget core = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: base,
          gradient: widget.enabled ? gradient : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: widget.enabled
              ? <BoxShadow>[
                  // Light source top-left
                  BoxShadow(
                    color: lightShadow,
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
                  // Dark shadow bottom-right
                  BoxShadow(
                    color: darkShadow,
                    offset: const Offset(5, 6),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: InkWell(
          onTap: widget.enabled && !widget.loading ? widget.onPressed : null,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: widget.expand ? double.infinity : null,
                height: widget.height,
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.enabled && !widget.loading,
      label: widget.label,
      child: core,
    );
  }

  Widget _buildContent(ThemeData theme) {
    final cs = theme.colorScheme;
    final Color fg = _onSurfaceForSoft(theme);

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
      children.add(Icon(widget.icon, size: widget.fontSize + 4, color: fg));
      children.add(const SizedBox(width: 8));
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  // Choose a readable foreground for soft UI; prefer onSurface at medium emphasis.
  Color _onSurfaceForSoft(ThemeData theme) {
    final cs = theme.colorScheme;
    // Slightly reduce contrast for the soft style while maintaining readability.
    return cs.onSurface.withValues(alpha: theme.brightness == Brightness.light ? 0.85 : 0.90);
  }

  // Slightly lighten a color for gradient highlights.
  Color _tint(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  // Slightly darken a color for gradient shadows.
  Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

