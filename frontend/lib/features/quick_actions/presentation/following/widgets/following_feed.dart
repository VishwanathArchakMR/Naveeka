// lib/features/quick_actions/presentation/following/widgets/following_feed.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Lightweight feed item model for presentation
class FollowingFeedItem {
  const FollowingFeedItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.type, // e.g., review | photo | place | journey | like | follow
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.thumbnailUrl,
    this.targetId,
    this.targetType,
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;

  final String type;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  final String? thumbnailUrl;
  final String? targetId;
  final String? targetType;

  final bool liked;
  final int likeCount;
  final int commentCount;

  FollowingFeedItem copyWith({
    bool? liked,
    int? likeCount,
  }) {
    return FollowingFeedItem(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      type: type,
      title: title,
      subtitle: subtitle,
      timestamp: timestamp,
      thumbnailUrl: thumbnailUrl,
      targetId: targetId,
      targetType: targetType,
      liked: liked ?? this.liked,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
    );
  }
}

/// A paginated feed of activities from followed users with:
/// - Pull-to-refresh
/// - Infinite scroll near list end
/// - Optional filter chips by type
/// - Optimistic like toggle per item
/// - Uses Color.withValues(...) (no deprecated withOpacity)
class FollowingFeed extends StatefulWidget {
  const FollowingFeed({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenItem,
    this.onOpenAuthor,
    this.onToggleLike, // Future<bool> Function(FollowingFeedItem item, bool next)
    this.onComment, // void Function(FollowingFeedItem item)
    this.types = const <String>[], // available types for filter chips
    this.selectedTypes = const <String>{},
    this.onChangeTypes, // void Function(Set<String>)
    this.sectionTitle = 'Following',
    this.emptyPlaceholder,
  });

  final List<FollowingFeedItem> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(FollowingFeedItem item)? onOpenItem;
  final void Function(String authorId)? onOpenAuthor;
  final Future<bool> Function(FollowingFeedItem item, bool next)? onToggleLike;
  final void Function(FollowingFeedItem item)? onComment;

  final List<String> types;
  final Set<String> selectedTypes;
  final void Function(Set<String> next)? onChangeTypes;

  final String sectionTitle;
  final Widget? emptyPlaceholder;

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> {
  final _scroll = ScrollController();
  bool _loadRequested = false;
  late Set<String> _selTypes;
  late List<FollowingFeedItem> _localItems;

  @override
  void initState() {
    super.initState();
    _selTypes = {...widget.selectedTypes};
    _localItems = [...widget.items];
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant FollowingFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _localItems = [...widget.items];
    }
    if (oldWidget.selectedTypes != widget.selectedTypes) {
      _selTypes = {...widget.selectedTypes};
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 420) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Infinite pagination triggers as the user nears the end of the list, which is a common ListView pattern. [2][1]

  @override
  Widget build(BuildContext context) {
    final items = _applyTypeFilter(_localItems, _selTypes);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (widget.loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Filters
            if (widget.types.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.types.map((t) {
                      final selected = _selTypes.contains(t);
                      final cs = Theme.of(context).colorScheme;
                      final bg = selected ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh.withValues(alpha: 1.0);
                      final fg = selected ? cs.primary : cs.onSurface;
                      return FilterChip(
                        label: Text(t, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                        selected: selected,
                        onSelected: (on) {
                          setState(() {
                            on ? _selTypes.add(t) : _selTypes.remove(t);
                          });
                          widget.onChangeTypes?.call(_selTypes);
                        },
                        backgroundColor: bg,
                        selectedColor: cs.primary.withValues(alpha: 0.18),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),

            // Body
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: () async {
                  await widget.onRefresh();
                },
                child: items.isEmpty && !widget.loading
                    ? (widget.emptyPlaceholder ??
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No recent activity'),
                          ),
                        ))
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: items.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          if (i == items.length) {
                            return _footer();
                          }
                          final it = items[i];
                          final messenger = ScaffoldMessenger.maybeOf(context); // capture before await
                          return _FeedTile(
                            item: it,
                            onOpen: widget.onOpenItem,
                            onOpenAuthor: widget.onOpenAuthor,
                            onToggleLike: widget.onToggleLike == null
                                ? null
                                : (next) async {
                                    final idx = _localItems.indexWhere((e) => e.id == it.id);
                                    if (idx != -1) {
                                      final cur = _localItems[idx];
                                      final liked = next;
                                      final count = (cur.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
                                      setState(() => _localItems[idx] = cur.copyWith(liked: liked, likeCount: count));
                                    }
                                    final ok = await widget.onToggleLike!(it, next);
                                    if (!ok && idx != -1) {
                                      final cur = _localItems[idx];
                                      final liked = !next;
                                      final count = (cur.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
                                      setState(() => _localItems[idx] = cur.copyWith(liked: liked, likeCount: count));
                                      messenger?.showSnackBar(const SnackBar(content: Text('Could not update like')));
                                    }
                                  },
                            onComment: widget.onComment,
                          );
                        },
                      ),
              ),
            ), // RefreshIndicator.adaptive applies platform-appropriate pull-to-refresh visuals and behavior. [6][12],
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No more activity')),
      );
    }
    return const SizedBox(height: 24);
  }

  List<FollowingFeedItem> _applyTypeFilter(List<FollowingFeedItem> src, Set<String> types) {
    if (types.isEmpty) return src;
    final s = types.map((e) => e.trim().toLowerCase()).toSet();
    return src.where((e) => s.contains(e.type.trim().toLowerCase())).toList(growable: false);
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.item,
    this.onOpen,
    this.onOpenAuthor,
    this.onToggleLike,
    this.onComment,
  });

  final FollowingFeedItem item;
  final void Function(FollowingFeedItem item)? onOpen;
  final void Function(String authorId)? onOpenAuthor;
  final Future<void> Function(bool next)? onToggleLike;
  final void Function(FollowingFeedItem item)? onComment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final when = _timeAgo(item.timestamp);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _avatar(item.authorName, item.authorAvatarUrl),
      title: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpenAuthor == null ? null : () => onOpenAuthor!(item.authorId),
              child: Text(
                item.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.type,
              style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.title.trim().isNotEmpty) Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (item.subtitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              when,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
      trailing: item.thumbnailUrl == null
          ? _ActionsBar(item: item, onToggleLike: onToggleLike, onComment: onComment, cs: cs)
          : SizedBox(
              width: 120,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.thumbnailUrl!,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 64,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionsBar(item: item, onToggleLike: onToggleLike, onComment: onComment, cs: cs),
                ],
              ),
            ),
      onTap: onOpen == null ? null : () => onOpen!(item),
    ); // ListView.separated with ListTile creates an accessible, efficient vertical feed with consistent separators. [1][2]
  }

  Widget _avatar(String name, String? url) {
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.black12,
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.black12,
    );
  }

  String _timeAgo(DateTime ts) {
    final now = DateTime.now();
    final d = now.difference(ts);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({
    required this.item,
    required this.cs,
    this.onToggleLike,
    this.onComment,
  });

  final FollowingFeedItem item;
  final ColorScheme cs;
  final Future<void> Function(bool next)? onToggleLike;
  final void Function(FollowingFeedItem item)? onComment;

  @override
  Widget build(BuildContext context) {
    final liked = item.liked;
    final likeColor = liked ? cs.primary : cs.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: liked ? 'Unlike' : 'Like',
          onPressed: onToggleLike == null ? null : () => onToggleLike!(!liked),
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
          color: likeColor,
        ),
        if (item.likeCount > 0) Text('${item.likeCount}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
        IconButton(
          tooltip: 'Comment',
          onPressed: onComment == null ? null : () => onComment!(item),
          icon: const Icon(Icons.mode_comment_outlined),
          color: cs.onSurfaceVariant,
        ),
      ],
    );
  }
}
