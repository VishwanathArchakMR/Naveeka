// lib/features/navee_ai/presentation/widgets/chat_interface.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/navee_ai_api.dart';
import 'ai_response_cards.dart';
import 'ai_settings.dart';

class ChatInterface extends StatefulWidget {
  const ChatInterface({
    super.key,
    required this.api,
    required this.initialSettings,
    this.title = 'Navee AI',
  });

  final NaveeAiApi api;
  final AiSettings initialSettings;
  final String title;

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _focus = FocusNode();

  late AiSettings _settings;

  bool _sending = false;

  // Chat messages: role = 'user' | 'assistant', content can be String or parsed JSON (Map/List)
  final List<_Msg> _messages = <_Msg>[];

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final res = await AiSettingsSheet.show(context, initial: _settings);
    if (res != null) {
      setState(() => _settings = res);
    }
  } // Settings are presented with a shaped modal bottom sheet and return values via Navigator.pop for a clean, contextual flow. [21]

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(_Msg(role: 'user', content: text));
    });
    _safeScrollToBottom();

    final sys = _settings.jsonOnly
        ? 'You are Navee, a travel AI. Reply with STRICT JSON when asked, otherwise answer concisely.'
        : 'You are Navee, a helpful travel AI assistant.';
    final user = text;

    final api = NaveeAiApi(
      baseUrl: _settings.baseUrl,
      apiKey: _settings.apiKey,
      defaultModel: _settings.model,
    );

    final res = await api.chat(
      messages: [
        {'role': 'system', 'content': sys},
        ..._toHistoryForApi(),
        {'role': 'user', 'content': user},
      ],
      temperature: _settings.temperature,
      maxTokens: _settings.maxTokens,
    ); // The chat request uses a messages array with system/user roles per chat completion contracts, with model/temperature/max_tokens as JSON body. [22][23]

    res.fold(
      onSuccess: (data) {
        final content = _firstMessage(data) ?? '';
        final parsed = _settings.stripFences ? _tryParseJson(_stripFences(content)) : _tryParseJson(content);
        setState(() {
          _messages.add(_Msg(role: 'assistant', content: parsed ?? content));
          _sending = false;
        });
        _safeScrollToBottom();
      },
      onError: (e) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.safeMessage))); // SnackBars provide route-safe feedback for network/parse errors. [8]
      },
    );
  } // onSubmitted and a send button both call this method; onSubmitted is triggered when the user finalizes input in a TextField. [10][13]

  List<Map<String, String>> _toHistoryForApi() {
    // Send only the last 8 messages to keep tokens in check
    final recent = _messages.takeLast(8);
    return recent
        .map((m) => {
              'role': m.role,
              'content': m.content is String ? m.content as String : jsonEncode(m.content),
            })
        .toList(growable: false);
  }

  String? _firstMessage(Map<String, dynamic> data) {
    try {
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final msg = (choices.first as Map)['message'] as Map?;
      return msg?['content']?.toString();
    } catch (_) {
      return null;
    }
  }

  dynamic _tryParseJson(String s) {
    try {
      final t = s.trim();
      if ((t.startsWith('{') && t.endsWith('}')) || (t.startsWith('[') && t.endsWith(']'))) {
        return jsonDecode(t);
      }
    } catch (_) {}
    return null;
  }

  String _stripFences(String s) {
    final fence = RegExp(r'^``````$', multiLine: true);
    final m = fence.firstMatch(s.trim());
    if (m != null && m.groupCount >= 1) return m.group(1)!;
    return s;
  }

  void _safeScrollToBottom() {
    // Animate to maxScrollExtent after a frame so the list has built with new items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      _scrollCtrl.animateTo(
        max,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  } // animateTo/maxScrollExtent on a ScrollController is the standard way to reach the bottom; always check hasClients and wait a frame for accurate extents. [18][6]

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return const _TypingIndicator();
                  }
                  final m = _messages[index];
                  final isUser = m.role == 'user';

                  if (isUser) {
                    return _UserBubble(text: (m.content is String) ? m.content as String : jsonEncode(m.content));
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AiResponseCards(
                        items: m.content is List ? (m.content as List) : [m.content],
                        currency: '₹',
                      ),
                    );
                  }
                },
              ),
            ), // ListView.builder is the standard scrolling widget for chat lists; it efficiently builds children on demand. [8]

            // Composer
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + (bottomPad > 0 ? bottomPad - 8 : 0)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Ask travel, plans, ideas…',
                        prefixIcon: Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ), // TextField.onSubmitted is called when the user finishes editing (e.g., presses the action on the soft keyboard). [10][13]
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : () async {
                      await _send();
                      _inputCtrl.clear();
                      _focus.requestFocus();
                    },
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------
// UI helpers
// ----------------------

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Text(text, style: TextStyle(color: fg)),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.smart_toy_outlined),
      title: Row(
        children: [
          _Dot(),
          SizedBox(width: 4),
          _Dot(delay: Duration(milliseconds: 200)),
          SizedBox(width: 4),
          _Dot(delay: Duration(milliseconds: 400)),
        ],
      ),
      dense: true,
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({this.delay = Duration.zero});
  final Duration delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      ),
    );
  }
}

// ----------------------
// Model
// ----------------------

class _Msg {
  _Msg({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final dynamic content; // String | Map | List
}

extension<T> on List<T> {
  Iterable<T> takeLast(int n) => (length <= n) ? this : sublist(length - n);
}
