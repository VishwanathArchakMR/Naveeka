// lib/features/trails/presentation/widgets/stories_row.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryItem {
  const StoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.unread = false,
    this.heroTag,
  });

  final String id;
  final String title;
  final String imageUrl;
  final bool unread;
  final Object? heroTag;
}

class StoriesRow extends StatelessWidget {
  const StoriesRow({
    super.key,
    required this.items,
    this.onOpenStory, // void Function(StoryItem item)
    this.onAddStory,  // VoidCallback
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.itemExtent = 76,
    this.spacing = 12,
    this.showTitles = true,
  });

  final List<StoryItem> items;
  final void Function(StoryItem item)? onOpenStory;
  final VoidCallback? onAddStory;

  final EdgeInsets padding;
  final double itemExtent;
  final double spacing;
  final bool showTitles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: showTitles ? (itemExtent + 34) : itemExtent,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: (onAddStory != null ? 1 : 0) + items.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          if (onAddStory != null && index == 0) {
            return _AddTile(
              size: itemExtent,
              label: showTitles ? 'Your story' : null,
              onTap: onAddStory,
            );
          }
          final item = items[index - (onAddStory != null ? 1 : 0)];
          return _StoryTile(
            item: item,
            size: itemExtent,
            showTitle: showTitles,
            onTap: onOpenStory == null ? null : () => onOpenStory!(item),
          );
        },
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.item,
    required this.size,
    required this.showTitle,
    this.onTap,
  });

  final StoryItem item;
  final double size;
  final bool showTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ring = item.unread
        ? const [Color(0xFFff7e5f), Color(0xFFfeb47b)] // warm gradient ring for unread
        : [cs.outlineVariant, cs.outlineVariant];

    final avatar = ClipOval(
      child: Hero(
        tag: item.heroTag ?? 'story-${item.id}',
        child: CachedNetworkImage(
          imageUrl: item.imageUrl,
          width: size - 6,
          height: size - 6,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size - 6,
            height: size - 6,
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            alignment: Alignment.center,
            child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            width: size - 6,
            height: size - 6,
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );

    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient ring (unread) -> inner avatar
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: ring),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: avatar,
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: size + 12,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, this.label, this.onTap});

  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.person_outline, color: cs.onSurfaceVariant, size: size * 0.46),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Material(
                    color: cs.primary.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
            if ((label ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: size + 12,
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
