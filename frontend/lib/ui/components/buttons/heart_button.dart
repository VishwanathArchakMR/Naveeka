// lib/ui/components/buttons/heart_button.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// A toggleable heart (like) button with async-optimistic behavior,
/// scale pop, and a lightweight burst ring when toggled on. [1]
class HeartButton extends StatefulWidget {
  const HeartButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 24,
    this.compact = true,
    this.tooltip,
    this.semanticLabel,
    this.variant = HeartButtonVariant.filledTonal,
    this.animationDuration = const Duration(milliseconds: 220),
  });

  /// Current selection state; the widget is controlled. [3]
  final bool value;

  /// Called when user toggles; may be async (optimistic UI with rollback on error). [3]
  final FutureOr<void> Function(bool next) onChanged;

  /// Disable interactions when false. [3]
  final bool enabled;

  /// Icon size in logical pixels. [3]
  final double size;

  /// Compact layout reduces surrounding padding in wrappers. [3]
  final bool compact;

  /// Optional tooltip text for accessibility. [3]
  final String? tooltip;

  /// Optional semantic label; defaults to contextual add/remove. [3]
  final String? semanticLabel;

  /// Visual style variant using Material 3 IconButton variants. [1]
  final HeartButtonVariant variant;

  /// Duration for the scale pop animation. [3]
  final Duration animationDuration;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

enum HeartButtonVariant { standard, filled, filledTonal, outlined }

class _HeartButtonState extends State<HeartButton> with TickerProviderStateMixin {
  late bool _localValue = widget.value;
  bool _busy = false;

  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
    lowerBound: 0.9,
    upperBound: 1.0,
    value: 1.0,
  );

  late final AnimationController _burstCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didUpdateWidget(HeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
      _pop();
      if (_localValue) _burst();
    }
  }

  Future<void> _toggle() async {
    if (!widget.enabled || _busy) return;
    final next = !_localValue;

    setState(() {
      _localValue = next;
      _busy = true;
    });
    _pop();
    if (next) _burst();

    try {
      await widget.onChanged(next);
    } catch (_) {
      setState(() {
        _localValue = !next; // rollback
      });
      _pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _pop() {
    _scaleCtrl
      ..value = 0.92
      ..forward();
  }

  void _burst() {
    _burstCtrl
      ..value = 0.0
      ..forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  IconButton _buildIconButton(BuildContext context) {
    final icon = Icon(
      _localValue ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: widget.size,
    );
    final selectedIcon = Icon(Icons.favorite_rounded, size: widget.size);
    final onPressed = (widget.enabled && !_busy) ? _toggle : null;

    switch (widget.variant) {
      case HeartButtonVariant.filled:
        return IconButton.filled(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case HeartButtonVariant.filledTonal:
        return IconButton.filledTonal(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case HeartButtonVariant.outlined:
        return IconButton.outlined(
          isSelected: _localValue,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
          icon: icon,
        );
      case HeartButtonVariant.standard:
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
      scale: _scaleCtrl,
      child: _buildIconButton(context),
    );

    final ring = _LikeBurst(
      controller: _burstCtrl,
      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45), // no withOpacity [2]
      size: (widget.size + 18),
    );

    final core = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        ring,
        btn,
      ],
    );

    final wrapped = (widget.tooltip != null && widget.tooltip!.trim().isNotEmpty)
        ? Tooltip(message: widget.tooltip!, child: core)
        : core;

    final semantics = Semantics(
      button: true,
      selected: _localValue,
      enabled: widget.enabled && !_busy,
      label: widget.semanticLabel ??
          (widget.value ? 'Remove from favorites' : 'Add to favorites'),
      child: wrapped,
    );

    return semantics;
  }
}

/// A simple, lightweight expanding ring burst drawn behind the icon. [3]
class _LikeBurst extends StatelessWidget {
  const _LikeBurst({
    required this.controller,
    required this.color,
    required this.size,
  });

  final Animation<double> controller;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeOut.transform(controller.value);
        final currentSize = size * (0.6 + 0.6 * t);
        final alpha = (0.35 * (1.0 - t)).clamp(0.0, 1.0);
        final ringColor = color.withValues(alpha: alpha); // wide-gamut safe [2]

        return IgnorePointer(
          child: Container(
            width: currentSize,
            height: currentSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2),
            ),
          ),
        );
      },
    );
  }
}
