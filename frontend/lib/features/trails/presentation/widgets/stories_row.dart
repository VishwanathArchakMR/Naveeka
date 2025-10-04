// lib/features/trails/presentation/widgets/stories_row.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

@immutable
class StoryItem {
  const StoryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.unread = false,
    this.heroTag,
    this.progress = 0.0, // 0.0..1.0 for optional seen progress ring
  });

  final String id;
  final String title;
  final String imageUrl;
  final bool unread;
  final Object? heroTag;
  final double progress;
}

class StoriesRow extends StatelessWidget {
  const StoriesRow({
    super.key,
    required this.items,
    this.onOpenStory, // void Function(StoryItem item)
    this.onAddStory, // VoidCallback
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.itemExtent = 76,
    this.spacing = 12,
    this.showTitles = true,
    this.enableProgress = true,
  });

  final List<StoryItem> items;
  final void Function(StoryItem item)? onOpenStory;
  final VoidCallback? onAddStory;

  final EdgeInsets padding;
  final double itemExtent;
  final double spacing;
  final bool showTitles;
  final bool enableProgress;

  @override
  Widget build(BuildContext context) {
    final total = (onAddStory != null ? 1 : 0) + items.length;
    return SizedBox(
      height: showTitles ? (itemExtent + 34) : itemExtent,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: total,
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
            enableProgress: enableProgress,
            onTap: onOpenStory == null ? null : () => onOpenStory!(item),
          );
        },
      ),
    );
  }
}

class _StoryTile extends StatefulWidget {
  const _StoryTile({
    required this.item,
    required this.size,
    required this.showTitle,
    required this.enableProgress,
    this.onTap,
  });

  final StoryItem item;
  final double size;
  final bool showTitle;
  final bool enableProgress;
  final VoidCallback? onTap;

  @override
  State<_StoryTile> createState() => _StoryTileState();
}

class _StoryTileState extends State<_StoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ringColors = widget.item.unread
        ? <Color>[const Color(0xFFff7e5f), const Color(0xFFfeb47b)]
        : <Color>[cs.outlineVariant, cs.outlineVariant];

    final avatar = ClipOval(
      child: Hero(
        tag: widget.item.heroTag ?? 'story-${widget.item.id}',
        child: CachedNetworkImage(
          imageUrl: widget.item.imageUrl,
          width: widget.size - 8,
          height: widget.size - 8,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: widget.size - 8,
            height: widget.size - 8,
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: widget.size - 8,
            height: widget.size - 8,
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.size,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.96 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Unread gradient ring or outline
                  Container(
                    width: widget.size,
                    height: widget.size,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: ringColors),
                    ),
                  ),
                  // Frosted inner mask for depth
                  ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: widget.size - 6,
                          height: widget.size - 6,
                        ),
                      ),
                    ),
                  ),
                  // Avatar image
                  avatar,
                  // Optional progress ring (seen progress)
                  if (widget.enableProgress && widget.item.progress > 0)
                    SizedBox(
                      width: widget.size + 2,
                      height: widget.size + 2,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: widget.item.progress.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return CircularProgressIndicator(
                            strokeWidth: 3,
                            value: value == 0 ? null : value,
                            // Use a soft on-surface color for subtle overlay
                            color: cs.onSurfaceVariant,
                            backgroundColor: Colors.transparent,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (widget.showTitle) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: widget.size + 12,
                child: Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
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
                  child: Icon(
                    Icons.person_outline,
                    color: cs.onSurfaceVariant,
                    size: size * 0.46,
                  ),
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
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
