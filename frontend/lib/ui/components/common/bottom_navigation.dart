// lib/ui/components/common/bottom_navigation.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/route_names.dart';

/// Wraps the active ShellRoute branch and renders a 5-tab NavigationBar. [1]
class BottomNavigationShell extends ConsumerWidget {
  const BottomNavigationShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(
      index: 0,
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      path: RoutePaths.home,
    ),
    _NavTab(
      index: 1,
      label: 'Trails',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      path: RoutePaths.trails,
    ),
    _NavTab(
      index: 2,
      label: 'Atlas',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      path: RoutePaths.atlas,
    ),
    _NavTab(
      index: 3,
      label: 'Journey',
      icon: Icons.flight_takeoff_outlined,
      activeIcon: Icons.flight_takeoff_rounded,
      path: RoutePaths.journey,
    ),
    _NavTab(
      index: 4,
      label: 'Navee.AI',
      icon: Icons.mic_none_rounded,
      activeIcon: Icons.mic_rounded,
      path: RoutePaths.naveeAI,
    ),
  ];

  int _indexFromLocation(String location) {
    // Pick tab by path prefix match, default to Home. [9]
    if (location.startsWith(RoutePaths.trails)) return 1;
    if (location.startsWith(RoutePaths.atlas)) return 2;
    if (location.startsWith(RoutePaths.journey)) return 3;
    if (location.startsWith(RoutePaths.naveeAI)) return 4;
    return 0;
  }

  void _goToIndex(BuildContext context, int index) {
    final tab = _tabs[index];
    final current = GoRouter.of(context).location;
    if (current.startsWith(tab.path)) return;
    context.go(tab.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouter.of(context).location;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey<String>(location),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _goToIndex(context, i),
      height: 64,
      destinations: _tabs
          .map(
            (t) => NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NavTab {
  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavTab({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
