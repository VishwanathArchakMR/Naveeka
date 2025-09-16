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
    _placesScroll.addListener(() => _maybeLoadMore(_placesScroll, widget.onPlacesLoadMore, widget.placesHasMore, widget.placesLoading));
    _reviewsScroll.addListener(() => _maybeLoadMore(_reviewsScroll, widget.onReviewsLoadMore, widget.reviewsHasMore, widget.reviewsLoading));
    _photosScroll.addListener(() => _maybeLoadMore(_photosScroll, widget.onPhotosLoadMore, widget.photosHasMore, widget.photosLoading));
  }

  @override
  void dispose() {
    _placesScroll.dispose();
    _reviewsScroll.dispose();
    _photosScroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore(ScrollController c, Future<void> Function()? loadMore, bool hasMore, bool loading) {
    if (loadMore == null) return;
    if (!hasMore || loading) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 480) {
      loadMore();
    }
  } // Infinite scroll loads more when nearing the end of the scroll extent, a standard pattern for progressive lists. [3][4]

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
                    OutlinedButton.icon(onPressed: widget.onAddPlace, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add place')),
                  if (widget.onWriteReview != null) const SizedBox(width: 8),
                  if (widget.onWriteReview != null)
                    OutlinedButton.icon(onPressed: widget.onWriteReview, icon: const Icon(Icons.rate_review_outlined), label: const Text('Write review')),
                  if (widget.onUploadPhoto != null) const SizedBox(width: 8),
                  if (widget.onUploadPhoto != null)
                    OutlinedButton.icon(onPressed: widget.onUploadPhoto, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Upload')),
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
              TabBar(
                isScrollable: false,
                tabs: const [
                  Tab(icon: Icon(Icons.place_outlined), text: 'Places'),
                  Tab(icon: Icon(Icons.reviews_outlined), text: 'Reviews'),
                  Tab(icon: Icon(Icons.photo_library_outlined), text: 'Photos'),
                ],
              ), // TabBar provides a primary navigation affordance for switching panes in a page. [5][6]

              const SizedBox(height: 8),

              SizedBox(
                height: 520,
                child: TabBarView(
                  children: [
                    _buildPlacesTab(context),
                    _buildReviewsTab(context),
                    _buildPhotosTab(context),
                  ],
                ), // TabBarView pairs with TabBar to present each tab’s content with swipe gesture support. [5][6]
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
          SliverToBoxAdapter(child: _footer(widget.placesLoading, widget.placesHasMore, widget.places.isEmpty)),
        ],
      ),
    ); // RefreshIndicator adds pull-to-refresh behavior to the scrollable tab content. [7][8]
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
          final map = {
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
          return PlaceCard(
            place: map,
            originLat: widget.originLat,
            originLng: widget.originLng,
            onToggleWishlist: () async {
              if (widget.onToggleWishlist != null) {
                await widget.onToggleWishlist!(p);
              }
            },
          );
        },
        childCount: items.length,
      ),
    ); // SliverGrid efficiently builds a responsive grid of cards for large item sets. [9][10]
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
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.black12,
              child: const Icon(Icons.rate_review_outlined, color: Colors.black54),
            ),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(r.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new),
            onTap: widget.onOpenReviewTarget == null ? null : () => widget.onOpenReviewTarget!(r),
          );
        },
      ),
    ); // ListView.separated inserts uniform dividers and remains efficient for long, scrollable lists. [2][11]
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
                    onTap: widget.onOpenPhotoIndex == null ? null : () => widget.onOpenPhotoIndex!(i),
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
          SliverToBoxAdapter(child: _footer(widget.photosLoading, widget.photosHasMore, urls.isEmpty)),
        ],
      ),
    ); // GridView/SliverGrid renders media thumbnails efficiently and pairs well with Hero for full-screen transitions. [12][13]
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
