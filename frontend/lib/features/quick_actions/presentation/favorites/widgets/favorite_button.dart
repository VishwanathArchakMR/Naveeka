// lib/features/quick_actions/presentation/favorites/widgets/favorite_button.dart

import 'package:flutter/material.dart';

/// A compact favorite toggle with:
/// - Animated heart icon (filled/outline)
/// - Optional counter badge with animation
/// - Optimistic tap behavior with error revert
/// - Accessibility semantics & tooltip
/// - Uses Color.withValues(...) (no deprecated withOpacity)
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    this.count,
    this.onChanged, // Future<bool> Function(bool next)
    this.size = 28,
    this.compact = false,
    this.tooltip,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.elevation = 1,
    this.borderRadius = 999,
    this.disabled = false,
  });

  /// Current favorite state.
  final bool isFavorite;

  /// Optional count to show as a small badge at the corner.
  final int? count;

  /// Callback invoked with desired next state.
  /// Return true on success, false (or throw) to revert.
  final Future<bool> Function(bool next)? onChanged;

  /// Icon button tap target height/width in logical pixels.
  final double size;

  /// If true, renders icon-only; if false, shows a small pill background.
  final bool compact;

  /// Optional tooltip for long-press.
  final String? tooltip;

  /// Override icon color when selected (defaults to theme.primary).
  final Color? activeColor;

  /// Override icon color when not selected (defaults to onSurfaceVariant).
  final Color? inactiveColor;

  /// Override background tint for non-compact style.
  final Color? backgroundColor;

  /// Elevation for non-compact style container.
  final double elevation;

  /// Border radius for non-compact style container.
  final double borderRadius;

  /// Disable interactions (e.g., while global requests in flight).
  final bool disabled;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _busy = false;
  late bool _fav;
  int? _count;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFavorite;
    _count = widget.count;
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) _fav = widget.isFavorite;
    if (oldWidget.count != widget.count) _count = widget.count;
  }

  Future<void> _toggle() async {
    if (_busy || widget.disabled) return;
    final next = !_fav;
    setState(() {
      _busy = true;
      _fav = next;
      if (_count != null) _count = (next ? (_count ?? 0) + 1 : (_count ?? 1) - 1).clamp(0, 1 << 31);
    });

    try {
      final ok = await (widget.onChanged?.call(next) ?? Future.value(true));
      if (!ok) throw Exception('Rejected');
    } catch (_) {
      if (!mounted) return;
      // Revert on failure
      setState(() {
        _fav = !next;
        if (_count != null) _count = (!next ? (_count ?? 0) + 1 : (_count ?? 1) - 1).clamp(0, 1 << 31);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorite')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? cs.primary;
    final inactive = widget.inactiveColor ?? cs.onSurfaceVariant;
    final bg = widget.backgroundColor ?? cs.surfaceContainerHigh.withValues(alpha: 1.0);

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Icon(
        _fav ? Icons.favorite : Icons.favorite_border,
        key: ValueKey<bool>(_fav),
        color: _fav ? active : inactive,
        size: widget.compact ? (widget.size * 0.7) : (widget.size * 0.6),
      ),
    );

    final content = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        icon,
        if (_count != null)
          Positioned(
            right: -2,
            top: -2,
            child: _CountBadge(value: _count!.clamp(0, 9999)),
          ),
      ],
    );

    final button = Semantics(
      button: true,
      toggled: _fav,
      label: widget.tooltip ?? 'Favorite',
      child: Tooltip(
        message: widget.tooltip ?? (_fav ? 'Remove from favorites' : 'Add to favorites'),
        child: InkWell(
          onTap: (_busy || widget.disabled) ? null : _toggle,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(child: content),
          ),
        ),
      ),
    );

    if (widget.compact) {
      return button;
    }

    return Material(
      elevation: widget.elevation,
      color: bg,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: button,
      ),
    );
  }
}

/// Small numeric badge for the favorite count.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary.withValues(alpha: 0.14);
    final fg = cs.primary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey<int>(value),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value > 999 ? '999+' : '$value',
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
