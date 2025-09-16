// lib/features/trails/presentation/widgets/messages_inbox.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../messages/providers/messages_providers.dart';

class MessagesInbox extends ConsumerStatefulWidget {
  const MessagesInbox({
    super.key,
    this.title = 'Messages',
    this.onOpenConversation, // void Function(ConversationSummary c)
  });

  final String title;
  final void Function(ConversationSummary c)? onOpenConversation;

  @override
  ConsumerState<MessagesInbox> createState() => _MessagesInboxState();
}

class _MessagesInboxState extends ConsumerState<MessagesInbox> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prime the list on first build
    final actions = ref.read(messagesActionsProvider);
    actions.initConversations(const ConversationQuery()); // initial load
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(messagesActionsProvider).refreshConversations();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(conversationsControllerProvider);
    final actions = ref.read(messagesActionsProvider);

    final items = state.valueOrNull?.items ?? const <ConversationSummary>[];
    final loading = state.isLoading;
    final error = state.hasError ? 'Failed to load messages' : null;

    // Client-side search filter
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? items
        : items.where((c) {
            final t = c.title.toLowerCase();
            final last = (c.lastMessageText ?? '').toLowerCase();
            return t.contains(query) || last.contains(query);
          }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // Search bar (Material 3 SearchBar alternative to AppBar search)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SearchBar(
                  controller: _search,
                  hintText: 'Search conversations',
                  onChanged: (_) => setState(() {}),
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            if (loading && items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),

            if (!loading && error != null && items.isEmpty)
              SliverToBoxAdapter(
                child: _ErrorState(message: error, onRetry: _refresh),
              ),

            if (!loading && error == null && filtered.isEmpty && items.isNotEmpty)
              const SliverToBoxAdapter(
                child: _EmptyFilterState(),
              ),

            if (filtered.isNotEmpty)
              SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  return _InboxTile(
                    item: c,
                    onOpen: widget.onOpenConversation == null ? null : () => widget.onOpenConversation!(c),
                    onTogglePin: (next) => actions.setPinned(c.id, next),
                    onToggleMute: (next) => actions.setMuted(c.id, next),
                    onMarkRead: () => actions.markRead(c.id, c.lastMessageText ?? ''),
                  );
                },
              ),

            if (state.valueOrNull?.cursor != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => actions.loadMoreConversations(),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({
    required this.item,
    this.onOpen,
    this.onTogglePin,
    this.onToggleMute,
    this.onMarkRead,
  });

  final ConversationSummary item;
  final VoidCallback? onOpen;
  final Future<bool> Function(bool next)? onTogglePin;
  final Future<bool> Function(bool next)? onToggleMute;
  final Future<void> Function()? onMarkRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Widget tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: _Avatar(avatars: item.participantAvatars),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (item.isPinned)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.push_pin, size: 16, color: cs.onSurfaceVariant),
            ),
          if (item.isMuted)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.notifications_off, size: 16, color: cs.onSurfaceVariant),
            ),
        ],
      ),
      subtitle: Text(
        (item.lastMessageText ?? 'No messages yet').trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: item.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.unreadCount.toString(),
                style: TextStyle(color: cs.onPrimary.withValues(alpha: 1.0), fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
      onTap: onOpen,
      onLongPress: onMarkRead,
    );

    // Swipe actions using Dismissible with confirm handlers to avoid removing the tile. [1][2]
    return Dismissible(
      key: ValueKey('conv-${item.id}'),
      background: _SwipeBg(
        alignment: Alignment.centerLeft,
        color: cs.primary.withValues(alpha: 0.14),
        icon: Icons.push_pin,
        label: item.isPinned ? 'Unpin' : 'Pin',
      ),
      secondaryBackground: _SwipeBg(
        alignment: Alignment.centerRight,
        color: cs.surfaceTint.withValues(alpha: 0.14),
        icon: item.isMuted ? Icons.notifications_active : Icons.notifications_off,
        label: item.isMuted ? 'Unmute' : 'Mute',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && onTogglePin != null) {
          await onTogglePin!(!item.isPinned);
        } else if (direction == DismissDirection.endToStart && onToggleMute != null) {
          await onToggleMute!(!item.isMuted);
        }
        return false; // keep item in the list; action performed already
      },
      child: tile,
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: cs.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
          ] else ...[
            Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(icon, color: cs.onSurface),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatars});
  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Simple placeholder or stacked avatars. Replace with real images if available.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.chat_bubble_outline, color: cs.primary),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 28),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, color: cs.onSurfaceVariant, size: 36),
          const SizedBox(height: 8),
          Text('No matches', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Try a different keyword', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
