// lib/features/quick_actions/presentation/planning/widgets/trip_groups_list.dart

import 'package:flutter/material.dart';

/// Lightweight member avatar info.
class GroupMember {
  const GroupMember({required this.id, required this.name, this.avatarUrl, this.isOnline = false});

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
}

/// Single trip group row model.
class TripGroupItem {
  const TripGroupItem({
    required this.id,
    required this.title,
    required this.members,
    required this.lastActivityAt,
    this.destination,
    this.dateRange,
    this.unreadCount = 0,
    this.isOwner = false,
    this.isActive = true,
    this.planSummary,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final List<GroupMember> members;
  final DateTime lastActivityAt;

  final String? destination;
  final DateTimeRange? dateRange;

  final int unreadCount;
  final bool isOwner;
  final bool isActive;

  final String? planSummary;
  final String? coverImageUrl;
}

/// A refreshable, paginated list of trip groups with quick actions.
class TripGroupsList extends StatefulWidget {
  const TripGroupsList({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenGroup,
    this.onInvite,
    this.onLeave,
    this.onNewGroup,
    this.sectionTitle = 'Trip groups',
    this.height = 560,
  });

  final List<TripGroupItem> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(TripGroupItem item)? onOpenGroup;
  final Future<void> Function(TripGroupItem item)? onInvite;
  final Future<void> Function(TripGroupItem item)? onLeave;

  final VoidCallback? onNewGroup;

  final String sectionTitle;
  final double height;

  @override
  State<TripGroupsList> createState() => _TripGroupsListState();
}

class _TripGroupsListState extends State<TripGroupsList> {
  final _scroll = ScrollController();
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
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
  } // Infinite pagination triggers near the end of the list with builder-style lists. [1][4]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAny = widget.items.isNotEmpty;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: widget.height,
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
                  if (widget.onNewGroup != null)
                    FilledButton.icon(
                      onPressed: widget.onNewGroup,
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('New'),
                    ),
                  const SizedBox(width: 8),
                  if (widget.loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: widget.onRefresh,
                child: hasAny
                    ? ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: widget.items.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          if (i == widget.items.length) return _footer();
                          final it = widget.items[i];
                          return _GroupTile(
                            item: it,
                            onOpen: widget.onOpenGroup,
                            onInvite: widget.onInvite,
                            onLeave: widget.onLeave,
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No groups yet', style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      ),
              ),
            ), // RefreshIndicator.adaptive gives platform-appropriate pull-to-refresh UX. [3][5]
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
        child: Center(child: Text('No more groups')),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.item,
    this.onOpen,
    this.onInvite,
    this.onLeave,
  });

  final TripGroupItem item;
  final void Function(TripGroupItem item)? onOpen;
  final Future<void> Function(TripGroupItem item)? onInvite;
  final Future<void> Function(TripGroupItem item)? onLeave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = item.title.trim().isEmpty ? 'Trip group' : item.title.trim();
    final subtitle = _subtitleLine(item);
    final chips = _chips(context, item);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _CoverOrAvatars(item: item),
      title: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (item.unreadCount > 0)
            Badge.count(
              count: item.unreadCount.clamp(0, 9999),
              backgroundColor: cs.primary,
              textColor: cs.onPrimary,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
          if ((item.planSummary ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.planSummary!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
      trailing: _ActionsMenu(
        isOwner: item.isOwner,
        onInvite: onInvite == null ? null : () => onInvite!(item),
        onLeave: onLeave == null ? null : () => onLeave!(item),
      ),
      onTap: onOpen == null ? null : () => onOpen!(item),
    ); // ListTile with Badge.count is a compact, accessible pattern for rows with unread counts and trailing actions. [6][2]
  }

  String _subtitleLine(TripGroupItem it) {
    final parts = <String>[];
    if (it.destination != null && it.destination!.trim().isNotEmpty) parts.add(it.destination!.trim());
    if (it.dateRange != null) {
      String d(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      parts.add('${d(it.dateRange!.start)} → ${d(it.dateRange!.end)}');
    }
    return parts.join(' · ');
  }

  List<Widget> _chips(BuildContext context, TripGroupItem it) {
    final cs = Theme.of(context).colorScheme;
    final list = <Widget>[];

    if (it.isActive) {
      list.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text('Active', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
      ));
    } else {
      list.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh.withValues(alpha: 1.0), borderRadius: BorderRadius.circular(999)),
        child: const Text('Archived', style: TextStyle(fontWeight: FontWeight.w700)),
      ));
    }

    final ago = _timeAgo(it.lastActivityAt);
    list.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh.withValues(alpha: 1.0), borderRadius: BorderRadius.circular(999)),
      child: Text('Updated $ago', style: const TextStyle(fontWeight: FontWeight.w700)),
    ));

    if (it.isOwner) {
      list.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh.withValues(alpha: 1.0), borderRadius: BorderRadius.circular(999)),
        child: const Text('Owner', style: TextStyle(fontWeight: FontWeight.w700)),
      ));
    }
    return list;
  }

  String _timeAgo(DateTime at) {
    final now = DateTime.now();
    final d = now.difference(at);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }
}

class _CoverOrAvatars extends StatelessWidget {
  const _CoverOrAvatars({required this.item});
  final TripGroupItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHigh.withValues(alpha: 1.0);

    if ((item.coverImageUrl ?? '').trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.coverImageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(bg),
        ),
      );
    }

    // Fallback: stacked avatars
    final maxShown = item.members.length >= 2 ? 2 : 1;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(maxShown, (i) {
          final m = item.members[i];
          final left = i * 16.0;
          return Positioned(
            left: left,
            top: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black12,
                    backgroundImage: (m.avatarUrl != null && m.avatarUrl!.trim().isNotEmpty) ? NetworkImage(m.avatarUrl!) : null,
                    child: (m.avatarUrl == null || m.avatarUrl!.trim().isEmpty)
                        ? Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 12))
                        : null,
                  ),
                ),
                if (m.isOnline)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _fallback(Color bg) {
    return Container(
      width: 56,
      height: 56,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo, color: Colors.black38),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.isOwner, this.onInvite, this.onLeave});

  final bool isOwner;
  final VoidCallback? onInvite;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          if (onInvite != null)
            const PopupMenuItem<String>(
              value: 'invite',
              child: ListTile(
                leading: Icon(Icons.person_add_alt_1),
                title: Text('Invite'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (onLeave != null && !isOwner)
            const PopupMenuItem<String>(
              value: 'leave',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Leave group'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ];
      },
      onSelected: (v) {
        if (v == 'invite' && onInvite != null) onInvite!();
        if (v == 'leave' && onLeave != null) onLeave!();
      },
    );
  }
}
