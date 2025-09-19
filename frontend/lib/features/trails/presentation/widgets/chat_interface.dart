// lib/features/trails/presentation/widgets/chat_interface.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Messaging providers and models (ensure these imports exist in your project)
import '../../../quick_actions/providers/messages_providers.dart';
// If you support location share in chat, also import your ShareLocation type:
// import '../../../messages/presentation/widgets/location_share.dart' show ShareLocationRequest, GeoPoint;

class ChatInterface extends ConsumerStatefulWidget {
  const ChatInterface({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    this.title = 'Trail chat',
    this.onClose,
    this.onPickAttachment, // Future<Uri?> Function()
    this.onShareTrail, // Future<void> Function()
    this.onShareLocation, // Future<void> Function()
  });

  final String conversationId;
  final String currentUserId;

  final String title;
  final VoidCallback? onClose;

  final Future<Uri?> Function()? onPickAttachment;
  final Future<void> Function()? onShareTrail;
  final Future<void> Function()? onShareLocation;

  @override
  ConsumerState<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends ConsumerState<ChatInterface> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Initial refresh to hydrate messages
    unawaited(ref.read(messagesActionsProvider).refreshThread(widget.conversationId));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final msg = _text.text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesActionsProvider).sendText(widget.conversationId, msg);
      _text.clear();
      // With reverse: true, newest is at "top" of reversed list; no need to jump if list is reversed correctly. [2][1]
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    if (widget.onPickAttachment == null) return;
    final uri = await widget.onPickAttachment!.call();
    if (uri == null) return;
    await ref.read(messagesActionsProvider).sendAttachment(widget.conversationId, uri);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = ref.watch(threadByIdProvider(widget.conversationId));
    final actions = ref.read(messagesActionsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => actions.refreshThread(widget.conversationId),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: cs.surfaceContainerLowest,
              child: _MessagesList(
                currentUserId: widget.currentUserId,
                items: store.items,
                loading: store.loading,
                controller: _scroll,
                onLoadMore: store.cursor == null
                    ? null
                    : () => actions.loadMoreThread(widget.conversationId),
              ),
            ),
          ),
          _InputBar(
            controller: _text,
            focusNode: _focus,
            busy: _sending,
            onSend: _sendText,
            onAttach: widget.onPickAttachment != null ? _attach : null,
            onShareTrail: widget.onShareTrail,
            onShareLocation: widget.onShareLocation,
          ),
        ],
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.currentUserId,
    required this.items,
    required this.loading,
    required this.controller,
    this.onLoadMore,
  });

  final String currentUserId;
  final List<MessageItem> items;
  final bool loading;
  final ScrollController controller;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    // Reverse mode keeps the latest message at the bottom with natural chat behavior. [2][5]
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && onLoadMore != null) {
          // In reverse list, reaching the bottom means at scrollExtent max in reverse axis; ListView handles this intuitively.
          final atTop = controller.position.pixels >= controller.position.maxScrollExtent - 24;
          if (atTop) onLoadMore!.call();
        }
        return false;
      },
      child: ListView.separated(
        controller: controller,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: items.length + (loading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (loading && index == items.length) {
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final m = items[index];
          final isMine = m.senderId == currentUserId;
          return _Bubble(message: m, isMine: isMine);
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final MessageItem message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isMine ? cs.primary.withValues(alpha: 0.15) : cs.surfaceContainerHigh.withValues(alpha: 1.0);
    final fg = isMine ? cs.onPrimaryContainer : cs.onSurface;

    final hasAttach = (message.attachmentUrls).isNotEmpty;
    final hasLoc = message.location != null;
    final hasText = (message.text ?? '').trim().isNotEmpty;

    return Row(
      mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasText)
                  Text(
                    message.text!.trim(),
                    style: TextStyle(color: fg),
                  ),
                if (hasAttach) ...[
                  if (hasText) const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.attachmentUrls
                        .map((u) => Container(
                              width: 120,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 1.0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.attach_file, color: cs.onSurfaceVariant),
                            ))
                        .toList(growable: false),
                  ),
                ],
                if (hasLoc) ...[
                  if (hasText || hasAttach) const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${message.location!.lat.toStringAsFixed(5)}, ${message.location!.lng.toStringAsFixed(5)}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
    this.onAttach,
    this.onShareTrail,
    this.onShareLocation,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;

  final Future<void> Function() onSend;
  final Future<void> Function()? onAttach;
  final Future<void> Function()? onShareTrail;
  final Future<void> Function()? onShareLocation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            if (onAttach != null)
              IconButton(
                tooltip: 'Attach',
                onPressed: busy ? null : onAttach,
                icon: const Icon(Icons.attach_file),
              ),
            if (onShareTrail != null)
              IconButton(
                tooltip: 'Share trail',
                onPressed: busy ? null : onShareTrail,
                icon: const Icon(Icons.route_outlined),
              ),
            if (onShareLocation != null)
              IconButton(
                tooltip: 'Share location',
                onPressed: busy ? null : onShareLocation,
                icon: const Icon(Icons.my_location),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Message',
                  filled: true,
                  fillColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onSend,
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: const Text('Send'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary.withValues(alpha: 1.0),
                foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
