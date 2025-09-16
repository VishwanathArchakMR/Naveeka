// lib/features/journey/presentation/journey_screen.dart

import 'package:flutter/material.dart';

import 'widgets/journey_top_nav.dart';
import 'widgets/journey_home.dart';

import 'hotels/hotel_search_screen.dart';
import 'places/place_search_screen.dart';
import 'restaurants/restaurant_search_screen.dart';
import 'trains/train_search_screen.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key, this.title = 'Journey'});

  final String title;

  @override
  Widget build(BuildContext context) {
    // Build tabs using the shared JourneyTopTab model so the top nav and content stay connected.
    final tabs = <JourneyTopTab>[
      JourneyTopTab(
        label: 'Home',
        icon: Icons.home_outlined,
        builder: (_) => const JourneyHome(title: 'Plan your journey'),
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

    // Use the convenience scaffold to wire DefaultTabController + AppBar.bottom TabBar + TabBarView.
    return JourneyTopNavScaffold(
      title: title,
      tabs: tabs,
      initialIndex: 0,
    );
  }
}
