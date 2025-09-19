// lib/features/quick_actions/presentation/history/widgets/visited_places.dart

import 'package:flutter/material.dart';

import '/../../../models/place.dart';
import '../../../../places/presentation/widgets/distance_indicator.dart';
import '/../../../ui/components/buttons/favorite_button.dart';
import 'rebook_button.dart';

class VisitedPlaceRow {
  const VisitedPlaceRow({
    required this.place,
    required this.lastVisited,
    required this.totalVisits,
    this.originLat,
    this.originLng,
    this.priceFrom, // optional display string
  });

  final Place place;
  final DateTime lastVisited;
  final int totalVisits;
  final double? originLat;
  final double? originLng;
  final String? priceFrom;
}

/// Responsive grid of visited places with lazy building and quick actions.
class VisitedPlaces extends StatelessWidget {
  const VisitedPlaces({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenPlace,
    this.onToggleFavorite, // Future<bool> Function(Place place, bool next)
    this.onRebook, // Future<bool> Function(Place place)
    this.sectionTitle = 'Visited places',
    this.heroPrefix = 'visited',
    this.cardWidth = 260,
  });

  final List<VisitedPlaceRow> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(Place place)? onOpenPlace;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;
  final Future<bool> Function(Place place)? onRebook;

  final String sectionTitle;
  final String heroPrefix;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; // Use theme colors for consistent styling [web:132].

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
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
                    child: Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (loading)
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
                onRefresh: onRefresh,
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No visited places',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cross = w >= 1100 ? 4 : (w >= 750 ? 3 : 2);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 4 / 5,
                            ),
                            itemCount: items.length + 1,
                            itemBuilder: (context, i) {
                              if (i == items.length) return _footer(loading, hasMore);
                              final row = items[i];
                              return _VisitedCard(
                                row: row,
                                heroTag: '$heroPrefix-${_idOf(row.place)}',
                                onOpen: onOpenPlace,
                                onToggleFavorite: onToggleFavorite,
                                onRebook: onRebook,
                              );
                            },
                          );
                        },
                      ),
              ),
            ), // GridView.builder lazily builds visible tiles and adapts columns responsively with a SliverGridDelegate [web:255].
          ],
        ),
      ),
    );
  }

  Widget _footer(bool loading, bool hasMore) {
    if (loading && hasMore) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (!hasMore) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No more places')));
    }
    return const SizedBox.shrink();
  }

  // JSON helpers (top-level to reuse in cards)
  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _idOf(Place p) {
    final j = _json(p);
    return (j['id'] ?? j['_id'] ?? j['placeId'] ?? '').toString();
  }
}

class _VisitedCard extends StatelessWidget {
  const _VisitedCard({
    required this.row,
    required this.heroTag,
    this.onOpen,
    this.onToggleFavorite,
    this.onRebook,
  });

  final VisitedPlaceRow row;
  final String heroTag;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;
  final Future<bool> Function(Place place)? onRebook;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; // Themed colors used for chips and text [web:132].
    final p = row.place;
    final name = _nameOf(p);
    final img = _coverUrl(p);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onOpen == null ? null : () => onOpen!(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            SizedBox(
              height: 120,
              width: double.infinity,
              child: img == null
                  ? _fallbackImage()
                  : Hero(
                      tag: heroTag,
                      child: Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(),
                        loadingBuilder: (context, child, prog) {
                          if (prog == null) return child;
                          return _shimmer();
                        },
                      ),
                    ),
            ),

            // Title + favorite
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
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
                  FavoriteButton(
  value: _isFavorite(p),
  compact: true,
  size: 28,
  onChanged: (next) {
    final handler = onToggleFavorite;
    if (handler != null) {
      // No `await` needed; FutureOr<void> accepts either sync void or a Future.
      handler(p, next);
    }
  },
),

                ],
              ),
            ), // Card shows place name and favorite toggle using a void-returning onChanged wrapper for compatibility [web:255].

            // Meta: last visited + total + distance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VisitsPill(lastVisited: row.lastVisited, total: row.totalVisits, cs: cs),
                  if (row.originLat != null &&
                      row.originLng != null &&
                      _latOf(p) != null &&
                      _lngOf(p) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: DistanceIndicator.fromPlace(
                        p,
                        originLat: row.originLat!,
                        originLng: row.originLng!,
                        unit: UnitSystem.metric,
                        compact: true,
                        labelSuffix: 'away',
                      ),
                    ),
                  if ((row.priceFrom ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'From ${row.priceFrom!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
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
                  OutlinedButton.icon(
                    onPressed: onOpen == null ? null : () => onOpen!(p),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  ),
                  const Spacer(),
                  if (onRebook != null)
                    RebookButton(
                      compact: false,
                      label: 'Rebook',
                      onRebook: () async => await onRebook!.call(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Helpers for _VisitedCard ----

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
    final v = (j['name'] ?? j['title'] ?? j['label'] ?? 'Place').toString();
    return v.trim();
  }

  String? _coverUrl(Place p) {
    final j = _json(p);
    final v = j['photos'] ?? j['images'] ?? j['gallery'];
    if (v is List && v.isNotEmpty) {
      final first = v.first?.toString().trim();
      if (first != null && first.isNotEmpty) return first;
    }
    return null;
  }

  double? _latOf(Place p) {
    final j = _json(p);
    final v = j['lat'] ?? j['latitude'] ?? j['coord_lat'] ?? j['location_lat'];
    return _d(v);
  }

  double? _lngOf(Place p) {
    final j = _json(p);
    final v = j['lng'] ?? j['lon'] ?? j['longitude'] ?? j['coord_lng'] ?? j['location_lng'];
    return _d(v);
  }

  bool _isFavorite(Place p) {
    final j = _json(p);
    final f = j['isFavorite'];
    final w = j['isWishlisted'] ?? j['wishlisted'];
    final fv = (f is bool) ? f : (f is String ? f.toLowerCase() == 'true' : false);
    final wv = (w is bool) ? w : (w is String ? w.toLowerCase() == 'true' : false);
    return fv || wv;
  }

  double? _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_size_select_actual_outlined, color: Colors.black26),
    );
  }

  Widget _shimmer() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _VisitsPill extends StatelessWidget {
  const _VisitsPill({required this.lastVisited, required this.total, required this.cs});
  final DateTime lastVisited;
  final int total;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final when = _fmt(context, lastVisited); // Pass BuildContext to formatting function [web:255].
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Last: $when', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            total == 1 ? '1 visit' : '$total visits',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  String _fmt(BuildContext context, DateTime dt) {
    final local = dt.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final t = TimeOfDay.fromDateTime(local);
    final ts = MaterialLocalizations.of(context).formatTimeOfDay(t);
    return '$date · $ts';
  }
}
