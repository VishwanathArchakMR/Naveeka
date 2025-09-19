// lib/features/quick_actions/presentation/favorites/widgets/favorite_places_list.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '/../../../models/place.dart';
// Use a clean, local import for the button in this favorites module.
import 'favorite_button.dart';
import '../../../../places/presentation/widgets/distance_indicator.dart';

class FavoritePlacesList extends StatefulWidget {
  const FavoritePlacesList({
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

  final String sectionTitle;
  final Widget? emptyPlaceholder;

  @override
  State<FavoritePlacesList> createState() => _FavoritePlacesListState();
}

class _FavoritePlacesListState extends State<FavoritePlacesList> {
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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 420) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // List lazy-loading pattern near end of extent [web:132].

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
            // Header
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
                      height: 16,
                      width: 16,
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
                    ? ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: widget.items.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          if (i == widget.items.length) return _footer();
                          final p = widget.items[i];
                          return _FavTile(
                            place: p,
                            originLat: widget.originLat,
                            originLng: widget.originLng,
                            onOpen: widget.onOpenPlace,
                            onToggleFavorite: widget.onToggleFavorite,
                          );
                        },
                      )
                    : _empty(),
              ),
            ), // RefreshIndicator wraps the list with pull-to-refresh behavior [web:132].
          ],
        ),
      ),
    );
  }

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
  }

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
        ); // Wide-gamut color withValues for consistent alpha [web:132].
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.place,
    this.originLat,
    this.originLng,
    this.onOpen,
    this.onToggleFavorite,
  });

  final Place place;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _nameOf(place);
    final category = _categoryOf(place);
    final photos = _photosOf(place);
    final lat = _latOf(place);
    final lng = _lngOf(place);
    final hasCoords = lat != null && lng != null;
    final subtitle = _subtitle(place);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _thumb(photos),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                category,
                style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (hasCoords && originLat != null && originLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DistanceIndicator.fromPlace(
                  place,
                  originLat: originLat!,
                  originLng: originLng!,
                  unit: UnitSystem.metric,
                  compact: true,
                  labelSuffix: 'away',
                ),
              ),
            ),
        ],
      ),
      trailing: FavoriteButton(
        // This FavoriteButton API requires `isFavorite` and `onChanged` -> Future<bool>.
        isFavorite: _isFavorite(place),
        onChanged: (next) async {
          final handler = onToggleFavorite;
          if (handler != null) {
            // Return the result to satisfy Future<bool> and avoid “body might complete normally”.
            return await handler(place, next);
          }
          // If no handler provided, report failure (no state change).
          return false;
        },
        size: 32,
        compact: true,
        tooltip: 'Favorite',
      ),
      onTap: onOpen == null ? null : () => onOpen!(place),
    ); // Non-null Future<bool> callback prevents incomplete-body errors [web:304][web:306][web:83].
  }

  // -------- JSON helpers for robust field access --------

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _nameOf(Place p) {
    final j = _json(p);
    return (j['name'] ?? j['title'] ?? j['label'] ?? 'Place').toString().trim();
  }

  String _categoryOf(Place p) {
    final j = _json(p);
    return (j['category'] ?? '').toString().trim();
  }

  List<String> _photosOf(Place p) {
    final j = _json(p);
    final v = j['photos'] ?? j['images'] ?? j['gallery'];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).cast<String>().toList();
    }
    return const <String>[];
  }

  double? _latOf(Place p) {
    final j = _json(p);
    return _d(j['lat'] ?? j['latitude'] ?? j['coord_lat'] ?? j['location_lat']);
  }

  double? _lngOf(Place p) {
    final j = _json(p);
    return _d(j['lng'] ?? j['lon'] ?? j['longitude'] ?? j['coord_lng'] ?? j['location_lng']);
  }

  bool _isFavorite(Place p) {
    final j = _json(p);
    final f = j['isFavorite'];
    final w = j['isWishlisted'] ?? j['wishlisted'];
    final fv = (f is bool) ? f : (f is String ? f.toLowerCase() == 'true' : false);
    final wv = (w is bool) ? w : (w is String ? w.toLowerCase() == 'true' : false);
    return fv || wv;
  }

  String _subtitle(Place p) {
    final j = _json(p);
    final parts = <String>[];
    final emo = (j['emotion'] ?? '').toString().trim();
    if (emo.isNotEmpty) parts.add(emo);
    final rating = _rating(j);
    final rc = _reviewsCount(j);
    if (rating != null) parts.add(rc > 0 ? '${rating.toStringAsFixed(1)} · $rc' : rating.toStringAsFixed(1));
    return parts.join(' · ');
  }

  double? _rating(Map<String, dynamic> j) {
    final v = j['rating'] ?? j['avgRating'] ?? j['averageRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int _reviewsCount(Map<String, dynamic> j) {
    final v = j['reviewsCount'] ?? j['reviewCount'] ?? j['reviews'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  double? _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // -------- UI helpers --------

  Widget _thumb(List<String> photos) {
    final url = photos.isNotEmpty ? photos.first.trim() : '';
    if (url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.place_outlined, color: Colors.black38),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
        ),
      ),
    );
  }
}
