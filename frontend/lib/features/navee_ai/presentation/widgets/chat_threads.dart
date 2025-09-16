// lib/features/navee_ai/presentation/widgets/chat_threads.dart

import 'package:flutter/material.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    this.preview,
    required this.updatedAt,
    this.pinned = false,
    this.unread = 0,
    this.messageCount = 0,
  });

  final String id;
  final String title;
  final String? preview;
  final DateTime updatedAt;
  final bool pinned;
  final int unread;
  final int messageCount;

  ChatThread copyWith({
    String? id,
    String? title,
    String? preview,
    DateTime? updatedAt,
    bool? pinned,
    int? unread,
    int? messageCount,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      unread: unread ?? this.unread,
      messageCount: messageCount ?? this.messageCount,
    );
    }
}

/// A screen that lists AI chat threads with:
/// - Search
/// - Swipe to delete (Dismissible)
/// - Reorder (ReorderableListView) when not filtering
/// - Per-item menu: Pin/Unpin, Rename, Duplicate, Delete
/// Delegates persistence to the provided callbacks to keep the UI decoupled.
class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({
    super.key,
    required this.threads,
    required this.onOpen,
    required this.onCreateNew,
    required this.onDelete,
    required this.onRename,
    required this.onTogglePin,
    required this.onReorder,
    this.onDuplicate,
    this.title = 'Conversations',
  });

  final List<ChatThread> threads;

  final void Function(ChatThread thread) onOpen;
  final VoidCallback onCreateNew;
  final void Function(ChatThread thread) onDelete;
  final void Function(ChatThread thread, String newTitle) onRename;
  final void Function(ChatThread thread, bool pinned) onTogglePin;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(ChatThread thread)? onDuplicate;

  final String title;

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChatThread> get _sorted {
    final list = [...widget.threads];
    // Pinned first, then by updatedAt desc
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<void> _confirmDelete(ChatThread t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('This will permanently delete “${t.title}”.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).maybePop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).maybePop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) widget.onDelete(t);
  }

  Future<void> _promptRename(ChatThread t) async {
    final ctrl = TextEditingController(text: t.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New title'),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(ctx).maybePop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).maybePop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).maybePop(ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != t.title) {
      widget.onRename(t, newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final items = _sorted.where((t) {
      if (query.isEmpty) return true;
      final title = t.title.toLowerCase();
      final prev = (t.preview ?? '').toLowerCase();
      return title.contains(query) || prev.contains(query);
    }).toList(growable: false);

    final searching = query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: widget.onCreateNew,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search conversations',
                isDense: true,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const _EmptyState()
            : searching
                ? _SearchList(
                    items: items,
                    onOpen: widget.onOpen,
                    onDelete: _confirmDelete,
                    onRename: _promptRename,
                    onTogglePin: widget.onTogglePin,
                    onDuplicate: widget.onDuplicate,
                  )
                : _ReorderableList(
                    items: items,
                    onOpen: widget.onOpen,
                    onDelete: _confirmDelete,
                    onRename: _promptRename,
                    onTogglePin: widget.onTogglePin,
                    onDuplicate: widget.onDuplicate,
                    onReorder: widget.onReorder,
                  ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            const Text('No conversations yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Start a new chat to plan trips, ideas, or itineraries', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _SearchList extends StatelessWidget {
  const _SearchList({
    required this.items,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onTogglePin,
    required this.onDuplicate,
  });

  final List<ChatThread> items;
  final void Function(ChatThread thread) onOpen;
  final Future<void> Function(ChatThread thread) onDelete;
  final Future<void> Function(ChatThread thread) onRename;
  final void Function(ChatThread thread, bool pinned) onTogglePin;
  final void Function(ChatThread thread)? onDuplicate;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = items[i];
        return _DismissibleTile(
          keyValue: t.id,
          backgroundColor: Colors.red.shade50,
          backgroundIcon: Icons.delete_outline,
          child: _ThreadTile(
            thread: t,
            onOpen: onOpen,
            onRename: onRename,
            onTogglePin: onTogglePin,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
          ),
          onConfirm: () async {
            await onDelete(t);
            return true;
          },
        );
      },
    );
  }
}

class _ReorderableList extends StatelessWidget {
  const _ReorderableList({
    required this.items,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onTogglePin,
    required this.onDuplicate,
    required this.onReorder,
  });

  final List<ChatThread> items;
  final void Function(ChatThread thread) onOpen;
  final Future<void> Function(ChatThread thread) onDelete;
  final Future<void> Function(ChatThread thread) onRename;
  final void Function(ChatThread thread, bool pinned) onTogglePin;
  final void Function(ChatThread thread)? onDuplicate;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        // Flutter moves the item to newIndex - (oldIndex < newIndex ? 1 : 0)
        if (newIndex > oldIndex) newIndex -= 1;
        onReorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          child: child,
        );
      },
      itemBuilder: (context, i) {
        final t = items[i];
        return _DismissibleTile(
          keyValue: t.id,
          backgroundColor: Colors.red.shade50,
          backgroundIcon: Icons.delete_outline,
          child: _ThreadTile(
            key: ValueKey('tile-${t.id}'),
            thread: t,
            onOpen: onOpen,
            onRename: onRename,
            onTogglePin: onTogglePin,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
            showDragHandle: true,
          ),
          onConfirm: () async {
            await onDelete(t);
            return true;
          },
        );
      },
    );
  }
}

class _DismissibleTile extends StatelessWidget {
  const _DismissibleTile({
    required this.keyValue,
    required this.child,
    required this.onConfirm,
    required this.backgroundColor,
    required this.backgroundIcon,
  });

  final String keyValue;
  final Widget child;
  final Future<bool> Function() onConfirm;
  final Color backgroundColor;
  final IconData backgroundIcon;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('dismiss-$keyValue'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: Icon(backgroundIcon, color: Colors.red.shade700),
      ),
      confirmDismiss: (_) => onConfirm(),
      child: child,
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    super.key,
    required this.thread,
    required this.onOpen,
    required this.onRename,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDuplicate,
    this.showDragHandle = false,
  });

  final ChatThread thread;
  final void Function(ChatThread thread) onOpen;
  final Future<void> Function(ChatThread thread) onRename;
  final void Function(ChatThread thread, bool pinned) onTogglePin;
  final Future<void> Function(ChatThread thread) onDelete;
  final void Function(ChatThread thread)? onDuplicate;

  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final title = thread.title.isEmpty ? 'Untitled' : thread.title;
    final subtitle = [
      if (thread.pinned) 'Pinned',
      if (thread.preview != null && thread.preview!.trim().isNotEmpty) thread.preview!.trim(),
      '${thread.messageCount} msg${thread.messageCount == 1 ? '' : 's'} • ${_ago(thread.updatedAt)}',
    ].join(' • ');

    return Container(
      key: ValueKey('item-${thread.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(thread.pinned ? Icons.push_pin : Icons.forum_outlined),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thread.unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(999)),
                child: Text('${thread.unread}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.blue)),
              ),
            if (showDragHandle)
              const SizedBox(width: 8),
            if (showDragHandle)
              const ReorderableDragStartListener(
                index: 0, // not used by external ReorderableListView.builder; kept for semantics
                child: Icon(Icons.drag_indicator, color: Colors.black38),
              ),
            const SizedBox(width: 4),
            _Menu(
              thread: thread,
              onRename: onRename,
              onTogglePin: onTogglePin,
              onDelete: onDelete,
              onDuplicate: onDuplicate,
            ),
          ],
        ),
        onTap: () => onOpen(thread),
      ),
    );
  }

  String _ago(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.thread,
    required this.onRename,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDuplicate,
  });

  final ChatThread thread;
  final Future<void> Function(ChatThread thread) onRename;
  final void Function(ChatThread thread, bool pinned) onTogglePin;
  final Future<void> Function(ChatThread thread) onDelete;
  final void Function(ChatThread thread)? onDuplicate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'open':
            // Handled by onTap at tile level; keep for completeness
            break;
          case 'rename':
            await onRename(thread);
            break;
          case 'pin':
            onTogglePin(thread, !thread.pinned);
            break;
          case 'duplicate':
            onDuplicate?.call(thread);
            break;
          case 'delete':
            await onDelete(thread);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'pin', child: Text(thread.pinned ? 'Unpin' : 'Pin')),
        if (onDuplicate != null) const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}
