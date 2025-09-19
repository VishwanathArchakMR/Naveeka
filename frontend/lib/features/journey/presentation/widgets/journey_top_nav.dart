// lib/features/journey/presentation/widgets/journey_top_nav.dart

import 'package:flutter/material.dart';

// Optional: plug real search screens or section roots
import '../flights/flight_search_screen.dart';
import '../../presentation/hotels/hotel_search_screen.dart';
import '../../presentation/places/place_search_screen.dart';
import '../../presentation/restaurants/restaurant_search_screen.dart';
import '../../presentation/trains/train_search_screen.dart';

class JourneyTopTab {
  const JourneyTopTab({
    required this.label,
    required this.icon,
    this.badge,
    this.builder, // Optional page for TabBarView convenience scaffold
  });

  final String label;
  final IconData icon;
  final String? badge;
  final WidgetBuilder? builder;
}

/// A TabBar for top navigation across journey sections (Flights/Hotels/Places/Restaurants/Trains). [1]
/// Place inside AppBar.bottom or SliverAppBar.bottom; relies on a TabController from DefaultTabController or explicit controller. [2][6]
class JourneyTopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const JourneyTopNavBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = true,
    this.onTap,
  });

  final List<JourneyTopTab> tabs;
  final TabController? controller;
  final bool isScrollable;
  final ValueChanged<int>? onTap;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? DefaultTabController.maybeOf(context);
    assert(ctrl != null,
        'JourneyTopNavBar requires a TabController via controller or DefaultTabController');
    return Material(
      color: Colors.transparent,
      child: TabBar(
        controller: ctrl,
        isScrollable: isScrollable,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: tabs.map((t) => _TabLabel(tab: t)).toList(growable: false),
        onTap: onTap,
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.tab});
  final JourneyTopTab tab;

  @override
  Widget build(BuildContext context) {
    final badge = tab.badge;
    return Tab(
      iconMargin: const EdgeInsets.only(bottom: 2),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(tab.icon),
          if (badge != null && badge.isNotEmpty)
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
      text: tab.label,
    );
  }
}

/// Convenience scaffold that wires DefaultTabController + AppBar + JourneyTopNavBar + TabBarView. [2][6]
/// Ideal for quickly bootstrapping a top-tabbed journey shell or embedding under a SliverAppBar via NestedScrollView in larger screens. [10]
class JourneyTopNavScaffold extends StatelessWidget {
  JourneyTopNavScaffold({
    super.key,
    this.title = 'Explore',
    List<JourneyTopTab>? tabs,
    this.initialIndex = 0,
  }) : _tabs = tabs ?? _defaultTabs;

  final String title;
  final int initialIndex;
  final List<JourneyTopTab> _tabs;

  static List<JourneyTopTab> get _defaultTabs => [
        JourneyTopTab(
          label: 'Flights',
          icon: Icons.flight_takeoff_outlined,
          badge: 'New',
          builder: (_) => const FlightSearchScreen(),
        ),
        JourneyTopTab(
          label: 'Hotels',
          icon: Icons.hotel_outlined,
          builder: (_) => const HotelSearchScreen(),
        ),
        JourneyTopTab(
          label: 'Places',
          icon: Icons.attractions_outlined,
          builder: (_) => const PlaceSearchScreen(),
        ),
        JourneyTopTab(
          label: 'Food',
          icon: Icons.restaurant_menu_outlined,
          builder: (_) => const RestaurantSearchScreen(),
        ),
        JourneyTopTab(
          label: 'Trains',
          icon: Icons.train_outlined,
          builder: (_) => const TrainSearchScreen(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialIndex.clamp(0, _tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: JourneyTopNavBar(tabs: _tabs),
        ),
        body: TabBarView(
          children: _tabs
              .map((t) => t.builder?.call(context) ?? const SizedBox.shrink())
              .toList(growable: false),
        ),
      ),
    );
  }
}
