// lib/features/places/presentation/widgets/favorite_heart_button.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/place.dart';

/// A reusable favorite/like heart button with:
/// - Smooth AnimatedSwitcher scale/fade animation on state change
/// - Haptic feedback on tap (light impact)
/// - Optional favorite count with AnimatedSwitcher
/// - Optimistic UI with async onChanged(bool next) -> Future<bool> to confirm/persist
/// - Size variants and semantic labels for accessibility
class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onChanged,
    this.count,
    this.size = 24,
    this.compact = false,
    this.activeColor,
    this.inactiveColor,
    this.tooltip,
    this.semanticLabel,
    this.disabled = false,
  });

  /// Build from your Place model fields.
  factory FavoriteHeartButton.fromPlace({
    Key? key,
    required Place place,
    required Future<bool> Function(bool next) onChanged,
    int? count,
    double size = 24,
    bool compact = false,
    Color? activeColor,
    Color? inactiveColor,
    String? tooltip,
    String? semanticLabel,
    bool disabled = false,
  }) {
    return FavoriteHeartButton(
      key: key,
      isFavorite: place.isFavorite ?? false,
      count: count ?? place.favoritesCount,
      onChanged: onChanged,
      size: size,
      compact: compact,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      tooltip: tooltip ?? 'Save',
      semanticLabel: semanticLabel ?? 'Toggle favorite',
      disabled: disabled,
    );
  }

  final bool isFavorite;
  final Future<bool> Function(bool next) onChanged;
  final int? count;

  /// Icon logical size (icon itself animates within).
  final double size;

  /// If true, hides the count label and keeps only the heart.
  final bool compact;

  final Color? activeColor;
  final Color? inactiveColor;

  final String? tooltip;
  final String? semanticLabel;

  final bool disabled;

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton> {
  late bool _fav;
  late int? _count;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFavorite;
    _count = widget.count;
  }

  @override
  void didUpdateWidget(covariant FavoriteHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) _fav = widget.isFavorite;
    if (oldWidget.count != widget.count) _count = widget.count;
  }

  Future<void> _toggle() async {
    if (widget.disabled || _busy) return;
    final next = !_fav;

    // Optimistic update
    setState(() {
      _fav = next;
      if (_count != null) _count = (_count! + (next ? 1 : -1)).clamp(0, 1 << 31);
      _busy = true;
    });

    // Light haptic for positive feedback
    HapticFeedback.lightImpact(); // Triggering HapticFeedback adds tactile confirmation for interactions. [13][7]

    try {
      final ok = await widget.onChanged(next);
      if (!ok) {
        // Revert if backend rejects
        setState(() {
          _fav = !next;
          if (_count != null) _count = (_count! + (!next ? 1 : -1)).clamp(0, 1 << 31);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final inactive = widget.inactiveColor ?? Colors.black38;

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        // Scale + fade on change
        return ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child));
      },
      child: Icon(
        _fav ? Icons.favorite : Icons.favorite_border,
        key: ValueKey<bool>(_fav),
        color: _fav ? active : inactive,
        size: widget.size,
      ),
    ); // AnimatedSwitcher cross-fades and can scale between old/new children when the keyed child changes. [12][6]

    final btn = IconButton(
      tooltip: widget.tooltip ?? (_fav ? 'Saved' : 'Save'),
      onPressed: widget.disabled ? null : _toggle,
      icon: icon,
      // Keeping IconButton ensures proper Material semantics and minimum tap size. [1][2]
    );

    if (widget.compact) {
      return Semantics(
        button: true,
        label: widget.semanticLabel ?? 'Favorite',
        value: _fav ? 'on' : 'off',
        child: btn,
      );
    }

    // With count label
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: widget.semanticLabel ?? 'Favorite',
          value: _fav ? 'on' : 'off',
          child: btn,
        ),
        if (_count != null) ...[
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Text(
              '${_count!}',
              key: ValueKey<int>(_count!),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ), // AnimatedSwitcher is ideal to animate numeric label changes smoothly when the count updates. [12][9]
        ],
      ],
    );
  }
}
