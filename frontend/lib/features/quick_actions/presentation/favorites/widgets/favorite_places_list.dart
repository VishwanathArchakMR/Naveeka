// lib/features/quick_actions/presentation/favorites/widgets/favorite_places_list.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../favorites/widgets/favorite_button.dart';
import '../../../places/presentation/widgets/distance_indicator.dart';

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
  } // Infinite loading triggers as the user nears the end of the list, a common pattern with ListView builder APIs. [2]

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
            ), // RefreshIndicator adds pull-to-refresh semantics to the list and shows the adaptive spinner per platform. [12][18]
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 1.0)),
            ),
          ),
        ); // Use withValues for color alpha to comply with the wide-gamut color migration and avoid withOpacity precision loss. [13][7]
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
    final hasCoords = place.lat != null && place.lng != null;
    final subtitle = _subtitle();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _thumb(place.photos),
      title: Row(
        children: [
          Expanded(
            child: Text(
              (place.name ?? 'Place').trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          if ((place.category ?? '').toString().trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${place.category}'.trim(),
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
        isFavorite: place.isFavorite ?? (place.isWishlisted ?? false) == true,
        onChanged: onToggleFavorite == null ? null : (next) => onToggleFavorite!(place, next),
        size: 32,
        compact: true,
        tooltip: 'Favorite',
      ),
      onTap: onOpen == null ? null : () => onOpen!(place),
    ); // ListView.separated with ListTile provides an accessible, high-performance list with consistent separators and simple item composition. [1][2]
  }

  String _subtitle() {
    final parts = <String>[];
    if ((place.emotion ?? '').toString().trim().isNotEmpty) parts.add((place.emotion ?? '').toString().trim());
    if (place.rating != null) {
      final r = place.rating!.toStringAsFixed(1);
      final rc = (place.reviewsCount ?? 0);
      parts.add(rc > 0 ? '$r · $rc' : r);
    }
    return parts.join(' · ');
  }

  Widget _thumb(List<String>? photos) {
    final url = (photos != null && photos.isNotEmpty && photos.first.trim().isNotEmpty) ? photos.first.trim() : null;
    if (url == null) {
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
