// lib/features/atlas/presentation/atlas_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/common/search_bar.dart';
import '../../../ui/components/common/top_bar.dart';
import '../../../ui/components/common/filter_chips.dart';
import '../../../core/storage/seed_data_loader.dart';
import '../../../navigation/route_names.dart';
import '../../../models/place.dart';
import '../../../services/location_service.dart';
import 'widgets/list_view.dart';
import 'widgets/map_view.dart';
import 'widgets/map_list_toggle.dart';

enum AtlasView { list, map }

class AtlasScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? region;
  final bool? nearby;
  final bool? trending;

  const AtlasScreen({
    super.key,
    this.initialQuery,
    this.region,
    this.nearby,
    this.trending,
  });

  @override
  ConsumerState<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends ConsumerState<AtlasScreen> {
  AtlasView _currentView = AtlasView.list;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedEmotion = 'all';
  String _sortBy = 'distance';

  List<Place> _filteredPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery ?? '';
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);

    try {
      final atlasData = await ref.read(atlasDataProvider.future);
      List<Place> places = [];

      if (widget.nearby == true) {
        final nearbyPlacesData =
            atlasData['nearbyPlaces'] as List<dynamic>? ?? [];
        places = nearbyPlacesData
            .cast<Map<String, dynamic>>()
            .map((data) => Place.fromJson(data))
            .toList();
      } else if (widget.trending == true) {
        final trendingPlacesData =
            atlasData['trendingPlaces'] as List<dynamic>? ?? [];
        places = trendingPlacesData
            .cast<Map<String, dynamic>>()
            .map((data) => Place.fromJson(data))
            .toList();
      } else if (widget.region != null) {
        final regionPlacesData =
            atlasData['regionPlaces']?[widget.region] as List<dynamic>? ?? [];
        places = regionPlacesData
            .cast<Map<String, dynamic>>()
            .map((data) => Place.fromJson(data))
            .toList();
      } else {
        final allPlacesData = atlasData['places'] as List<dynamic>? ?? [];
        places = allPlacesData
            .cast<Map<String, dynamic>>()
            .map((data) => Place.fromJson(data))
            .toList();
      }

      _filteredPlaces = _applyFilters(places);
    } catch (e) {
      debugPrint('Error loading places: $e');
      _filteredPlaces = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Place> _applyFilters(List<Place> places) {
    var filtered = places.where((place) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = place.name.toLowerCase().contains(query);
        final matchesDescription =
            place.description?.toLowerCase().contains(query) ?? false;
        final matchesTags =
            place.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!matchesName && !matchesDescription && !matchesTags) {
          return false;
        }
      }

      if (_selectedCategory != 'all' &&
          place.category.name != _selectedCategory) {
        return false;
      }

      if (_selectedEmotion != 'all') {
        final hasEmotion =
            place.emotions.any((emotion) => emotion.name == _selectedEmotion);
        if (!hasEmotion) return false;
      }

      return true;
    }).toList();

    switch (_sortBy) {
      case 'distance':
        filtered.sort((a, b) {
          final aDistance = a.location.distanceFromUser ?? double.infinity;
          final bDistance = b.location.distanceFromUser ?? double.infinity;
          return aDistance.compareTo(bDistance);
        });
        break;
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'featured':
        filtered.sort((a, b) {
          if (a.isFeatured && !b.isFeatured) return -1;
          if (!a.isFeatured && b.isFeatured) return 1;
          return b.rating.compareTo(a.rating);
        });
        break;
    }

    return filtered;
  }

  void _onSearchChanged(String query, _) {
    setState(() {
      _searchQuery = query;
      _filteredPlaces = _applyFilters(_filteredPlaces);
    });
  }

  void _onFilterChanged() {
    _loadPlaces();
  }

  void _onViewToggle(AtlasView view) {
    setState(() => _currentView = view);
  }

  String _getScreenTitle() {
    if (widget.nearby == true) return 'Nearby Places';
    if (widget.trending == true) return 'Trending Places';
    if (widget.region != null) return '${widget.region} Region';
    return 'Atlas';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(
        title: _getScreenTitle(),
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await SeedDataLoader.instance.reload();
          await LocationService.instance.getCurrentLocation(forceRefresh: true);
          _loadPlaces();
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: AtlasSearchBar(
                onSearch: _onSearchChanged,
              ),
            ),
            AtlasFilterChips(
              selectedCategory: _selectedCategory,
              selectedEmotion: _selectedEmotion,
              sortBy: _sortBy,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
                _onFilterChanged();
              },
              onEmotionChanged: (emotion) {
                setState(() => _selectedEmotion = emotion);
                _onFilterChanged();
              },
              onSortChanged: (sortBy) {
                setState(() => _sortBy = sortBy);
                _onFilterChanged();
              },
            ),
            const SizedBox(height: 8),
            MapListToggle(
              currentView: _currentView,
              onViewChanged: _onViewToggle,
            ),
            const SizedBox(height: 8),
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${_filteredPlaces.length} places found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const Spacer(),
                    if (_searchQuery.isNotEmpty ||
                        _selectedCategory != 'all' ||
                        _selectedEmotion != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = 'all';
                            _selectedEmotion = 'all';
                            _sortBy = 'distance';
                          });
                          _loadPlaces();
                        },
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPlaces.isEmpty
                      ? _buildEmptyState()
                      : _currentView == AtlasView.list
                          ? AtlasListView(
                              places: _filteredPlaces,
                              onPlaceTap: (place) {
                                context.pushNamed(
                                  RouteNames.placeDetail,
                                  pathParameters: {'id': place.id},
                                );
                              },
                            )
                          : AtlasMapView(
                              places: _filteredPlaces,
                              onPlaceTap: (place) {
                                context.pushNamed(
                                  RouteNames.placeDetail,
                                  pathParameters: {'id': place.id},
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await LocationService.instance.getCurrentLocation(forceRefresh: true);
          _loadPlaces();
        },
        tooltip: 'Refresh location',
        child: const Icon(Icons.my_location_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No places found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Try searching for places or changing filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = 'all';
                      _selectedEmotion = 'all';
                    });
                    _loadPlaces();
                  },
                  child: const Text('Clear filters'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    context.goNamed(RouteNames.home);
                  },
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
