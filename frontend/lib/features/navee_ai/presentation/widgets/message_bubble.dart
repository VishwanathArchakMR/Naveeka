// lib/features/navee_ai/presentation/widgets/message_bubble.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';

enum BubbleRole { user, assistant, system }

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content, // String | Map | List
    this.timestamp, // DateTime
    this.error, // String?
    this.onRetry,
    this.actions = const <BubbleAction>[],
    this.maxWidth = 540,
  });

  final BubbleRole role;
  final dynamic content;
  final DateTime? timestamp;
  final String? error;
  final VoidCallback? onRetry;
  final List<BubbleAction> actions;
  final double maxWidth;

  bool get _isUser => role == BubbleRole.user;
  bool get _isSystem => role == BubbleRole.system;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;
    final fg = _isUser ? theme.colorScheme.onPrimaryContainer : Colors.black87;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(_isUser ? 12 : 4),
            topRight: Radius.circular(_isUser ? 4 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (_isSystem)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'System',
                    style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ),
              _ContentView(content: content, fg: fg),
              const SizedBox(height: 6),
              _MetaRow(
                fg: fg,
                timestamp: timestamp,
                error: error,
                onRetry: onRetry,
                onCopy: () => _copy(context, content),
                actions: actions,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            _Avatar(role: role),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (_isUser) ...[
            const SizedBox(width: 8),
            _Avatar(role: role),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, dynamic value) async {
    final text = _contentAsString(value);
    final messenger = ScaffoldMessenger.maybeOf(context); // capture before await
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(const SnackBar(content: Text('Copied')));
  }

  String _contentAsString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.role});
  final BubbleRole role;

  @override
  Widget build(BuildContext context) {
    final icon = switch (role) {
      BubbleRole.user => Icons.person_outline,
      BubbleRole.assistant => Icons.smart_toy_outlined,
      BubbleRole.system => Icons.info_outline,
    };
    return CircleAvatar(
      radius: 14,
      child: Icon(icon, size: 16),
    );
  }
}

class _ContentView extends StatelessWidget {
  const _ContentView({required this.content, required this.fg});

  final dynamic content;
  final Color fg;

  bool _looksJsonString(String s) {
    final t = s.trim();
    return (t.startsWith('{') && t.endsWith('}')) || (t.startsWith('[') && t.endsWith(']'));
  }

  @override
  Widget build(BuildContext context) {
    if (content == null) {
      return const SizedBox.shrink();
    }

    // Map/List -> pretty JSON code block
    if (content is Map || content is List) {
      final code = const JsonEncoder.withIndent('  ').convert(content);
      return _CodeBlock(code: code, fg: fg);
    }

    // String: try JSON, else Markdown with selection
    if (content is String) {
      final s = content as String;
      if (_looksJsonString(s)) {
        try {
          final parsed = jsonDecode(s);
          final code = const JsonEncoder.withIndent('  ').convert(parsed);
          return _CodeBlock(code: code, fg: fg);
        } catch (_) {
          // fall through to markdown
        }
      }
      return SelectableText(
        s,
        style: TextStyle(color: fg),
      ); // Use SelectableText when markdown package is unavailable.
    }

    // Fallback
    return SelectableText(
      content.toString(),
      style: TextStyle(color: fg),
    ); // SelectableText allows users to highlight/copy text inside the bubble for improved interaction and accessibility. [1][11]
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.fg});
  final String code;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black.withValues(alpha: 0.06);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          color: fg,
          fontSize: 13,
        ),
      ),
    ); // Code blocks render in a monospaced SelectableText, improving readability and enabling copy operations directly. [1][3]
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.fg,
    required this.timestamp,
    required this.error,
    required this.onRetry,
    required this.onCopy,
    required this.actions,
  });

  final Color fg;
  final DateTime? timestamp;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback onCopy;
  final List<BubbleAction> actions;

  @override
  Widget build(BuildContext context) {
    final ts = timestamp != null ? _fmtTime(timestamp!) : null;
    final muted = fg.withValues(alpha: 0.7);

    return Row(
      children: [
        if (ts != null) Text(ts, style: TextStyle(color: muted, fontSize: 11)),
        const Spacer(),
        Tooltip(
          message: 'Copy',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_all_outlined, size: 16),
            color: muted,
            onPressed: onCopy,
          ),
        ), // Tooltip explains control intent for accessibility and hover support across platforms. [13][7]
        if (error != null && onRetry != null)
          Tooltip(
            message: error!,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: OutlinedButton.icon(
              onPressed: a.onPressed,
              icon: Icon(a.icon, size: 16),
              label: Text(a.label),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }
}

class BubbleAction {
  const BubbleAction({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
