// lib/features/journey/presentation/widgets/journey_home.dart

import 'package:flutter/material.dart';

import '../widgets/category_cards.dart';

// Entry screens wired earlier
import '../../flights/flight_search_screen.dart';
import '../../hotels/hotel_search_screen.dart';
import '../../places/place_search_screen.dart';
import '../../restaurants/restaurant_search_screen.dart';
import '../../trains/train_search_screen.dart';

class JourneyHome extends StatelessWidget {
  const JourneyHome({super.key, this.title = 'Plan your journey'});

  final String title;

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final items = <CategoryItem>[
      CategoryItem(
        id: 'flights',
        title: 'Flights',
        subtitle: 'Search and book',
        icon: Icons.flight_takeoff_outlined,
        color: Colors.blue.shade50,
        badge: 'New',
        heroTag: 'cat-flights',
        onTap: () => _go(context, const FlightSearchScreen()),
      ),
      CategoryItem(
        id: 'hotels',
        title: 'Hotels',
        subtitle: 'Stay your way',
        icon: Icons.hotel_outlined,
        color: Colors.purple.shade50,
        heroTag: 'cat-hotels',
        onTap: () => _go(context, const HotelSearchScreen()),
      ),
      CategoryItem(
        id: 'places',
        title: 'Places',
        subtitle: 'Things to do',
        icon: Icons.attractions_outlined,
        color: Colors.teal.shade50,
        heroTag: 'cat-places',
        onTap: () => _go(context, const PlaceSearchScreen()),
      ),
      CategoryItem(
        id: 'restaurants',
        title: 'Restaurants',
        subtitle: 'Eat & reserve',
        icon: Icons.restaurant_menu_outlined,
        color: Colors.orange.shade50,
        heroTag: 'cat-restaurants',
        onTap: () => _go(context, const RestaurantSearchScreen()),
      ),
      CategoryItem(
        id: 'trains',
        title: 'Trains',
        subtitle: 'Reserve seats',
        icon: Icons.train_outlined,
        color: Colors.green.shade50,
        heroTag: 'cat-trains',
        onTap: () => _go(context, const TrainSearchScreen()),
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
                    child: Text(
                      'Discover, compare, and book',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Explore', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: CategoryCards(
                items: items,
                layout: CategoryCardsLayout.grid,
                crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 3 : 2,
                tileAspectRatio: 1.8,
                gap: 12,
                semanticLabel: 'Journey categories',
              ),
            ),
          ),
          // Optional: horizontal quick links section (reuse CategoryCards horizontal)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Shortcuts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: CategoryCards(
                items: [
                  CategoryItem(
                    id: 'map-hotels',
                    title: 'Hotels on map',
                    subtitle: 'Browse nearby',
                    icon: Icons.map_outlined,
                    color: Colors.indigo.shade50,
                    onTap: () => _go(context, const HotelSearchScreen()),
                  ),
                  CategoryItem(
                    id: 'today-places',
                    title: 'Today’s activities',
                    subtitle: 'Book for today',
                    icon: Icons.today_outlined,
                    color: Colors.cyan.shade50,
                    onTap: () => _go(context, const PlaceSearchScreen()),
                  ),
                  CategoryItem(
                    id: 'table-now',
                    title: 'Table now',
                    subtitle: 'Reserve near you',
                    icon: Icons.event_seat_outlined,
                    color: Colors.red.shade50,
                    onTap: () => _go(context, const RestaurantSearchScreen()),
                  ),
                ],
                layout: CategoryCardsLayout.horizontal,
                horizontalHeight: 110,
                gap: 12,
                semanticLabel: 'Quick shortcuts',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
