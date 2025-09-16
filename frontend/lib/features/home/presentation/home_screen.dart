import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/theme/app_themes.dart';
import '../../../ui/components/common/top_bar.dart';
import '../../../ui/components/common/search_bar.dart';
import '../../../core/storage/seed_data_loader.dart';
import '../../../navigation/route_names.dart';
import '../../../services/location_service.dart';
import '../../../models/place.dart';
import 'widgets/hero_section.dart';
import 'widgets/quick_actions.dart';
import 'widgets/explore_by_region.dart';
import 'widgets/nearby_places.dart';
import 'widgets/nearby_hotels_restaurants.dart';
import 'widgets/trending_places.dart';
import 'widgets/whats_new_strip.dart';
import 'widgets/top_hotels_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initialize location service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.instance.getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 100;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Reload seed data
          await SeedDataLoader.instance.reload();
          // Refresh location
          await LocationService.instance.getCurrentLocation(forceRefresh: true);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Custom app bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              elevation: _isScrolled ? 1 : 0,
              backgroundColor: _isScrolled 
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppThemes.naveekaBlue.withValues(alpha: 0.1),
                        AppThemes.naveekaGreen.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const SafeArea(
                    child: HomeTopBar(),
                  ),
                ),
              ),
            ),

            // Main content
            homeDataAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: _buildErrorState(error),
              ),
              data: (homeData) => SliverList(
                delegate: SliverChildListDelegate([
                  // Hero Section
                  const HeroSection(),
                  
                  const SizedBox(height: 16),

                  // Search Bar
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: HomeSearchBar(),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions (6 horizontal buttons)
                  const QuickActionsRow(),

                  const SizedBox(height: 32),

                  // Explore by Region
                  ExploreByRegionSection(
                    regions: _extractRegions(homeData),
                  ),

                  const SizedBox(height: 32),

                  // Nearby Places
                  NearbyPlacesSection(
                    places: _extractNearbyPlaces(homeData),
                  ),

                  const SizedBox(height: 32),

                  // What's New Strip
                  WhatsNewStrip(
                    newsItems: _extractNewsItems(homeData),
                  ),

                  const SizedBox(height: 32),

                  // Nearby Hotels & Restaurants
                  NearbyHotelsRestaurantsSection(
                    hotels: _extractNearbyHotels(homeData),
                    restaurants: _extractNearbyRestaurants(homeData),
                  ),

                  const SizedBox(height: 32),

                  // Trending Places
                  TrendingPlacesSection(
                    places: _extractTrendingPlaces(homeData),
                  ),

                  const SizedBox(height: 32),

                  // Top Hotels List
                  TopHotelsListSection(
                    hotels: _extractTopHotels(homeData),
                  ),

                  const SizedBox(height: 32),

                  // Footer spacing
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load content',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Retry loading
              ref.invalidate(homeDataProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Data extraction methods (convert seed data to models)
  List<Map<String, dynamic>> _extractRegions(Map<String, dynamic> homeData) {
    final regions = homeData['regions'] as List<dynamic>? ?? [];
    return regions.cast<Map<String, dynamic>>();
  }

  List<Place> _extractNearbyPlaces(Map<String, dynamic> homeData) {
    final placesData = homeData['nearbyPlaces'] as List<dynamic>? ?? [];
    return placesData
        .cast<Map<String, dynamic>>()
        .map((data) => Place.fromJson(data))
        .toList();
  }

  List<Map<String, dynamic>> _extractNewsItems(Map<String, dynamic> homeData) {
    final news = homeData['whatsNew'] as List<dynamic>? ?? [];
    return news.cast<Map<String, dynamic>>();
  }

  List<Place> _extractNearbyHotels(Map<String, dynamic> homeData) {
    final hotelsData = homeData['nearbyHotels'] as List<dynamic>? ?? [];
    return hotelsData
        .cast<Map<String, dynamic>>()
        .map((data) => Place.fromJson(data))
        .toList();
  }

  List<Place> _extractNearbyRestaurants(Map<String, dynamic> homeData) {
    final restaurantsData = homeData['nearbyRestaurants'] as List<dynamic>? ?? [];
    return restaurantsData
        .cast<Map<String, dynamic>>()
        .map((data) => Place.fromJson(data))
        .toList();
  }

  List<Place> _extractTrendingPlaces(Map<String, dynamic> homeData) {
    final placesData = homeData['trendingPlaces'] as List<dynamic>? ?? [];
    return placesData
        .cast<Map<String, dynamic>>()
        .map((data) => Place.fromJson(data))
        .toList();
  }

  List<Place> _extractTopHotels(Map<String, dynamic> homeData) {
    final hotelsData = homeData['topHotels'] as List<dynamic>? ?? [];
    return hotelsData
        .cast<Map<String, dynamic>>()
        .map((data) => Place.fromJson(data))
        .toList();
  }
}

// Emergency fallback widget if seed data fails
class HomeFallbackContent extends StatelessWidget {
  const HomeFallbackContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppThemes.naveekaGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Naveeka',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover amazing places and plan your perfect journey',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Quick Actions (simplified)
          const QuickActionsRow(),

          const SizedBox(height: 32),

          // Call to action
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Exploring',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the search bar above or browse categories to find amazing places.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => context.goNamed(RouteNames.atlas),
                        child: const Text('Explore Atlas'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => context.goNamed(RouteNames.trails),
                        child: const Text('View Trails'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
