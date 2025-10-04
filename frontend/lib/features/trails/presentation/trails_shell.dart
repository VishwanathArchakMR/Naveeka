// lib/features/trails/presentation/trails_shell.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TrailsShell extends StatelessWidget {
  const TrailsShell({super.key, required this.child});
  final Widget child;

  int _indexForLocation(String loc) {
    if (loc.startsWith('/trails/explore')) return 1;
    if (loc.startsWith('/trails/create')) return 2;
    if (loc.startsWith('/trails/activity')) return 3;
    if (loc.startsWith('/trails/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/trails/home');
        break;
      case 1:
        context.go('/trails/explore');
        break;
      case 2:
        context.go('/trails/create');
        break;
      case 3:
        context.go('/trails/activity');
        break;
      case 4:
        context.go('/trails/profile');
        break;
    }
  }

  String _subtitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Following';
      case 1:
        return 'Trending';
      case 2:
        return 'Create';
      case 3:
        return 'Activity';
      case 4:
        return 'My Profile';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(loc);

    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.65),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.30),
              ),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Trails', style: titleStyle),
                            const SizedBox(height: 2),
                            Text(
                              _subtitleForIndex(index),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: _TrailsNavBar(
        selectedIndex: index,
        onSelected: (i) => _onTap(context, i),
      ),
    );
  }
}

class _TrailsNavBar extends StatelessWidget {
  const _TrailsNavBar({
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
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
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

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final Color bg =
        selected ? _selectedFill(scheme) : Colors.transparent;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                  selected ? selectedIcon : icon,
                  key: ValueKey<bool>(selected),
                  size: 22,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _selectedFill(ColorScheme scheme) {
    // Approximate ~95% opacity of primary using withValues for precision
    return scheme.primary.withValues(alpha: 0.95);
  }
}
