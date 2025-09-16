// lib/ui/components/buttons/favorite_button.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// A compact, toggleable favorite (heart) button with optional count,
/// async-optimistic support, and a subtle scale “pop” animation.
/// Uses Material 3 IconButton variants and avoids withOpacity. [1][3]
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.count,
    this.enabled = true,
    this.compact = true,
    this.tooltip,
    this.semanticLabel,
    this.size = 24,
    this.variant = FavoriteButtonVariant.filledTonal,
    this.animationDuration = const Duration(milliseconds: 220),
  });

  /// Current favorite state; the widget is controlled and reflects this value. [1]
  final bool value;

  /// Called when user toggles; may be async.
  /// If it throws, the UI reverts to the previous value. [1]
  final FutureOr<void> Function(bool next) onChanged;

  /// Optional like/favorite count to show next to the icon.
  final int? count;

  /// Set to false to disable taps.
  final bool enabled;

  /// Smaller padding for dense UIs if true.
  final bool compact;

  /// Optional tooltip string.
  final String? tooltip;

  /// Optional semantics label (falls back to tooltip or default).
  final String? semanticLabel;

  /// Icon size in logical pixels.
  final double size;

  /// Visual style for the icon button (M3 variants). [3]
  final FavoriteButtonVariant variant;

  /// Duration for the scale pop animation.
  final Duration animationDuration;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

enum FavoriteButtonVariant { standard, filled, filledTonal, outlined }

class _FavoriteButtonState extends State<FavoriteButton> with SingleTickerProviderStateMixin {
  late bool _localValue = widget.value;
  bool _busy = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
    lowerBound: 0.9,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
      // trigger a subtle pop when the external value changes
      _pop();
    }
  }

  Future<void> _toggle() async {
    if (!widget.enabled || _busy) return;
    final next = !_localValue;

    // Optimistically flip and animate
    setState(() {
      _localValue = next;
      _busy = true;
    });
    _pop();

    try {
      await widget.onChanged(next);
    } catch (_) {
      // Revert on error
      setState(() {
        _localValue = !next;
      });
      _pop();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _pop() {
    _controller
      ..value = 0.92
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconButton _buildIconButton(BuildContext context) {
    final icon = Icon(
      _localValue ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: widget.size,
    );

    final selectedIcon = Icon(
      Icons.favorite_rounded,
      size: widget.size,
    );

    final onPressed = (widget.enabled && !_busy) ? _toggle : null;

    switch (widget.variant) {
      case FavoriteButtonVariant.filled:
        return IconButton.filled(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case FavoriteButtonVariant.filledTonal:
        return IconButton.filledTonal(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case FavoriteButtonVariant.outlined:
        return IconButton.outlined(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case FavoriteButtonVariant.standard:
        return IconButton(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final btn = ScaleTransition(
      scale: _controller,
      child: _buildIconButton(context),
    );

    final core = widget.tooltip != null && widget.tooltip!.trim().isNotEmpty
        ? Tooltip(message: widget.tooltip!, child: btn)
        : btn;

    final semanticsLabel =
        widget.semanticLabel ?? widget.tooltip ?? (widget.value ? 'Remove from favorites' : 'Add to favorites');

    final count = widget.count;
    final showCount = count != null && count >= 0;

    final textStyle = widget.compact
        ? Theme.of(context).textTheme.labelMedium
        : Theme.of(context).textTheme.labelLarge;

    // Using Color.withValues for subtle badge background when needed, no withOpacity usage. [6][12]
    final Color fg = Theme.of(context).colorScheme.onSurface;
    final Color badgeBg = fg.withValues(alpha: 0.10);

    final countChip = Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8, vertical: widget.compact ? 2 : 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Text(
        _formatCount(count ?? 0),
        style: textStyle?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          selected: _localValue,
          button: true,
          label: semanticsLabel,
          child: core,
        ),
        if (showCount) SizedBox(width: widget.compact ? 6 : 8),
        if (showCount) countChip,
      ],
    );

    return row;
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }
}
