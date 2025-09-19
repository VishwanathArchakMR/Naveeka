// lib/features/places/presentation/widgets/place_header.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import 'favorite_heart_button.dart';
import 'map_view_button.dart';
import 'directions_button.dart';

/// Collapsible image header for place details screens. [SliverAppBar docs reference]
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
    final title = _title(place);

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
        if (_hasCoords(place)) MapViewButton.fromPlace(place, extended: false),
        if (_hasCoords(place)) DirectionsButton.fromPlace(place, expanded: false),
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
                tag: heroTag ?? 'place-hero-${_id(place)}',
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

  String _title(Place p) {
    final name = _pickString(p, ['name', 'title'])?.trim();
    if (name == null || name.isEmpty) return 'Place';
    return name;
  }

  String _id(Place p) {
    return _pickString(p, ['id', '_id', 'placeId']) ?? 'place';
  }

  bool _hasCoords(Place p) {
    final lat = _pickNum(p, ['lat', 'latitude', 'locationLat', 'coordLat']);
    final lng = _pickNum(p, ['lng', 'longitude', 'locationLng', 'coordLng']);
    return lat != null && lng != null;
  }

  String? _coverUrl(Place p) {
    final photos = _pickList<String>(p, ['photos', 'images']);
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    final single = _pickString(p, ['imageUrl', 'cover', 'thumbnail']);
    return (single != null && single.trim().isNotEmpty) ? single.trim() : null;
  }

  // Dynamic map readers

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String? _pickString(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  num? _pickNum(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  List<T>? _pickList<T>(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        try {
          return List<T>.from(v);
        } catch (_) {
          if (T == String) {
            return v.map((e) => e.toString()).cast<T>().toList();
          }
        }
      }
    }
    return null;
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
/// Rounded cover image, title, categories, rating, and inline actions.
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
    final title = _title(place);
    final cats = _categories(place);
    final rating = _pickNum(place, ['rating', 'avgRating'])?.toDouble() ?? 0.0;
    final reviewsCount = _pickNum(place, ['reviewsCount', 'reviewCount'])?.toInt() ?? 0;

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
                    tag: heroTag ?? 'place-hero-${_id(place)}',
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
                    if (_hasCoords(place)) MapViewButton.fromPlace(place, extended: false),
                    if (_hasCoords(place)) DirectionsButton.fromPlace(place, expanded: false),
                  ],
                ),
                const SizedBox(height: 6),

                // Rating
                if (showRating)
                  Row(
                    children: [
                      _stars(rating),
                      const SizedBox(width: 6),
                      Text(rating.toStringAsFixed(1)),
                      if (reviewsCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('· $reviewsCount reviews', style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),

                // Categories
                if (showCategories && cats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats
                        .map((c) => Chip(label: Text(c), visualDensity: VisualDensity.compact))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Local helpers (card)

  String _title(Place p) {
    final name = _pickString(p, ['name', 'title'])?.trim();
    if (name == null || name.isEmpty) return 'Place';
    return name;
  }

  String _id(Place p) {
    return _pickString(p, ['id', '_id', 'placeId']) ?? 'place';
  }

  bool _hasCoords(Place p) {
    final lat = _pickNum(p, ['lat', 'latitude', 'locationLat', 'coordLat']);
    final lng = _pickNum(p, ['lng', 'longitude', 'locationLng', 'coordLng']);
    return lat != null && lng != null;
  }

  String? _coverUrl(Place p) {
    final photos = _pickList<String>(p, ['photos', 'images']);
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    final single = _pickString(p, ['imageUrl', 'cover', 'thumbnail']);
    return (single != null && single.trim().isNotEmpty) ? single.trim() : null;
  }

  List<String> _categories(Place p) {
    final cats = _pickList<String>(p, ['categories', 'tags']) ?? const <String>[];
    return cats.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String? _pickString(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  num? _pickNum(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  List<T>? _pickList<T>(Place p, List<String> keys) {
    final m = _json(p);
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        try {
          return List<T>.from(v);
        } catch (_) {
          if (T == String) {
            return v.map((e) => e.toString()).cast<T>().toList();
          }
        }
      }
    }
    return null;
  }

  Widget _stars(double rating) {
    final widgets = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      final icon =
          rating >= i - 0.25 ? Icons.star : (rating >= i - 0.75 ? Icons.star_half : Icons.star_border);
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
