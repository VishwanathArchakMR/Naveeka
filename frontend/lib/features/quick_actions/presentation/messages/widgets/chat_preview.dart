// lib/features/quick_actions/presentation/messages/widgets/chat_preview.dart

import 'package:flutter/material.dart';

/// Lightweight model for conversation preview rows.
class ChatPreviewData {
  const ChatPreviewData({
    required this.id,
    required this.title, // conversation title or other participant(s)
    required this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSender,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isTyping = false,
    this.participantAvatars = const <String>[],
    this.hasAttachments = false,
  });

  final String id;
  final String title;
  final DateTime lastMessageAt;

  final String? lastMessageText;
  final String? lastMessageSender;
  final int unreadCount;

  final bool isMuted;
  final bool isPinned;
  final bool isTyping;

  final List<String> participantAvatars; // up to 3 shown
  final bool hasAttachments;
}

/// A Material list preview of a chat/conversation suitable for inbox screens.
/// - Avatar or stacked avatars for group chats
/// - Unread Badge.count and pinned/muted icons
/// - Typing indicator via AnimatedSwitcher
/// - Last message snippet with attachment icon and relative time
/// - Uses withValues() instead of deprecated withOpacity()
class ChatPreview extends StatelessWidget {
  const ChatPreview({
    super.key,
    required this.data,
    this.onTap,
    this.onLongPress,
  });

  final ChatPreviewData data;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitleStyle = TextStyle(color: cs.onSurfaceVariant);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _AvatarStack(urls: data.participantAvatars, unread: data.unreadCount > 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (data.isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.push_pin, size: 16),
            ),
          if (data.isMuted)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.volume_off, size: 16),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          // Typing indicator or last message
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: data.isTyping
                  ? _TypingPill(key: const ValueKey('typing'))
                  : _Snippet(
                      key: const ValueKey('snippet'),
                      sender: data.lastMessageSender,
                      text: data.lastMessageText,
                      hasAttachments: data.hasAttachments,
                      style: subtitleStyle,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(_timeAgo(data.lastMessageAt), style: subtitleStyle),
        ],
      ),
      trailing: data.unreadCount > 0
          ? Badge.count(
              count: data.unreadCount.clamp(0, 9999),
              backgroundColor: cs.primary,
              textColor: cs.onPrimary,
            )
          : const SizedBox(width: 12),
      onTap: onTap,
      onLongPress: onLongPress,
    ); // ListTile is the Material pattern for list rows and supports leading/trailing content and dense text layouts. [1][2]
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

class _TypingPill extends StatelessWidget {
  const _TypingPill({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delayMs: 0, color: cs.primary),
          const SizedBox(width: 2),
          _Dot(delayMs: 200, color: cs.primary),
          const SizedBox(width: 2),
          _Dot(delayMs: 400, color: cs.primary),
          const SizedBox(width: 6),
          Text('Typing…', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    ); // Animated typing dots make the state change obvious while staying compact. [13][18]
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delayMs, required this.color});
  final int delayMs;
  final Color color;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  late final Animation<double> _a = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    ); // AnimatedSwitcher and simple transitions provide smooth micro-interactions per Material motion guidance. [13][18]
  }
}

class _Snippet extends StatelessWidget {
  const _Snippet({
    super.key,
    required this.sender,
    required this.text,
    required this.hasAttachments,
    required this.style,
  });

  final String? sender;
  final String? text;
  final bool hasAttachments;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final prefix = (sender ?? '').trim().isEmpty ? '' : '${sender!.trim()}: ';
    final body = (text ?? '').trim().isEmpty ? 'Attachment' : text!.trim();
    return Row(
      children: [
        if (hasAttachments) const Icon(Icons.attachment, size: 14),
        if (hasAttachments) const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$prefix$body',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    ); // The subtitle shows sender and a trimmed snippet, with an attachment icon when present. [1][2]
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.urls, required this.unread});
  final List<String> urls;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHigh.withValues(alpha: 1.0);
    final border = Border.all(color: bg, width: 2);

    final children = <Widget>[];
    final maxShown = urls.length >= 2 ? 2 : 1;
    for (var i = 0; i < maxShown; i++) {
      final url = urls[i];
      final left = i * 16.0;
      children.add(Positioned(
        left: left,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black12,
          backgroundImage: (url.trim().isNotEmpty) ? NetworkImage(url) : null,
          child: (url.trim().isEmpty) ? const Icon(Icons.person, size: 18, color: Colors.black38) : null,
        ),
      ));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: 36 + (urls.length >= 2 ? 16 : 0), height: 36),
        ...children.map((w) => Container(decoration: BoxDecoration(shape: BoxShape.circle, border: border), child: w)),
        if (unread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: bg, width: 2),
              ),
            ),
          ),
      ],
    ); // CircleAvatar is standard for user images, and a small dot indicates unread state without extra text. [1][2]
  }
}
