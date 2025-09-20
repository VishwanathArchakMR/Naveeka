// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';

// Core models
import '../../../models/place.dart';

// Reused profile widgets
import 'widgets/about_section.dart';
import 'widgets/profile_stats.dart';
import 'widgets/travel_stats.dart';
import 'widgets/visited_locations_map.dart';
import 'widgets/my_contributions.dart';
import 'widgets/activity_feed.dart'
import 'widgets/my_journeys.dart';

// Optional: reuse Reviews' ReviewItem if showing contributions that leverage shared model.
// import '../../places/presentation/widgets/reviews_ratings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,

    // Header / identity
    required this.name,
    this.username,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.location,
    this.joinedOn,
    this.verified = false,

    // Stats
    this.placesCount = 0,
    this.reviewsCount = 0,
    this.photosCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.journeysCount = 0,

    // Travel stats
    this.totalDistanceKm = 0,
    this.totalDays = 0,
    this.totalTrips = 0,
    this.countries = 0,
    this.cities = 0,
    this.continentCounts = const <String, int>{},
    this.transportMix = const <String, double>{},

    // Map
    this.visitedPlaces = const <Place>[],
    this.originLat,
    this.originLng,

    // Contributions
    this.contributionPlaces = const <Place>[],
    this.contributionReviews = const <ContributionReview>[],
    this.contributionPhotoUrls = const <String>[], // For photos tab
    this.journeys = const <JourneyView>[],
    this.activityItems = const <ActivityItem>[],

    // Async / callbacks
    this.loading = false,
    this.onRefresh,
    this.onEditProfile,
    this.onOpenPlace,
    this.onOpenReviewTarget,
    this.onUploadPhoto,
    this.onWriteReview,
    this.onAddPlace,
    this.onCreateJourney,
  });

  // Identity
  final String name;
  final String? username;
  final String? headline;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? location;
  final DateTime? joinedOn;
  final bool verified;

  // Stats
  final int placesCount;
  final int reviewsCount;
  final int photosCount;
  final int followersCount;
  final int followingCount;
  final int journeysCount;

  // Travel stats
  final double totalDistanceKm;
  final int totalDays;
  final int totalTrips;
  final int countries;
  final int cities;
  final Map<String, int> continentCounts;
  final Map<String, double> transportMix;

  // Map and distances
  final List<Place> visitedPlaces;
  final double? originLat;
  final double? originLng;

  // Contributions
  final List<Place> contributionPlaces;
  final List<ContributionReview> contributionReviews;
  final List<String> contributionPhotoUrls;

  // Journeys + Activity
  final List<JourneyView> journeys;
  final List<ActivityItem> activityItems;

  // Async states / handlers
  final bool loading;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onEditProfile;

  final void Function(Place place)? onOpenPlace;
  final void Function(ContributionReview item)? onOpenReviewTarget;
  final VoidCallback? onUploadPhoto;
  final VoidCallback? onWriteReview;
  final VoidCallback? onAddPlace;
  final VoidCallback? onCreateJourney;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// Simple review view-model for the reviews tab in MyContributions.
class ContributionReview {
  const ContributionReview({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.name).trim().isEmpty ? 'Profile' : widget.name.trim();

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          slivers: [
            // Collapsing header with optional cover background
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 240,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: [
                if (widget.onEditProfile != null)
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: widget.onEditProfile,
                    icon: const Icon(Icons.edit_outlined),
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
                    if ((widget.coverUrl ?? '').trim().isNotEmpty)
                      Image.network(
                        widget.coverUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                        loadingBuilder: (context, child, prog) => prog == null
                            ? child
                            : Container(color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      Container(color: Colors.black12),
                    // Gradient for title legibility
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
            ), // SliverAppBar plus FlexibleSpaceBar creates a rich, collapsing header suited for profile pages with banners and actions. [3][4]

            // Body sections
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  const SizedBox(height: 8),

                  // About section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AboutSection.fromUser(
                      name: widget.name,
                      username: widget.username,
                      headline: widget.headline,
                      bio: widget.bio,
                      avatarUrl: widget.avatarUrl,
                      location: widget.location,
                      joinedOn: widget.joinedOn,
                      verified: widget.verified,
                      showEdit: widget.onEditProfile != null,
                      onEdit: widget.onEditProfile,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Profile stats (counts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ProfileStats(
                      places: widget.placesCount,
                      reviews: widget.reviewsCount,
                      photos: widget.photosCount,
                      followers: widget.followersCount,
                      following: widget.followingCount,
                      journeys: widget.journeysCount,
                      showBadges: true,
                      tooltips: true,
                      progressLabel: 'Profile completeness',
                      progressValue: _profileCompleteness(),
                      onTapPlaces: () => _scrollTo('contributions'),
                      onTapReviews: () => _scrollTo('contributions'),
                      onTapPhotos: () => _scrollTo('contributions'),
                      onTapJourneys: () => _scrollTo('journeys'),
                    ),
                  ), // The stats grid uses GridView for responsive tiles and tooltips for discoverability in dense UIs. [5][6]

                  const SizedBox(height: 12),

                  // Travel stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TravelStats(
                      totalDistanceKm: widget.totalDistanceKm.toDouble(),
                      totalDays: widget.totalDays,
                      totalTrips: widget.totalTrips,
                      countries: widget.countries,
                      cities: widget.cities,
                      continentCounts: widget.continentCounts,
                      transportMix: widget.transportMix,
                    ),
                  ), // TravelStats uses a SegmentedButton for km/mi and LinearProgressIndicator for transport mix proportions. [7][8]

                  const SizedBox(height: 12),

                  // Visited locations map
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: VisitedLocationsMap(
                      places: widget.visitedPlaces,
                      originLat: widget.originLat,
                      originLng: widget.originLng,
                      onOpenPlace: widget.onOpenPlace,
                      onRefresh: widget.onRefresh,
                    ),
                  ), // A mapped visualization of visited places, with year chips and a “peek” card on marker select; integrates with the shared map contract. [9]

                  const SizedBox(height: 12),

                  // My contributions (Places / Reviews / Photos tabs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _ContribAdapter(
                      places: widget.contributionPlaces,
                      reviews: widget.contributionReviews,
                      photoUrls: widget.contributionPhotoUrls,
                      originLat: widget.originLat,
                      originLng: widget.originLng,
                      onOpenPlace: widget.onOpenPlace,
                      onOpenReviewTarget: widget.onOpenReviewTarget,
                      onAddPlace: widget.onAddPlace,
                      onWriteReview: widget.onWriteReview,
                      onUploadPhoto: widget.onUploadPhoto,
                    ),
                  ), // The contributions section uses TabBar/TabBarView internally with per-tab refresh/load-more hooks. [1]

                  const SizedBox(height: 12),

                  // Activity feed
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ActivityFeed(
                      items: widget.activityItems,
                      loading: widget.loading,
                      hasMore: false,
                      onRefresh: widget.onRefresh ?? () async {},
                      onLoadMore: null,
                      onOpen: (item) {
                        // Route to the referenced content if provided
                      },
                      onDelete: (item) async {
                        // Hook to remove the activity item
                      },
                      sectionTitle: 'Activity',
                    ),
                  ), // RefreshIndicator and ListView.separated provide a clean, pull-to-refresh, paginated feed with swipe-to-dismiss actions. [2][10]

                  const SizedBox(height: 12),

                  // My journeys
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: MyJourneys(
                      journeys: widget.journeys,
                      loading: widget.loading,
                      hasMore: false,
                      onRefresh: widget.onRefresh,
                      onLoadMore: null,
                      onOpenJourney: (j) {
                        // Navigate to journey details
                      },
                      onEditJourney: (j) {
                        // Open editor
                      },
                      onDeleteJourney: (j) async {
                        // Delete journey
                      },
                      onReorderJourneys: (oldIndex, newIndex) async {
                        // Persist new order
                      },
                      onCreateJourney: widget.onCreateJourney,
                    ),
                  ), // ReorderableListView enables drag-to-reorder while Expansion-based content reveals per-journey timelines inline. [11][12]

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ); // CustomScrollView with slivers composes a collapsing header and scrollable sections efficiently; RefreshIndicator adds pull-to-refresh on the whole page. [1][2]
  }

  // Basic completeness heuristic; replace with real business logic if needed.
  double _profileCompleteness() {
    var score = 0.0;
    if (widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty) score += 0.2;
    if ((widget.bio ?? '').trim().isNotEmpty) score += 0.2;
    if ((widget.location ?? '').trim().isNotEmpty) score += 0.2;
    if (widget.photosCount > 0) score += 0.2;
    if (widget.placesCount > 0) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  // Optional: jump to sections when stat tiles are tapped (no-op anchor placeholder).
  void _scrollTo(String anchor) {
    // In a more advanced setup, consider using Scrollable.ensureVisible with GlobalKeys per section.
  }
}

// Adapter to MyContributions' current constructor (expects ReviewItem from that widget).
class _ContribAdapter extends StatelessWidget {
  const _ContribAdapter({
    required this.places,
    required this.reviews,
    required this.photoUrls,
    this.originLat,
    this.originLng,
    this.onOpenPlace,
    this.onOpenReviewTarget,
    this.onAddPlace,
    this.onWriteReview,
    this.onUploadPhoto,
  });

  final List<Place> places;
  final List<ContributionReview> reviews;
  final List<String> photoUrls;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpenPlace;
  final void Function(ContributionReview item)? onOpenReviewTarget;
  final VoidCallback? onAddPlace;
  final VoidCallback? onWriteReview;
  final VoidCallback? onUploadPhoto;

  @override
  Widget build(BuildContext context) {
    return MyContributions(
      totalPlaces: places.length,
      totalReviews: reviews.length,
      totalPhotos: photoUrls.length,
      places: places,
      placesLoading: false,
      placesHasMore: false,
      onPlacesRefresh: null,
      onPlacesLoadMore: null,
      onOpenPlace: onOpenPlace,
      onToggleWishlist: null,
      reviews: reviews
          .map((e) => ReviewItem(id: e.id, author: '', rating: 0, text: e.subtitle, date: DateTime.now(), source: null))
          .toList(growable: false),
      reviewsLoading: false,
      reviewsHasMore: false,
      onReviewsRefresh: null,
      onReviewsLoadMore: null,
      onOpenReviewTarget: (item) {
        // This ReviewItem is a lightweight placeholder mapped from ContributionReview.
        final match = reviews.firstWhere((r) => r.subtitle == item.subtitle, orElse: () => ContributionReview(id: item.id, title: item.title, subtitle: item.subtitle));
        onOpenReviewTarget?.call(match);
      },
      photoUrls: photoUrls,
      photosLoading: false,
      photosHasMore: false,
      onPhotosRefresh: null,
      onPhotosLoadMore: null,
      onOpenPhotoIndex: (i) {
        // Push full-screen viewer if desired
      },
      onAddPlace: onAddPlace,
      onWriteReview: onWriteReview,
      onUploadPhoto: onUploadPhoto,
      originLat: originLat,
      originLng: originLng,
      heroPrefix: 'profile-contrib',
    );
  }
}
