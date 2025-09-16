// lib/features/places/presentation/widgets/place_header.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import 'favorite_heart_button.dart';
import 'map_view_button.dart';
import 'directions_button.dart';

/// Collapsible image header for place details screens:
/// - SliverAppBar + FlexibleSpaceBar with cover image and gradient overlay
/// - Hero image for shared transitions
/// - Top-right actions: Favorite, Map view, Directions
/// Use inside a CustomScrollView as a sliver. [SliverAppBar docs reference]
class PlaceHeaderSliver extends StatelessWidget {
  const PlaceHeaderSliver({
    super.key,
    required this.place,
    this.expandedHeight = 260,
    this.heroTag,
    this.originLat,
    this.originLng,
    this.onToggleFavorite,
    this.favoriteCount,
  });

  final Place place;
  final double expandedHeight;
  final String? heroTag;

  /// Optional origin for “Directions” defaulting current location in apps if omitted.
  final double? originLat;
  final double? originLng;

  /// Hook to persist favorite toggles.
  final Future<bool> Function(bool next)? onToggleFavorite;
  final int? favoriteCount;

  @override
  Widget build(BuildContext context) {
    final img = _coverUrl(place);
    final title = (place.name ?? '').trim().isEmpty ? 'Place' : place.name!.trim();

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        if (onToggleFavorite != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FavoriteHeartButton.fromPlace(
              place: place,
              onChanged: onToggleFavorite!,
              count: favoriteCount,
              compact: true,
              tooltip: 'Save',
            ),
          ),
        if (place.lat != null && place.lng != null)
          IconButton(
            tooltip: 'Map view',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              // Push an in-app map page if desired, else fallback to external maps.
              MapViewButton.fromPlace(place, extended: false).onPressed?.call();
            },
          ),
        if (place.lat != null && place.lng != null)
          IconButton(
            tooltip: 'Directions',
            icon: const Icon(Icons.directions_outlined),
            onPressed: () {
              DirectionsButton.fromPlace(place, expanded: false).onPressed?.call();
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12, end: 56),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              Hero(
                tag: heroTag ?? 'place-hero-${place.id}',
                child: Image.network(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(),
                  loadingBuilder: (context, child, prog) {
                    if (prog == null) return child;
                    return _loading();
                  },
                ),
              )
            else
              _fallback(),
            // Gradient overlay for legible title
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, 0.6),
                  end: Alignment(0, 1),
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _coverUrl(Place p) {
    final list = p.photos ?? const <String>[];
    return list.isNotEmpty && list.first.trim().isNotEmpty ? list.first.trim() : null;
  }

  Widget _fallback() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_size_select_actual_outlined, size: 48, color: Colors.black26),
    );
  }

  Widget _loading() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Non-sliver header card for places:
/// - Rounded cover image with Hero
/// - Title, category chips, rating, and inline actions
/// Good for screens without CustomScrollView/slivers.
class PlaceHeaderCard extends StatelessWidget {
  const PlaceHeaderCard({
    super.key,
    required this.place,
    this.heroTag,
    this.onToggleFavorite,
    this.favoriteCount,
    this.showCategories = true,
    this.showRating = true,
  });

  final Place place;
  final String? heroTag;
  final Future<bool> Function(bool next)? onToggleFavorite;
  final int? favoriteCount;
  final bool showCategories;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final img = _coverUrl(place);
    final title = (place.name ?? '').trim().isEmpty ? 'Place' : place.name!.trim();
    final cats = _categories(place);
    final rating = place.rating;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cover
          AspectRatio(
            aspectRatio: 16 / 9,
            child: img == null
                ? _fallback()
                : Hero(
                    tag: heroTag ?? 'place-hero-${place.id}',
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                      loadingBuilder: (context, child, prog) {
                        if (prog == null) return child;
                        return _loading();
                      },
                    ),
                  ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + actions
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onToggleFavorite != null)
                      FavoriteHeartButton.fromPlace(
                        place: place,
                        onChanged: onToggleFavorite!,
                        count: favoriteCount,
                        compact: true,
                        tooltip: 'Save',
                      ),
                    if (place.lat != null && place.lng != null)
                      IconButton(
                        tooltip: 'Map view',
                        icon: const Icon(Icons.map_outlined),
                        onPressed: () {
                          MapViewButton.fromPlace(place, extended: false).onPressed?.call();
                        },
                      ),
                    if (place.lat != null && place.lng != null)
                      IconButton(
                        tooltip: 'Directions',
                        icon: const Icon(Icons.directions_outlined),
                        onPressed: () {
                          DirectionsButton.fromPlace(place, expanded: false).onPressed?.call();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Rating
                if (showRating && rating != null)
                  Row(
                    children: [
                      _stars(rating),
                      const SizedBox(width: 6),
                      Text(rating.toStringAsFixed(1)),
                      if ((place.reviewsCount ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Text('· ${place.reviewsCount} reviews', style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),

                // Categories
                if (showCategories && cats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((c) => Chip(label: Text(c), visualDensity: VisualDensity.compact)).toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _coverUrl(Place p) {
    final list = p.photos ?? const <String>[];
    return list.isNotEmpty && list.first.trim().isNotEmpty ? list.first.trim() : null;
  }

  List<String> _categories(Place p) {
    final list = p.categories ?? const <String>[];
    return list.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  Widget _stars(double rating) {
    // Draw 5-star row with half-step visualization
    final widgets = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      final icon = rating >= i - 0.25
          ? Icons.star
          : (rating >= i - 0.75 ? Icons.star_half : Icons.star_border);
      widgets.add(Icon(icon, size: 16, color: Colors.amber));
    }
    return Row(children: widgets);
  }

  Widget _fallback() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_size_select_actual_outlined, size: 48, color: Colors.black26),
    );
  }

  Widget _loading() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
