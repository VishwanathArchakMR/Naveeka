// lib/features/profile/presentation/widgets/activity_feed.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Categories of activity shown in the feed.
enum ActivityType {
  review,
  favorite,
  placeCreated,
  comment,
  follow,
  ratingUpdate,
}

/// A single activity item rendered in the feed.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp, // DateTime in UTC or local
    this.thumbnailUrl,
    this.targetId,
    this.targetType,
    this.meta, // optional structured extras (e.g., rating: 4.5)
  });

  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? thumbnailUrl;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? meta;
}

/// A reusable, paged activity list with:
/// - Pull-to-refresh and load-more on scroll
/// - Filter chips to narrow types
/// - Dismissible rows for delete/hide
/// - Relative “time ago” stamps
class ActivityFeed extends StatefulWidget {
  const ActivityFeed({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpen,
    this.onDelete,
    this.sectionTitle = 'Activity',
    this.initialFilters = const <ActivityType>{},
    this.emptyPlaceholder,
  });

  final List<ActivityItem> items;
  final bool loading;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final void Function(ActivityItem item)? onOpen;
  final Future<void> Function(ActivityItem item)? onDelete;
  final String sectionTitle;
  final Set<ActivityType> initialFilters;
  final Widget? emptyPlaceholder;

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  final _scroll = ScrollController();
  late Set<ActivityType> _filters;

  @override
  void initState() {
    super.initState();
    _filters = {...widget.initialFilters};
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore == null) return;
    if (!widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      widget.onLoadMore!.call();
    }
  } // Infinite scroll triggers loadMore when approaching the end of the list for a smooth “load as you go” experience. [23]

  @override
  Widget build(BuildContext context) {
    final visible = _applyFilters(widget.items, _filters);
    final hasAny = visible.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.sectionTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (widget.loading)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Filter chips row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ActivityType.values.map((t) {
                final selected = _filters.contains(t);
                return FilterChip(
                  label: Text(_labelOf(t)),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      on ? _filters.add(t) : _filters.remove(t);
                    });
                  },
                );
              }).toList(growable: false),
            ),
          ), // FilterChip provides intuitive multi-select filters in a compact layout that fits above lists. [21]

          const SizedBox(height: 6),

          // Body
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: widget.onRefresh,
              child: hasAny
                  ? ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: visible.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, i) {
                        if (i == visible.length) return _footer(context);
                        final item = visible[i];
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: widget.onDelete == null
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          background: _dismissBg(),
                          confirmDismiss: widget.onDelete == null
                              ? null
                              : (dir) async => await _confirmDelete(context),
                          onDismissed: widget.onDelete == null
                              ? null
                              : (_) async {
                                  await widget.onDelete!(item);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Removed "${item.title}"')),
                                    );
                                  }
                                },
                          child: _ActivityTile(
                            item: item,
                            onOpen: widget.onOpen,
                          ),
                        );
                      },
                    )
                  : _empty(context),
            ),
          ), // RefreshIndicator wraps the scrollable list to enable pull-to-refresh gestures and status. [22]

        ],
      ),
    );
  }

  List<ActivityItem> _applyFilters(List<ActivityItem> items, Set<ActivityType> filters) {
    if (filters.isEmpty) return items;
    return items.where((e) => filters.contains(e.type)).toList(growable: false);
  }

  String _labelOf(ActivityType t) {
    switch (t) {
      case ActivityType.review:
        return 'Reviews';
      case ActivityType.favorite:
        return 'Favorites';
      case ActivityType.placeCreated:
        return 'Places';
      case ActivityType.comment:
        return 'Comments';
      case ActivityType.follow:
        return 'Follows';
      case ActivityType.ratingUpdate:
        return 'Ratings';
    }
  }

  Widget _dismissBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.red.shade400,
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  } // Dismissible supports “leave-behind” backgrounds for clear destructive cues during swipe gestures. [1][2]

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove item?'),
            content: const Text('This will remove the activity from the feed.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
            ],
          ),
        ) ??
        false;
  }

  Widget _footer(BuildContext context) {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No more activity')),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _empty(BuildContext context) {
    return widget.emptyPlaceholder ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No activity yet'),
          ),
        );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, this.onOpen});
  final ActivityItem item;
  final void Function(ActivityItem item)? onOpen;

  @override
  Widget build(BuildContext context) {
    final time = _timeAgo(item.timestamp);
    final icon = _iconOf(item.type);

    return ListTile(
      leading: _thumb(item.thumbnailUrl, icon),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item.subtitle}\n$time',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Open',
        icon: const Icon(Icons.open_in_new),
        onPressed: onOpen == null ? null : () => onOpen!(item),
      ),
      onTap: onOpen == null ? null : () => onOpen!(item),
    ); // ListTile offers accessible, aligned rows with leading icon/avatar, primary/secondary text, and trailing actions suitable for feeds. [21]
  }

  Widget _thumb(String? url, IconData fallback) {
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.black12,
        child: Icon(fallback, color: Colors.black54),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.black12,
    );
  }

  IconData _iconOf(ActivityType t) {
    switch (t) {
      case ActivityType.review:
        return Icons.rate_review_outlined;
      case ActivityType.favorite:
        return Icons.favorite_outline;
      case ActivityType.placeCreated:
        return Icons.place_outlined;
      case ActivityType.comment:
        return Icons.chat_bubble_outline;
      case ActivityType.follow:
        return Icons.person_add_alt_1_outlined;
      case ActivityType.ratingUpdate:
        return Icons.star_outline;
    }
  }

  String _timeAgo(DateTime dt) {
    // Lightweight relative time (“time ago”) formatter:
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  } // Relative time (“time ago”) presentation is a common UX pattern, and dedicated packages exist if needed for localization and precision. [20][16]
}
