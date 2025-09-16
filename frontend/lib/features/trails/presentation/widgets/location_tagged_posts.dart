// lib/features/trails/presentation/widgets/location_tagged_posts.dart

import 'package:flutter/material.dart';

import 'feed_card.dart';

class LocationTaggedPost {
  const LocationTaggedPost({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.heroTag,
    this.rating,
    this.distanceKm,
    this.elevationGainM,
    this.difficulty,
    this.tags = const <String>[],
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String imageUrl;
  final Object? heroTag;

  final double? rating;
  final double? distanceKm;
  final double? elevationGainM;
  final String? difficulty;
  final List<String> tags;

  final bool isFavorite;
}

class LocationTaggedPosts extends StatelessWidget {
  const LocationTaggedPosts({
    super.key,
    required this.items,
    required this.onRefresh,
    this.onOpenPost,
    this.onToggleFavorite,
    this.onShare,
    this.onNavigate,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.maxCrossAxisExtent = 360,
    this.gridMainSpacing = 12,
    this.gridCrossSpacing = 12,
    this.header,
    this.footer,
    this.loading = false,
    this.error,
  });

  final List<LocationTaggedPost> items;
  final Future<void> Function() onRefresh;

  final void Function(LocationTaggedPost post)? onOpenPost;
  final Future<void> Function(LocationTaggedPost post, bool next)? onToggleFavorite;
  final void Function(LocationTaggedPost post)? onShare;
  final void Function(LocationTaggedPost post)? onNavigate;

  final EdgeInsets padding;
  final double maxCrossAxisExtent;
  final double gridMainSpacing;
  final double gridCrossSpacing;

  final Widget? header;
  final Widget? footer;

  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: padding,
            sliver: _buildGrid(context),
          ),
          if (loading) _LoadingSliver(color: cs.onSurfaceVariant),
          if (error != null && !loading)
            SliverToBoxAdapter(
              child: _ErrorState(message: error!, onRetry: onRefresh),
            ),
          if (footer != null) SliverToBoxAdapter(child: footer),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (items.isEmpty && !loading && error == null) {
      return const SliverToBoxAdapter(
        child: _EmptyState(),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: gridMainSpacing,
        crossAxisSpacing: gridCrossSpacing,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final p = items[index];
          return FeedCard(
            trailId: p.id,
            title: p.title,
            imageUrl: p.imageUrl,
            heroTag: p.heroTag ?? 'locpost-${p.id}',
            rating: p.rating,
            distanceKm: p.distanceKm,
            elevationGainM: p.elevationGainM,
            difficulty: p.difficulty,
            tags: p.tags,
            isFavorite: p.isFavorite,
            onOpen: onOpenPost == null ? null : () => onOpenPost!(p),
            onToggleFavorite: onToggleFavorite == null ? null : (next) => onToggleFavorite!(p, next),
            onShare: onShare == null ? null : () => onShare!(p),
            onNavigate: onNavigate == null ? null : () => onNavigate!(p),
          );
        },
        childCount: items.length,
      ),
    );
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.photo_library_outlined, color: cs.primary, size: 36),
          ),
          const SizedBox(height: 12),
          Text('No posts for this location', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Try expanding the area or refreshing', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 28),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
