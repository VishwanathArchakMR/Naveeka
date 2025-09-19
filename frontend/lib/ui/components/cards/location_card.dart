// lib/ui/components/cards/location_card.dart

import 'package:flutter/material.dart';

/// Lightweight UI view model for rendering a location/place item.
class LocationViewData {
  const LocationViewData({
    required this.id,
    required this.name,
    this.category,
    this.addressLine,
    this.distanceText, // e.g., "1.2 km away"
    this.isOpenNow,
    this.rating, // 0..5
    this.reviewCount,
    this.thumbnailUrl,
    this.tags = const <String>[],
    this.priceLevel, // e.g., "$$", optional
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String? category;
  final String? addressLine;
  final String? distanceText;
  final bool? isOpenNow;
  final double? rating;
  final int? reviewCount;
  final String? thumbnailUrl;
  final List<String> tags;
  final String? priceLevel;
  final bool isFavorite;
}

/// A Material 3 location card with thumbnail, title, category/address, chips for
/// distance/status, rating row, tags, and favorite/directions actions with ripple. 
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.data,
    this.onTap,
    this.onFavoriteToggle,
    this.onDirections,
    this.onCall,
    this.dense = false,
    this.heroTag,
  });

  final LocationViewData data;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDirections;
  final VoidCallback? onCall;
  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final Widget leading = _buildLeading(context);
    final Widget content = _buildContent(context);
    final Widget? actions = _buildActions(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        leading,
        const SizedBox(width: 12),
        Expanded(child: content),
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              row,
              if (actions != null) ...[
                SizedBox(height: dense ? 8 : 12),
                actions,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    final size = dense ? 60.0 : 76.0;

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.location_on_rounded,
        size: dense ? 26 : 30,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (data.thumbnailUrl == null || data.thumbnailUrl!.trim().isEmpty) {
      return _FavoriteOverlay(
        size: size,
        borderRadius: 12,
        isFavorite: data.isFavorite,
        onFavoriteToggle: onFavoriteToggle,
        child: placeholder,
      );
    }

    final img = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          data.thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );

    final withHero = heroTag != null ? Hero(tag: heroTag!, child: img) : img;

    return _FavoriteOverlay(
      size: size,
      borderRadius: 12,
      isFavorite: data.isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      child: withHero,
    );
  }

  Widget _buildContent(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final title = Text(
      data.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (dense ? t.textTheme.titleSmall : t.textTheme.titleMedium)?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );

    final categoryOrAddress = Text(
      data.category?.trim().isNotEmpty == true
          ? data.category!
          : (data.addressLine ?? ''),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    );

    final chips = _ChipsRow(
      distanceText: data.distanceText,
      isOpenNow: data.isOpenNow,
      priceLevel: data.priceLevel,
      dense: dense,
    );

    final rating = _RatingRow(
      rating: data.rating,
      count: data.reviewCount,
      dense: dense,
    );

    final contentChildren = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: title),
          if (onDirections != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_rounded, size: 20),
              tooltip: 'Directions',
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      categoryOrAddress,
      const SizedBox(height: 6),
      chips,
      if (data.rating != null || (data.reviewCount ?? 0) > 0) ...[
        const SizedBox(height: 6),
        rating,
      ],
      if (data.tags.isNotEmpty) ...[
        SizedBox(height: dense ? 6 : 8),
        _TagsWrap(tags: data.tags, dense: dense),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: contentChildren,
    );
  }

  Widget? _buildActions(BuildContext context) {
    if (onCall == null && onDirections == null) return null;

    final v = dense ? VisualDensity.compact : VisualDensity.standard;

    final buttons = <Widget>[];
    if (onCall != null) {
      buttons.add(OutlinedButton.icon(
        onPressed: onCall,
        style: OutlinedButton.styleFrom(visualDensity: v),
        icon: const Icon(Icons.phone_rounded, size: 18),
        label: const Text('Call'),
      ));
      buttons.add(const SizedBox(width: 8));
    }
    if (onDirections != null) {
      buttons.add(FilledButton.tonalIcon(
        onPressed: onDirections,
        style: FilledButton.styleFrom(visualDensity: v),
        icon: const Icon(Icons.route_rounded, size: 18),
        label: const Text('Route'),
      ));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons);
  }
}

class _FavoriteOverlay extends StatelessWidget {
  const _FavoriteOverlay({
    required this.size,
    required this.borderRadius,
    required this.child,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final double size;
  final double borderRadius;
  final Widget child;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final favBtn = IconButton.filledTonal(
      onPressed: onFavoriteToggle,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      isSelected: isFavorite,
      selectedIcon: const Icon(Icons.favorite_rounded, size: 18),
      icon: const Icon(Icons.favorite_border_rounded, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      ),
    );

    return Stack(
      children: <Widget>[
        child,
        Positioned(
          right: 4,
          top: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: favBtn,
          ),
        ),
      ],
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.distanceText,
    required this.isOpenNow,
    required this.priceLevel,
    required this.dense,
  });

  final String? distanceText;
  final bool? isOpenNow;
  final String? priceLevel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <Widget>[];

    if (distanceText != null && distanceText!.trim().isNotEmpty) {
      items.add(_Chip(
        label: distanceText!,
        icon: Icons.place_rounded,
        bg: cs.surfaceContainerHighest.withValues(alpha: 0.9),
        fg: cs.onSurfaceVariant,
        dense: dense,
      ));
    }

    if (isOpenNow != null) {
      final open = isOpenNow!;
      items.add(_Chip(
        label: open ? 'Open now' : 'Closed',
        icon: open ? Icons.access_time_filled_rounded : Icons.schedule_rounded,
        bg: (open ? cs.primary : cs.error).withValues(alpha: 0.14),
        fg: open ? cs.onPrimaryContainer : cs.onErrorContainer,
        dense: dense,
      ));
    }

    if (priceLevel != null && priceLevel!.trim().isNotEmpty) {
      items.add(_Chip(
        label: priceLevel!,
        icon: Icons.payments_rounded,
        bg: cs.surfaceContainerHighest.withValues(alpha: 0.9),
        fg: cs.onSurfaceVariant,
        dense: dense,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.dense,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: dense ? 14 : 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.count, required this.dense});

  final double? rating;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (rating == null && (count == null || count == 0)) return const SizedBox.shrink();
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final r = (rating ?? 0).clamp(0, 5).toDouble();
    final c = (count ?? 0).clamp(0, 1000000);

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = r >= i + 1;
        final half = !filled && r > i && r < i + 1;
        return Icon(
          half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_border_rounded),
          size: dense ? 16 : 18,
          color: cs.secondary,
        );
      }),
    );

    final text = Text(
      '${r.toStringAsFixed(1)} (${_shortCount(c)})',
      style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        stars,
        const SizedBox(width: 8),
        text,
      ],
    );
  }

  String _shortCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }
}

class _TagsWrap extends StatelessWidget {
  const _TagsWrap({required this.tags, required this.dense});

  final List<String> tags;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final padH = dense ? 6.0 : 8.0;
    final padV = dense ? 3.0 : 4.0;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((t) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            t,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      }).toList(growable: false),
    );
  }
}
