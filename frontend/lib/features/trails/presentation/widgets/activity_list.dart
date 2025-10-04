// lib/features/trails/presentation/widgets/activity_list.dart

import 'package:flutter/material.dart';

@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type, // like | comment | follow | mention | achievement
    required this.userName,
    required this.timestamp, // DateTime
    this.message,
    this.previewUrl, // image of the trail post
    this.userAvatarUrl,
  });

  final String id;
  final String type;
  final String userName;
  final DateTime timestamp;
  final String? message;
  final String? previewUrl;
  final String? userAvatarUrl;
}

class ActivityList extends StatelessWidget {
  const ActivityList({
    super.key,
    required this.items,
    this.onOpenUser, // void Function(String userName)
    this.onOpenPreview, // void Function(String itemId)
    this.onLoadMore, // Future<void> Function()
    this.hasMore = false,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 90),
  });

  final List<ActivityItem> items;
  final ValueChanged<String>? onOpenUser;
  final ValueChanged<String>? onOpenPreview;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onLoadMore == null || !hasMore) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
          onLoadMore!.call();
        }
        return false;
      },
      child: ListView.separated(
        padding: padding,
        itemCount: items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final it = items[i];
          return _ActivityCard(
            item: it,
            onOpenUser: onOpenUser,
            onOpenPreview: onOpenPreview,
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({
    required this.item,
    this.onOpenUser,
    this.onOpenPreview,
  });

  final ActivityItem item;
  final ValueChanged<String>? onOpenUser;
  final ValueChanged<String>? onOpenPreview;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String _verb(String type) {
    switch (type) {
      case 'like':
        return 'liked your trail';
      case 'comment':
        return 'commented on your trail';
      case 'follow':
        return 'started following you';
      case 'mention':
        return 'mentioned you';
      case 'achievement':
        return 'achievement unlocked';
      default:
        return 'activity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final it = widget.item;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          leading: _Avatar(url: it.userAvatarUrl),
          title: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => widget.onOpenUser?.call(it.userName),
                    child: Text(
                      it.userName,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: ' ${_verb(it.type)}',
                  style: TextStyle(color: cs.onSurface),
                ),
                if ((it.message ?? '').isNotEmpty)
                  TextSpan(
                    text: ' — ${it.message}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          subtitle: Text(
            _timeAgo(it.timestamp),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          trailing: _PreviewThumb(
            url: it.previewUrl,
            onTap: () => widget.onOpenPreview?.call(it.id),
          ),
          onTap: () => widget.onOpenPreview?.call(it.id),
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = diff.inDays ~/ 7;
    return '${weeks}w ago';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: cs.secondaryContainer,
      child: (url == null || url!.isEmpty)
          ? Icon(Icons.person, color: cs.onSecondaryContainer)
          : null,
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({this.url, this.onTap});
  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceTint.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.landscape_outlined, color: cs.onSurfaceVariant, size: 22),
      ),
    );
  }
}
