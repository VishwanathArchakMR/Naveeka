// lib/features/quick_actions/presentation/messages/widgets/recent_chats.dart

import 'package:flutter/material.dart';

import 'chat_preview.dart';

/// A paginated, refreshable list of recent chat conversations.
/// - Uses ListView.separated for consistent dividers
/// - Adaptive RefreshIndicator
/// - Infinite scroll near the end
/// - Integrates ChatPreview entries with unread badges
class RecentChats extends StatefulWidget {
  const RecentChats({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpenChat, // void Function(ChatPreviewData)
    this.sectionTitle = 'Recent chats',
    this.emptyPlaceholder,
  });

  final List<ChatPreviewData> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(ChatPreviewData data)? onOpenChat;

  final String sectionTitle;
  final Widget? emptyPlaceholder;

  @override
  State<RecentChats> createState() => _RecentChatsState();
}

class _RecentChatsState extends State<RecentChats> {
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
      widget.onLoadMore!().whenComplete(() => _loadRequested = false);
    }
  } // Infinite pagination triggers near the end of the list, which pairs well with builder-style lists. [11][1]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAny = widget.items.isNotEmpty;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
                          final chat = widget.items[i];
                          return ChatPreview(
                            data: chat,
                            onTap: widget.onOpenChat == null ? null : () => widget.onOpenChat!(chat),
                          );
                        },
                      )
                    : _empty(),
              ),
            ), // RefreshIndicator.adaptive provides platform-appropriate pull-to-refresh UX across iOS/Android. [7][13]
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
        child: Center(child: Text('No more chats')),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _empty() {
    return widget.emptyPlaceholder ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No conversations yet'),
          ),
        );
  }
}
