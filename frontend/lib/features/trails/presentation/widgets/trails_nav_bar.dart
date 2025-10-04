// lib/features/trails/presentation/widgets/trails_nav_bar.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TrailsNavBar extends StatelessWidget {
  const TrailsNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _NavItem(
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: 'Explore',
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _NavItem(
                    icon: Icons.add_box_outlined,
                    selectedIcon: Icons.add_box,
                    label: 'Create',
                    selected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                  _NavItem(
                    icon: Icons.favorite_outline,
                    selectedIcon: Icons.favorite,
                    label: 'Activity',
                    selected: selectedIndex == 3,
                    onTap: () => onSelected(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profile',
                    selected: selectedIndex == 4,
                    onTap: () => onSelected(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color fg = widget.selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final Color bg = widget.selected
        ? scheme.primary.withValues(alpha: 0.95)
        : Colors.transparent;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _pressed ? 0.96 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    widget.selected ? widget.selectedIcon : widget.icon,
                    key: ValueKey<bool>(widget.selected),
                    size: 22,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: fg,
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
