// lib/features/quick_actions/presentation/history/widgets/rebook_button.dart

import 'package:flutter/material.dart';

/// A reusable “Rebook” button widget with:
/// - Busy state and progress spinner
/// - Success/error feedback via SnackBar (optional)
/// - Variants: compact icon-only or filled button
/// - Uses Color.withValues(...) (no deprecated withOpacity)
class RebookButton extends StatefulWidget {
  const RebookButton({
    super.key,
    required this.onRebook, // Future<bool> Function()
    this.enabled = true,
    this.compact = false,
    this.label = 'Rebook',
    this.tooltip,
    this.showSnackbars = true,
    this.size = 40,
    this.icon = Icons.event_available_outlined,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Trigger the rebooking workflow (quote + create reservation or deep link).
  /// Return true on success to show a success toast (if enabled).
  final Future<bool> Function() onRebook;

  /// Disable the button (e.g., user not authenticated or invalid state).
  final bool enabled;

  /// Render as icon-only pill when true, else a standard filled button.
  final bool compact;

  /// Label for the filled variant.
  final String label;

  /// Tooltip for long-press/accessibility (compact variant).
  final String? tooltip;

  /// Whether to show SnackBars for success/failure.
  final bool showSnackbars;

  /// Visual size for the compact icon variant.
  final double size;

  /// Icon to display.
  final IconData icon;

  /// Optional color overrides.
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<RebookButton> createState() => _RebookButtonState();
}

class _RebookButtonState extends State<RebookButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.compact) {
      final bg = (widget.backgroundColor ?? cs.primary).withValues(alpha: 0.15);
      final fg = widget.foregroundColor ?? cs.primary;

      final child = _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon, color: fg, size: 18);

      final button = InkWell(
        onTap: (!widget.enabled || _busy) ? null : _handleTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );

      return Tooltip(
        message: widget.tooltip ?? widget.label,
        child: button,
      );
    }

    // Filled button variant
    final bg = widget.backgroundColor ?? cs.primary;
    final fg = widget.foregroundColor ?? cs.onPrimary;

    return ElevatedButton.icon(
      onPressed: (!widget.enabled || _busy) ? null : _handleTap,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ); // ElevatedButton is the modern Material filled button for prominent actions like “Rebook”. [1][2]
  }

  Future<void> _handleTap() async {
    setState(() => _busy = true);
    try {
      final ok = await widget.onRebook();
      if (widget.showSnackbars && mounted) {
        final msg = ok ? 'Rebooked' : 'Could not rebook';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (widget.showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not rebook')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
