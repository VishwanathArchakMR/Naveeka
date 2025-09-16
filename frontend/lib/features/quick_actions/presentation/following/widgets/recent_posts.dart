// lib/features/quick_actions/presentation/following/widgets/recent_posts.dart

import 'dart:async';
import 'package:flutter/material.dart';

class RecentPost {
  const RecentPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.imageUrl,
    required this.caption,
    required this.timestamp,
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;

  final String imageUrl;
  final String caption;
  final DateTime timestamp;

  final bool liked;
  final int likeCount;
  final int commentCount;

  RecentPost copyWith({
    bool? liked,
    int? likeCount,
  }) {
    return RecentPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      imageUrl: imageUrl,
      caption: caption,
      timestamp: timestamp,
      liked: liked ?? this.liked,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
    );
  }
}

/// A horizontal “Recent posts” carousel for followed users:
/// - Horizontal ListView.builder with lazy item creation
/// - Infinite scroll trigger near end
/// - Animated like toggle + counters
/// - Author chip and time label
/// - Color.withValues used for overlays/badges (no withOpacity)
class RecentPosts extends StatefulWidget {
  const RecentPosts({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenPost,
    this.onOpenAuthor,
    this.onToggleLike, // Future<bool> Function(RecentPost post, bool next)
    this.onComment, // void Function(RecentPost post)
    this.onShare, // void Function(RecentPost post)
    this.sectionTitle = 'Recent posts',
    this.height = 230,
  });

  final List<RecentPost> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(RecentPost post)? onOpenPost;
  final void Function(String authorId)? onOpenAuthor;
  final Future<bool> Function(RecentPost post, bool next)? onToggleLike;
  final void Function(RecentPost post)? onComment;
  final void Function(RecentPost post)? onShare;

  final String sectionTitle;
  final double height;

  @override
  State<RecentPosts> createState() => _RecentPostsState();
}

class _RecentPostsState extends State<RecentPosts> {
  final _scroll = ScrollController();
  bool _loadRequested = false;
  late List<RecentPost> _local;

  @override
  void initState() {
    super.initState();
    _local = [...widget.items];
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant RecentPosts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _local = [...widget.items];
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
    // Trigger when scrolled near the end (horizontal)
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Horizontal lists require a fixed height and set scrollDirection to Axis.horizontal for proper layout and lazy loading. [1][3]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAny = _local.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: widget.height + 56, // header + list height
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (widget.loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),

            // Body: horizontal carousel
            SizedBox(
              height: widget.height,
              child: hasAny
                  ? RefreshIndicator.adaptive(
                      onRefresh: widget.onRefresh,
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: _local.length + 1,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, i) {
                          if (i == _local.length) return _tail();
                          final p = _local[i];
                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 8 : 6, right: i == _local.length - 1 ? 8 : 6),
                            child: _PostCard(
                              post: p,
                              height: widget.height,
                              onOpen: widget.onOpenPost,
                              onOpenAuthor: widget.onOpenAuthor,
                              onToggleLike: widget.onToggleLike == null
                                  ? null
                                  : (next) async {
                                      // optimistic update
                                      final idx = _local.indexWhere((e) => e.id == p.id);
                                      if (idx != -1) {
                                        final cur = _local[idx];
                                        final liked = next;
                                        final count = (cur.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
                                        setState(() => _local[idx] = cur.copyWith(liked: liked, likeCount: count));
                                      }
                                      final ok = await widget.onToggleLike!(p, next);
                                      if (!ok && mounted && idx != -1) {
                                        final cur = _local[idx];
                                        final liked = !next;
                                        final count = (cur.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
                                        setState(() => _local[idx] = cur.copyWith(liked: liked, likeCount: count));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not update like')),
                                        );
                                      }
                                    },
                              onComment: widget.onComment,
                              onShare: widget.onShare,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No posts yet',
                          style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 1.0)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tail() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Text('· end ·')),
      );
    }
    return const SizedBox(width: 24);
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.height,
    this.onOpen,
    this.onOpenAuthor,
    this.onToggleLike,
    this.onComment,
    this.onShare,
  });

  final RecentPost post;
  final double height;
  final void Function(RecentPost post)? onOpen;
  final void Function(String authorId)? onOpenAuthor;
  final Future<void> Function(bool next)? onToggleLike;
  final void Function(RecentPost post)? onComment;
  final void Function(RecentPost post)? onShare;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardWidth = height * 0.72;

    return SizedBox(
      width: cardWidth,
      height: height,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onOpen == null ? null : () => onOpen!(post),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
                  ),
                ),
              ),

              // Gradient overlay for text legibility
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(0, 0.0),
                      end: const Alignment(0, 1),
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),

              // Top row: author chip + time
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    _AuthorChip(
                      name: post.authorName,
                      avatarUrl: post.authorAvatarUrl,
                      onTap: onOpenAuthor == null ? null : () => onOpenAuthor!(post.authorId),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_timeAgo(post.timestamp), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

              // Bottom caption + actions
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.caption.trim().isNotEmpty)
                      Text(
                        post.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _LikeButton(
                          liked: post.liked,
                          count: post.likeCount,
                          onPressed: onToggleLike == null ? null : () => onToggleLike!(!post.liked),
                        ),
                        const SizedBox(width: 8),
                        _IconPill(
                          icon: Icons.mode_comment_outlined,
                          label: post.commentCount > 0 ? '${post.commentCount}' : 'Comment',
                          onTap: onComment == null ? null : () => onComment!(post),
                        ),
                        const SizedBox(width: 8),
                        _IconPill(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: onShare == null ? null : () => onShare!(post),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime ts) {
    final now = DateTime.now();
    final d = now.difference(ts);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
  }
}

class _AuthorChip extends StatelessWidget {
  const _AuthorChip({required this.name, this.avatarUrl, this.onTap});
  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.black12,
            backgroundImage: (avatarUrl != null && avatarUrl!.trim().isNotEmpty) ? NetworkImage(avatarUrl!) : null,
            child: (avatarUrl == null || avatarUrl!.trim().isEmpty)
                ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 12))
                : null,
          ),
          const SizedBox(width: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, this.onPressed});
  final bool liked;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = liked ? cs.primary : Colors.white;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: liked ? cs.primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border, size: 16, color: color),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Text(
                count > 0 ? '$count' : 'Like',
                key: ValueKey<int>(count),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
