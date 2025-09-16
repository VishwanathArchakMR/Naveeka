// lib/features/trails/presentation/widgets/feed_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.trailId,
    required this.title,
    required this.imageUrl,
    required this.heroTag,
    this.rating,
    this.distanceKm,
    this.elevationGainM,
    this.difficulty, // easy | moderate | hard
    this.tags = const <String>[],
    this.isFavorite = false,
    this.onOpen, // VoidCallback
    this.onToggleFavorite, // Future<void> Function(bool next)
    this.onShare, // VoidCallback
    this.onNavigate, // VoidCallback
  });

  final String trailId;
  final String title;
  final String imageUrl;
  final Object heroTag;

  final double? rating;
  final double? distanceKm;
  final double? elevationGainM;
  final String? difficulty;
  final List<String> tags;

  final bool isFavorite;

  final VoidCallback? onOpen;
  final Future<void> Function(bool next)? onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover with Hero + cached image + gradient overlay + top actions
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  // Legibility gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.6, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top-right actions
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _GlassIconButton(
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : cs.onSurface,
                      onPressed: onToggleFavorite == null
                          ? null
                          : () => onToggleFavorite!.call(!isFavorite),
                    ),
                  ),
                  if (onShare != null)
                    Positioned(
                      right: 56,
                      top: 8,
                      child: _GlassIconButton(
                        icon: Icons.ios_share,
                        color: cs.onSurface,
                        onPressed: onShare,
                      ),
                    ),
                  if (onNavigate != null)
                    Positioned(
                      right: 104,
                      top: 8,
                      child: _GlassIconButton(
                        icon: Icons.directions_walk,
                        color: cs.onSurface,
                        onPressed: onNavigate,
                      ),
                    ),
                  // Bottom-left title and stats
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _TitleAndStats(
                      title: title,
                      rating: rating,
                      distanceKm: distanceKm,
                      elevationGainM: elevationGainM,
                      difficulty: difficulty,
                    ),
                  ),
                ],
              ),
            ),

            // Tags
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _TagsRow(tags: tags),
              ),
          ],
        ),
      ),
    );
  }
}

class _TitleAndStats extends StatelessWidget {
  const _TitleAndStats({
    required this.title,
    this.rating,
    this.distanceKm,
    this.elevationGainM,
    this.difficulty,
  });

  final String title;
  final double? rating;
  final double? distanceKm;
  final double? elevationGainM;
  final String? difficulty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        // Stats row
        Row(
          children: [
            if (rating != null) ...[
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                rating!.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
            ],
            if (distanceKm != null) ...[
              const Icon(Icons.place_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '${distanceKm!.toStringAsFixed(distanceKm! >= 10 ? 0 : 1)} km',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 10),
            ],
            if (elevationGainM != null) ...[
              const Icon(Icons.trending_up, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '${elevationGainM!.toStringAsFixed(0)} m',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 10),
            ],
            if ((difficulty ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  difficulty!.toUpperCase(),
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.take(6).map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            t,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: onPressed == null ? cs.onSurfaceVariant : color, size: 20),
        ),
      ),
    );
  }
}
