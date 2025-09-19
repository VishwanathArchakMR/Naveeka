// lib/features/quick_actions/presentation/messages/widgets/suggested_places_messages.dart

import 'package:flutter/material.dart';

import '/../../../models/place.dart';
import '/../../../models/unit_system.dart' as us show UnitSystem;
import '../../../../places/presentation/widgets/distance_indicator.dart' as di
    show DistanceIndicator, UnitSystem;

class SuggestedPlacesMessages extends StatefulWidget {
  const SuggestedPlacesMessages({
    super.key,
    required this.places,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenPlace,
    this.onSharePlace, // Future<void> Function(Place place)
    this.onBook, // Future<void> Function(Place place)
    this.originLat,
    this.originLng,
    this.unit = us.UnitSystem.metric,
    this.sectionTitle = 'Suggested places',
    this.cardWidth = 260,
    this.height = 230,
    this.heroPrefix = 'msg-suggest',
  });

  final List<Place> places;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(Place place)? onOpenPlace;
  final Future<void> Function(Place place)? onSharePlace;
  final Future<void> Function(Place place)? onBook;

  final double? originLat;
  final double? originLng;
  final us.UnitSystem unit;

  final String sectionTitle;
  final double cardWidth;
  final double height;
  final String heroPrefix;

  @override
  State<SuggestedPlacesMessages> createState() => _SuggestedPlacesMessagesState();
}

class _SuggestedPlacesMessagesState extends State<SuggestedPlacesMessages> {
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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Pagination guard avoids duplicate trailing loads. [web:6120]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAny = widget.places.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: widget.height + 56,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with optional loader
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (widget.loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),

            // Body: horizontal list of cards
            SizedBox(
              height: widget.height,
              child: hasAny
                  ? RefreshIndicator.adaptive(
                      onRefresh: widget.onRefresh,
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.places.length + 1,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, i) {
                          if (i == widget.places.length) return _tail();
                          final p = widget.places[i];
                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 8 : 6, right: i == widget.places.length - 1 ? 8 : 6),
                            child: _PlaceCard(
                              place: p,
                              width: widget.cardWidth,
                              height: widget.height,
                              // Use index-based tag to ensure uniqueness per route/subtree. [web:6171][web:6174]
                              heroTag: '${widget.heroPrefix}-$i',
                              originLat: widget.originLat,
                              originLng: widget.originLng,
                              unit: widget.unit,
                              onOpen: widget.onOpenPlace,
                              onShare: widget.onSharePlace,
                              onBook: widget.onBook,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No suggestions', style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tail() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Text('· end ·')),
      );
    }
    return const SizedBox(width: 24);
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.width,
    required this.height,
    required this.heroTag,
    this.originLat,
    this.originLng,
    required this.unit,
    this.onOpen,
    this.onShare,
    this.onBook,
  });

  final Place place;
  final double width;
  final double height;
  final String heroTag;

  final double? originLat;
  final double? originLng;
  final us.UnitSystem unit;

  final void Function(Place place)? onOpen;
  final Future<void> Function(Place place)? onShare;
  final Future<void> Function(Place place)? onBook;

  @override
  Widget build(BuildContext context) {
    final img = _coverUrl(place);
    final name = _nameOf(place);

    final la = _latOf(place), ln = _lngOf(place);
    final hasCoords = la != null && ln != null && originLat != null && originLng != null;

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onOpen == null ? null : () => onOpen!(place),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              SizedBox(
                height: height * 0.52,
                width: double.infinity,
                child: img == null
                    ? _fallbackImage()
                    : Hero(
                        tag: heroTag,
                        child: Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackImage(),
                          loadingBuilder: (context, child, prog) => prog == null
                              ? child
                              : Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                ),
                        ),
                      ),
              ),

              // Title and rating
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    finalRating(place) == null
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  finalRating(place)!.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),

              // Distance (optional)
              if (hasCoords)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                  child: di.DistanceIndicator.fromPlace(
                    place,
                    originLat: originLat!,
                    originLng: originLng!,
                    unit: _toDi(unit),
                    compact: true,
                    labelSuffix: 'away',
                  ),
                ),

              const Spacer(),

              // Actions: Share, Open, (Book)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onShare == null ? null : () => onShare!(place),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: onOpen == null ? null : () => onOpen!(place),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open'),
                    ),
                    const Spacer(),
                    if (onBook != null)
                      FilledButton.icon(
                        onPressed: () => onBook!(place),
                        icon: const Icon(Icons.event_available_outlined, size: 18),
                        label: const Text('Book'),
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

  // -------- Unit mapping (models -> distance_indicator) --------

  di.UnitSystem _toDi(us.UnitSystem u) {
    switch (u) {
      case us.UnitSystem.metric:
        return di.UnitSystem.metric;
      case us.UnitSystem.imperial:
        return di.UnitSystem.imperial;
    }
  } // Prefixing imports avoids UnitSystem collisions; map enums explicitly. [web:6120]

  // -------- Place helpers via toJson (model-agnostic) --------

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  } // Safely project Place to a map to avoid missing getters. [web:5858]

  String _nameOf(Place p) {
    final m = _json(p);
    final v = (m['name'] ?? m['title'])?.toString().trim();
    return (v == null || v.isEmpty) ? 'Place' : v;
  } // Title or fallback. [web:5858]

  double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Accept number or parse string. [web:5858]

  double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Accept number or parse string. [web:5858]

  double? finalRating(Place p) {
    final m = _json(p);
    final v = m['rating'] ?? m['avgRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Rating key fallbacks. [web:5858]

  String? _coverUrl(Place p) {
    final m = _json(p);
    final photos = m['photos'] ?? m['images'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    final single = (m['imageUrl'] ?? m['cover'] ?? m['thumbnail'])?.toString().trim();
    return (single != null && single.isNotEmpty) ? single : null;
  } // Flexible image source. [web:5858]

  Widget _fallbackImage() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_size_select_actual_outlined, color: Colors.black26),
    );
  }
}
