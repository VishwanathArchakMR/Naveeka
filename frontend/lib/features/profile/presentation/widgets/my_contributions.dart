// lib/features/profile/presentation/widgets/my_contributions.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../places/presentation/widgets/place_card.dart';
import '../../../places/presentation/widgets/photo_gallery.dart';
import '../../../places/presentation/widgets/reviews_ratings.dart';

class MyContributions extends StatefulWidget {
  const MyContributions({
    super.key,
    // Stats
    this.totalPlaces = 0,
    this.totalReviews = 0,
    this.totalPhotos = 0,

    // Places tab
    this.places = const <Place>[],
    this.placesLoading = false,
    this.placesHasMore = false,
    this.onPlacesRefresh,
    this.onPlacesLoadMore,
    this.onOpenPlace,
    this.onToggleWishlist,

    // Reviews tab
    this.reviews = const <ReviewItem>[],
    this.reviewsLoading = false,
    this.reviewsHasMore = false,
    this.onReviewsRefresh,
    this.onReviewsLoadMore,
    this.onOpenReviewTarget,

    // Photos tab
    this.photoUrls = const <String>[],
    this.photosLoading = false,
    this.photosHasMore = false,
    this.onPhotosRefresh,
    this.onPhotosLoadMore,
    this.onOpenPhotoIndex,

    // Actions
    this.onAddPlace,
    this.onWriteReview,
    this.onUploadPhoto,

    // Options
    this.originLat,
    this.originLng,
    this.heroPrefix = 'contrib-hero',
  });

  // Summary stats
  final int totalPlaces;
  final int totalReviews;
  final int totalPhotos;

  // Places
  final List<Place> places;
  final bool placesLoading;
  final bool placesHasMore;
  final Future<void> Function()? onPlacesRefresh;
  final Future<void> Function()? onPlacesLoadMore;
  final void Function(Place place)? onOpenPlace;
  final Future<void> Function(Place place)? onToggleWishlist;

  // Reviews
  final List<ReviewItem> reviews;
  final bool reviewsLoading;
  final bool reviewsHasMore;
  final Future<void> Function()? onReviewsRefresh;
  final Future<void> Function()? onReviewsLoadMore;
  final void Function(ReviewItem item)? onOpenReviewTarget;

  // Photos
  final List<String> photoUrls;
  final bool photosLoading;
  final bool photosHasMore;
  final Future<void> Function()? onPhotosRefresh;
  final Future<void> Function()? onPhotosLoadMore;
  final void Function(int index)? onOpenPhotoIndex;

  // Quick actions
  final VoidCallback? onAddPlace;
  final VoidCallback? onWriteReview;
  final VoidCallback? onUploadPhoto;

  // Extras
  final double? originLat;
  final double? originLng;
  final String heroPrefix;

  @override
  State<MyContributions> createState() => _MyContributionsState();
}

class _MyContributionsState extends State<MyContributions> with TickerProviderStateMixin {
  final _placesScroll = ScrollController();
  final _reviewsScroll = ScrollController();
  final _photosScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _placesScroll.addListener(() => _maybeLoadMore(
          _placesScroll,
          widget.onPlacesLoadMore,
          widget.placesHasMore,
          widget.placesLoading,
        ));
    _reviewsScroll.addListener(() => _maybeLoadMore(
          _reviewsScroll,
          widget.onReviewsLoadMore,
          widget.reviewsHasMore,
          widget.reviewsLoading,
        ));
    _photosScroll.addListener(() => _maybeLoadMore(
          _photosScroll,
          widget.onPhotosLoadMore,
          widget.photosHasMore,
          widget.photosLoading,
        ));
  }

  @override
  void dispose() {
    _placesScroll.dispose();
    _reviewsScroll.dispose();
    _photosScroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore(
    ScrollController c,
    Future<void> Function()? loadMore,
    bool hasMore,
    bool loading,
  ) {
    if (loadMore == null) return;
    if (!hasMore || loading) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 480) {
      loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // Header: title + actions
              Row(
                children: [
                  const Expanded(
                    child: Text('My contributions', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (widget.onAddPlace != null)
                    OutlinedButton.icon(
                      onPressed: widget.onAddPlace,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add place'),
                    ),
                  if (widget.onWriteReview != null) const SizedBox(width: 8),
                  if (widget.onWriteReview != null)
                    OutlinedButton.icon(
                      onPressed: widget.onWriteReview,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Write review'),
                    ),
                  if (widget.onUploadPhoto != null) const SizedBox(width: 8),
                  if (widget.onUploadPhoto != null)
                    OutlinedButton.icon(
                      onPressed: widget.onUploadPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Upload'),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Stats
              _StatsRow(
                places: widget.totalPlaces,
                reviews: widget.totalReviews,
                photos: widget.totalPhotos,
              ),

              const SizedBox(height: 8),

              // Tabs
              const TabBar(
                isScrollable: false,
                tabs: [
                  Tab(icon: Icon(Icons.place_outlined), text: 'Places'),
                  Tab(icon: Icon(Icons.reviews_outlined), text: 'Reviews'),
                  Tab(icon: Icon(Icons.photo_library_outlined), text: 'Photos'),
                ],
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 520,
                child: TabBarView(
                  children: [
                    _buildPlacesTab(context),
                    _buildReviewsTab(context),
                    _buildPhotosTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------- PLACES -----------------
  Widget _buildPlacesTab(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: widget.onPlacesRefresh ?? () async {},
      child: CustomScrollView(
        controller: _placesScroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            sliver: _placesGrid(),
          ),
          SliverToBoxAdapter(
            child: _footer(widget.placesLoading, widget.placesHasMore, widget.places.isEmpty),
          ),
        ],
      ),
    );
  }

  SliverGrid _placesGrid() {
    final items = widget.places;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 4 / 5,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final p = items[i];

          // Read a flexible JSON map from Place.
          Map<String, dynamic> j = const <String, dynamic>{};
          try {
            final dyn = p as dynamic;
            final raw = dyn.toJson();
            if (raw is Map<String, dynamic>) j = raw;
          } catch (_) {}

          T? pick<T>(List<String> keys) {
            for (final k in keys) {
              final v = j[k];
              if (v is T) return v;
              if (T == double && v is num) return v.toDouble() as T;
              if (T == double && v is String) {
                final d = double.tryParse(v);
                if (d != null) return d as T;
              }
              if (T == String && v != null) return v.toString() as T;
              if (T == bool && v is String) {
                final s = v.toLowerCase();
                if (s == 'true') return true as T;
                if (s == 'false') return false as T;
              }
            }
            return null;
          }

          List<dynamic> listOf(dynamic v) {
            if (v is List) return v;
            return const <dynamic>[];
          }

          final photos = listOf(j['photos'] ?? j['images'] ?? j['gallery']);
          final categories = listOf(j['categories'] ?? j['tags'] ?? j['types']);
          final map = {
            '_id': j['_id'] ?? j['id'] ?? j['placeId'],
            'id': j['id'] ?? j['_id'] ?? j['placeId'],
            'name': j['name'] ?? j['title'] ?? j['label'],
            'coverImage': photos.isNotEmpty ? photos.first : null,
            'photos': photos,
            'category': categories.isNotEmpty ? categories.first : null,
            'emotion': j['emotion'],
            'rating': pick<num>(['rating', 'avgRating', 'averageRating']),
            'reviewsCount': pick<num>(['reviewsCount', 'reviewCount', 'reviews']),
            'lat': pick<double>(['lat', 'latitude', 'coord_lat', 'location_lat']),
            'lng': pick<double>(['lng', 'lon', 'longitude', 'coord_lng', 'location_lng']),
            'isApproved': pick<bool>(['isApproved', 'approved']),
            'isWishlisted': pick<bool>(['isFavorite', 'wishlisted', 'isWishlisted']),
          };

          // Wrap PlaceCard to handle taps externally (no onTap in PlaceCard).
          return GestureDetector(
            onTap: widget.onOpenPlace == null ? null : () => widget.onOpenPlace!(p),
            child: PlaceCard(
              place: map,
              originLat: widget.originLat,
              originLng: widget.originLng,
              onToggleWishlist: () async {
                if (widget.onToggleWishlist != null) {
                  await widget.onToggleWishlist!(p);
                }
              },
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  // ----------------- REVIEWS -----------------
  Widget _buildReviewsTab(BuildContext context) {
    final items = widget.reviews;
    return RefreshIndicator.adaptive(
      onRefresh: widget.onReviewsRefresh ?? () async {},
      child: ListView.separated(
        controller: _reviewsScroll,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return _footer(widget.reviewsLoading, widget.reviewsHasMore, items.isEmpty);
          }
          final r = items[i];

          Map<String, dynamic> j = const <String, dynamic>{};
          try {
            final dyn = r as dynamic;
            final raw = dyn.toJson();
            if (raw is Map<String, dynamic>) j = raw;
          } catch (_) {}

          String titleOf() {
            final v = j['title'] ??
                j['headline'] ??
                j['placeName'] ??
                j['subject'] ??
                '';
            return v?.toString() ?? '';
          }

          String subtitleOf() {
            final v = j['subtitle'] ??
                j['text'] ??
                j['comment'] ??
                j['body'] ??
                '';
            return v?.toString() ?? '';
          }

          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.black12,
              child: Icon(Icons.rate_review_outlined, color: Colors.black54),
            ),
            title: Text(titleOf(), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitleOf(), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new),
            onTap: widget.onOpenReviewTarget == null ? null : () => widget.onOpenReviewTarget!(r),
          );
        },
      ),
    );
  }

  // ----------------- PHOTOS -----------------
  Widget _buildPhotosTab(BuildContext context) {
    final urls = widget.photoUrls;
    return RefreshIndicator.adaptive(
      onRefresh: widget.onPhotosRefresh ?? () async {},
      child: CustomScrollView(
        controller: _photosScroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(6),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final url = urls[i];
                  final tag = '${widget.heroPrefix}-photo-$i';
                  return GestureDetector(
                    onTap: () async {
                      if (widget.onOpenPhotoIndex != null) {
                        // Do not await a void callback.
                        widget.onOpenPhotoIndex!(i);
                        return;
                      }
                      // Open full-screen PhotoGallery; this widget in this codebase requires imageUrls.
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PhotoGallery(
                          imageUrls: urls,
                        ),
                      ));
                    },
                    child: Hero(
                      tag: tag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: urls.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _footer(widget.photosLoading, widget.photosHasMore, urls.isEmpty),
          ),
        ],
      ),
    );
  }

  // ----------------- FOOTER -----------------
  Widget _footer(bool loading, bool hasMore, bool isEmpty) {
    if (loading && isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (loading && hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No more items')),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.places, required this.reviews, required this.photos});
  final int places;
  final int reviews;
  final int photos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(icon: Icons.place_outlined, label: 'Places', value: places),
        const SizedBox(width: 8),
        _StatTile(icon: Icons.reviews_outlined, label: 'Reviews', value: reviews),
        const SizedBox(width: 8),
        _StatTile(icon: Icons.photo_library_outlined, label: 'Photos', value: photos),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
            const Spacer(),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
