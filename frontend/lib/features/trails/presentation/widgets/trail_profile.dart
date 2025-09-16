// lib/features/trails/presentation/widgets/trail_profile.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/trail_location_api.dart' show TrailDetail, GeoPoint;
import '../../data/trails_api.dart' show TrailReview, TrailStats;
import 'trail_map_view.dart';

class TrailProfile extends StatefulWidget {
  const TrailProfile({
    super.key,
    required this.detail,
    this.stats,
    this.reviews = const <TrailReview>[],
    this.photos = const <String>[],
    this.isFavorite = false,

    // Actions
    this.onToggleFavorite, // Future<bool> Function(bool next)
    this.onShare, // VoidCallback
    this.onStartNav, // VoidCallback
    this.onOpenChat, // VoidCallback

    // Hero tag for shared element from feed/list
    this.heroTag,
  });

  final TrailDetail detail;
  final TrailStats? stats;
  final List<TrailReview> reviews;
  final List<String> photos;

  final bool isFavorite;

  final Future<bool> Function(bool next)? onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onStartNav;
  final VoidCallback? onOpenChat;

  final Object? heroTag;

  @override
  State<TrailProfile> createState() => _TrailProfileState();
}

class _TrailProfileState extends State<TrailProfile> with TickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // Tabs: Overview, Map, Reviews, Photos
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              expandedHeight: 300,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                if (widget.onShare != null)
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.ios_share),
                    onPressed: widget.onShare,
                  ),
                if (widget.onOpenChat != null)
                  IconButton(
                    tooltip: 'Chat',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: widget.onOpenChat,
                  ),
                if (widget.onToggleFavorite != null)
                  IconButton(
                    tooltip: widget.isFavorite ? 'Unfavorite' : 'Favorite',
                    icon: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border),
                    onPressed: () async {
                      await widget.onToggleFavorite!.call(!widget.isFavorite);
                    },
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image with optional Hero
                    widget.heroTag != null
                        ? Hero(
                            tag: widget.heroTag!,
                            child: _CoverImage(url: summary.thumbnailUrl),
                          )
                        : _CoverImage(url: summary.thumbnailUrl),

                    // Legibility gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            stops: const [0.0, 0.6, 1.0],
                            colors: [
                              Colors.black.withValues(alpha: 0.46),
                              Colors.black.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom-left title block
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _TitleBlock(
                        title: summary.label,
                        distanceKm: widget.detail.lengthKm ?? summary.distanceKm,
                        elevationGainM: widget.detail.elevationGainM ?? summary.distanceKm,
                        difficulty: summary.label.isNotEmpty ? widget.detail.summary.label : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pinned TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeaderDelegate(
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
                    Tab(text: 'Map', icon: Icon(Icons.map_outlined)),
                    Tab(text: 'Reviews', icon: Icon(Icons.reviews_outlined)),
                    Tab(text: 'Photos', icon: Icon(Icons.photo_library_outlined)),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabs,
          children: [
            // Overview
            _OverviewTab(detail: widget.detail, stats: widget.stats, onStartNav: widget.onStartNav),

            // Map
            _MapTab(detail: widget.detail),

            // Reviews
            _ReviewsTab(reviews: widget.reviews),

            // Photos
            _PhotosTab(photos: widget.photos),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if ((url ?? '').isEmpty) {
      return Container(color: cs.surfaceContainerHigh.withValues(alpha: 1.0));
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (ctx, _) => Container(color: cs.surfaceContainerHigh.withValues(alpha: 1.0)),
      errorWidget: (ctx, u, e) => Container(
        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    this.distanceKm,
    this.elevationGainM,
    this.difficulty,
  });

  final String title;
  final double? distanceKm;
  final double? elevationGainM;
  final String? difficulty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (distanceKm != null)
              _Pill(icon: Icons.route, label: '${distanceKm!.toStringAsFixed(distanceKm! >= 10 ? 0 : 1)} km'),
            if (elevationGainM != null)
              _Pill(icon: Icons.trending_up, label: '${elevationGainM!.toStringAsFixed(0)} m'),
            if ((difficulty ?? '').isNotEmpty) _Pill(icon: Icons.flag_outlined, label: (difficulty ?? '').toUpperCase()),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onInverseSurface),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => false;
}

// ---------------- Tabs ----------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail, this.stats, this.onStartNav});

  final TrailDetail detail;
  final TrailStats? stats;
  final VoidCallback? onStartNav;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = detail.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Top quick stats
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(icon: Icons.star, label: 'Rating', value: (stats?.avgRating ?? 0).toStringAsFixed(1)),
              _StatTile(icon: Icons.reviews_outlined, label: 'Reviews', value: (stats?.reviewCount ?? 0).toString()),
              _StatTile(icon: Icons.favorite_outline, label: 'Saves', value: (stats?.favoriteCount ?? 0).toString()),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tags
        if (s.tags.isNotEmpty) _SectionHeader('Tags'),
        if (s.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(t, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    ))
                .toList(growable: false),
          ),
        if (s.tags.isNotEmpty) const SizedBox(height: 12),

        // Description
        if ((detail.description ?? '').trim().isNotEmpty) _SectionHeader('About this trail'),
        if ((detail.description ?? '').trim().isNotEmpty)
          Text(detail.description!.trim()),
        if ((detail.description ?? '').trim().isNotEmpty) const SizedBox(height: 12),

        // Start navigation
        if (onStartNav != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartNav,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Start navigation'),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({required this.detail});
  final TrailDetail detail;

  @override
  Widget build(BuildContext context) {
    final points = detail.geometry ?? const <GeoPoint>[];
    final heads = <GeoPoint>[];
    if (points.isNotEmpty) {
      heads.add(points.first);
      heads.add(points.last);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TrailMapView(
        geometry: points,
        trailheads: heads,
        padding: const EdgeInsets.all(24),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews});
  final List<TrailReview> reviews;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (reviews.isEmpty) {
      return Center(
        child: Text('No reviews yet', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, i) {
        final r = reviews[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            child: Text(r.rating.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          title: Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            r.createdAt.toLocal().toString(),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        );
      },
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (photos.isEmpty) {
      return Center(
        child: Text('No photos yet', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 900
        ? 5
        : width >= 600
            ? 4
            : 3;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final url = photos[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (ctx, _) => Container(color: cs.surfaceContainerHigh.withValues(alpha: 1.0)),
            errorWidget: (ctx, u, e) => Container(
              color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}
