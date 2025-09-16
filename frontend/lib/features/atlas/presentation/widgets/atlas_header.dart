// lib/features/atlas/presentation/widgets/atlas_header.dart

import 'package:flutter/material.dart';

import '../atlas_screen.dart';
import 'universal_search.dart';
import 'location_filters.dart';
import 'map_list_toggle.dart';

class AtlasHeader extends StatelessWidget {
  // View toggle
  final AtlasView currentView;
  final ValueChanged<AtlasView> onViewChanged;

  // Search
  final void Function(String) onSearch;

  // Filters (location-related)
  final double radiusKm;
  final bool openNow;
  final PriceFilter price;
  final RatingFilter rating;

  // Filter handlers
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onOpenNowChanged;
  final ValueChanged<PriceFilter> onPriceChanged;
  final ValueChanged<RatingFilter> onRatingChanged;
  final VoidCallback? onClearAll;

  const AtlasHeader({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.onSearch,
    required this.radiusKm,
    required this.openNow,
    required this.price,
    required this.rating,
    required this.onRadiusChanged,
    required this.onOpenNowChanged,
    required this.onPriceChanged,
    required this.onRatingChanged,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Universal search (with async results dropdown)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UniversalSearch(onSearch: onSearch),
        ),
        const SizedBox(height: 8),

        // Location filters row (open now, radius, price, rating)
        LocationFilters(
          radiusKm: radiusKm,
          openNow: openNow,
          price: price,
          rating: rating,
          onRadiusChanged: onRadiusChanged,
          onOpenNowChanged: onOpenNowChanged,
          onPriceChanged: onPriceChanged,
          onRatingChanged: onRatingChanged,
          onClearAll: onClearAll,
        ),
        const SizedBox(height: 8),

        // Map/List toggle
        MapListToggle(
          currentView: currentView,
          onViewChanged: onViewChanged,
        ),
      ],
    );
  }
}
