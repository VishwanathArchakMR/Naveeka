// lib/features/quick_actions/presentation/favorites/widgets/favorite_places_grid.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:naveeka/models/place.dart';
import 'package:naveeka/features/places/presentation/widgets/place_card.dart';

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
  } // Infinite scroll with a ScrollController near end-of-list threshold. [web:6119][web:6126]

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
                                    final curFav = _favoriteOf(p);
                                    final next = !curFav;
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
            ), // GridView.builder with RefreshIndicator for pull-to-refresh. [web:6126][web:6119]
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
  } // Width-based column count keeps a consistent grid layout. [web:6126]

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
  } // Footer shows loading or end-of-list state for pagination. [web:6119]

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
  } // Simple empty state using Material color roles. [web:6041]

  // --------- Robust mapper from Place -> Map expected by PlaceCard ----------

  Map<String, dynamic> _placeToMap(Place p) {
    final m = _json(p);
    final id = (m['id'] ?? m['_id'] ?? m['placeId'] ?? '').toString();
    final name = (m['name'] ?? m['title'])?.toString();
    final photos = _listOf<String>(m['photos']) ?? _listOf<String>(m['images']);
    final cover = (photos != null && photos.isNotEmpty)
        ? photos.first
        : ((m['imageUrl'] ?? m['cover'] ?? m['thumbnail'])?.toString());
    final cats = _listOf<String>(m['categories']) ?? _listOf<String>(m['tags']);
    final category = (m['category'] ?? m['type'] ?? (cats != null && cats.isNotEmpty ? cats.first : null))?.toString();
    final emotion = (m['emotion'] ?? m['mood'])?.toString();
    final rating = _doubleOf(m['rating'] ?? m['avgRating']);
    final reviewsCount = _intOf(m['reviewsCount'] ?? m['reviewCount']);
    final lat = _doubleOf(m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat']);
    final lng = _doubleOf(m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng']);
    final isApproved = _boolOf(m['isApproved'] ?? m['approved']);
    final isWishlisted = _boolOf(m['isFavorite'] ?? m['favorite'] ?? m['saved'] ?? m['liked'] ?? m['isWishlisted']);

    return {
      '_id': id,
      'id': id,
      'name': name,
      'coverImage': (cover is String && cover.trim().isNotEmpty) ? cover.trim() : null,
      'photos': photos,
      'category': category,
      'emotion': emotion,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'lat': lat,
      'lng': lng,
      'isApproved': isApproved,
      'isWishlisted': isWishlisted,
    };
  } // Use toJson-derived keys with fallbacks to avoid undefined getters. [web:5858][web:5860]

  bool _favoriteOf(Place p) {
    final m = _json(p);
    final v = m['isFavorite'] ?? m['favorite'] ?? m['saved'] ?? m['liked'] ?? m['isWishlisted'];
    return _boolOf(v) ?? false;
  } // Current favorite flag derived from common keys in the JSON map. [web:5858]

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  } // Safely read Place.toJson to support varying model shapes. [web:5858][web:6035]

  List<T>? _listOf<T>(dynamic v) {
    if (v is List) {
      try {
        return List<T>.from(v);
      } catch (_) {
        if (T == String) {
          return v.map((e) => e.toString()).cast<T>().toList();
        }
      }
    }
    return null;
  } // Defensive list conversion for heterogeneous JSON arrays. [web:5858]

  double? _doubleOf(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Parse numeric strings to double for UI friendliness. [web:5858]

  int? _intOf(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  } // Normalize JSON counts to int. [web:5858]

  bool? _boolOf(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return null;
  } // Parse boolean-like strings to bool. [web:5858]
}
