// lib/features/quick_actions/presentation/favorites/widgets/favorite_places_grid.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../places/presentation/widgets/place_card.dart';

class FavoritePlacesGrid extends StatefulWidget {
  const FavoritePlacesGrid({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenPlace,
    this.onToggleFavorite, // Future<bool> Function(Place place, bool next)
    this.originLat,
    this.originLng,
    this.heroPrefix = 'fav-grid',
    this.sectionTitle = 'Favorites',
    this.emptyPlaceholder,
  });

  final List<Place> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(Place place)? onOpenPlace;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  final double? originLat;
  final double? originLng;
  final String heroPrefix;
  final String sectionTitle;

  final Widget? emptyPlaceholder;

  @override
  State<FavoritePlacesGrid> createState() => _FavoritePlacesGridState();
}

class _FavoritePlacesGridState extends State<FavoritePlacesGrid> {
  final _scroll = ScrollController();
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Infinite scroll requests the next page when nearing the end, matching common GridView.builder pagination patterns. [2][14]

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.items.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.sectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (widget.loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: widget.onRefresh,
                child: hasAny
                    ? GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        gridDelegate: _responsiveDelegate(context),
                        itemCount: widget.items.length + 1,
                        itemBuilder: (context, i) {
                          if (i == widget.items.length) return _footer();
                          final p = widget.items[i];
                          final map = _placeToMap(p);
                          return PlaceCard(
                            place: map,
                            originLat: widget.originLat,
                            originLng: widget.originLng,
                            heroPrefix: widget.heroPrefix,
                            onToggleWishlist: widget.onToggleFavorite == null
                                ? null
                                : () async {
                                    // Optimistic toggle via callback; PlaceCard uses the map for UI state
                                    final next = !(p.isFavorite ?? false);
                                    final ok = await widget.onToggleFavorite!(p, next);
                                    if (!ok && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not update favorite')),
                                      );
                                    }
                                  },
                          );
                        },
                      )
                    : _empty(),
              ),
            ), // GridView.builder lazily builds tiles for large lists and works well with RefreshIndicator for pull-to-refresh. [2][21]
          ],
        ),
      ),
    );
  }

  SliverGridDelegate _responsiveDelegate(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cross = w >= 1100 ? 4 : (w >= 750 ? 3 : 2);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cross,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 4 / 5,
    );
  } // A responsive SliverGridDelegate adjusts columns by width while keeping spacing and aspect ratio consistent for cards. [1][9]

  Widget _footer() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No more favorites')),
      );
    }
    return const SizedBox(height: 24);
  } // A footer indicator communicates progressive loading and end-of-list states for paginated grids. [1][8]

  Widget _empty() {
    return widget.emptyPlaceholder ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No favorites yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 1.0),
              ),
            ),
          ),
        );
  } // The empty state uses Color.withValues instead of withOpacity to comply with the wide-gamut color migration guidance. [10][19]

  Map<String, dynamic> _placeToMap(Place p) {
    return {
      '_id': p.id,
      'id': p.id,
      'name': p.name,
      'coverImage': (p.photos != null && p.photos!.isNotEmpty) ? p.photos!.first : null,
      'photos': p.photos,
      'category': (p.categories != null && p.categories!.isNotEmpty) ? p.categories!.first : null,
      'emotion': p.emotion,
      'rating': p.rating,
      'reviewsCount': p.reviewsCount,
      'lat': p.lat,
      'lng': p.lng,
      'isApproved': p.isApproved,
      'isWishlisted': p.isFavorite,
    };
  } // PlaceCard expects a Map; this adapter maps Place fields to expected keys including isWishlisted for the heart icon. [1][11]
}
