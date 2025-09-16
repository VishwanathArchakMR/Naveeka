// lib/features/places/presentation/widgets/suggested_nearby.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import 'distance_indicator.dart';
import 'favorite_heart_button.dart';
import 'directions_button.dart';

class SuggestedNearby extends StatelessWidget {
  const SuggestedNearby({
    super.key,
    required this.places,
    this.title = 'Suggested nearby',
    this.originLat,
    this.originLng,
    this.unit = UnitSystem.metric,
    this.onSeeAll,
    this.onOpenPlace,
    this.onToggleFavorite,
    this.emptyPlaceholder,
    this.cardWidth = 240,
    this.heroPrefix = 'nearby',
  });

  final List<Place> places;
  final String title;

  /// Optional origin for DistanceIndicator.
  final double? originLat;
  final double? originLng;
  final UnitSystem unit;

  /// Header “See all” action.
  final VoidCallback? onSeeAll;

  /// Called when a card is tapped.
  final void Function(Place place)? onOpenPlace;

  /// Favorite toggle handler used by the heart button.
  final Future<bool> Function(bool next)? onToggleFavorite;

  /// Shown when places is empty.
  final Widget? emptyPlaceholder;

  /// Card width for each horizontal item.
  final double cardWidth;

  /// Prefix for Hero tags (when used by outer detail pages).
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return emptyPlaceholder ?? const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all'),
                ),
            ],
          ),
        ),

        // Horizontal list of cards
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: places.length,
            itemBuilder: (context, i) {
              final p = places[i];
              return Padding(
                padding: EdgeInsets.only(right: i == places.length - 1 ? 0 : 12),
                child: _NearbyCard(
                  place: p,
                  width: cardWidth,
                  heroTag: '$heroPrefix-${p.id}',
                  originLat: originLat,
                  originLng: originLng,
                  unit: unit,
                  onOpen: () => onOpenPlace?.call(p),
                  onToggleFavorite: onToggleFavorite,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.place,
    required this.width,
    required this.heroTag,
    required this.originLat,
    required this.originLng,
    required this.unit,
    this.onOpen,
    this.onToggleFavorite,
  });

  final Place place;
  final double width;
  final String heroTag;
  final double? originLat;
  final double? originLng;
  final UnitSystem unit;
  final VoidCallback? onOpen;
  final Future<bool> Function(bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final img = _coverUrl(place);
    final name = (place.name ?? '').trim().isEmpty ? 'Place' : place.name!.trim();
    final hasCoords = place.lat != null && place.lng != null;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover with overlay actions
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    img == null
                        ? _fallbackImage()
                        : Hero(
                            tag: heroTag,
                            child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackImage(),
                              loadingBuilder: (context, child, prog) {
                                if (prog == null) return child;
                                return _loading();
                              },
                            ),
                          ),
                    // Top-right favorite
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
                        shape: const CircleBorder(),
                        child: FavoriteHeartButton.fromPlace(
                          place: place,
                          onChanged: onToggleFavorite ?? (next) async => true,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body: name, meta, distance
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),

              // Meta row (rating + distance)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    _RatingPill(rating: place.rating),
                    const SizedBox(width: 8),
                    if (originLat != null && originLng != null && hasCoords)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DistanceIndicator.fromPlace(
                            place,
                            originLat: originLat!,
                            originLng: originLng!,
                            unit: unit,
                            compact: true,
                            labelSuffix: 'away',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Footer actions
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  children: [
                    if (hasCoords)
                      OutlinedButton.icon(
                        onPressed: () => DirectionsButton.fromPlace(place, expanded: false).onPressed?.call(),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Go'),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _coverUrl(Place p) {
    final list = p.photos ?? const <String>[];
    return list.isNotEmpty && list.first.trim().isNotEmpty ? list.first.trim() : null;
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_size_select_actual_outlined, color: Colors.black26),
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

class _RatingPill extends StatelessWidget {
  const _RatingPill({this.rating});
  final double? rating;
  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(rating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
