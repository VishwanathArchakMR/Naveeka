// lib/features/navee_ai/presentation/widgets/collaborative_mode.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Lightweight, room-based collaborative mode:
/// - Presence: who is in the room
/// - Shared note: text synced across participants (optimistic)
/// - Chat: simple message feed
/// - Invite: bottom sheet with copyable link
///
/// Backend message protocol (JSON):
/// { "type":"join","user":{"id":"u1","name":"A"} }
/// { "type":"leave","userId":"u1" }
/// { "type":"presence","users":[{"id":"u1","name":"A"}] }
/// { "type":"edit","note":"..." }       // server echo
/// { "type":"message","user":{"id":"u1","name":"A"},"text":"Hi" }
///
/// Client sends (JSON):
/// { "type":"edit","note":"..." }       // debounce recommended
/// { "type":"message","text":"..." }
/// { "type":"ping" }
class CollaborativeMode extends StatefulWidget {
  const CollaborativeMode({
    super.key,
    required this.roomId,
    required this.wsBaseUrl, // e.g., wss://collab.example.com/ws
    required this.currentUserId,
    required this.currentUserName,
    this.inviteLink, // optional deep link to share
    this.headerTitle = 'Collaborative planning',
  });

  final String roomId;
  final String wsBaseUrl;
  final String currentUserId;
  final String currentUserName;
  final String? inviteLink;
  final String headerTitle;

  @override
  State<CollaborativeMode> createState() => _CollaborativeModeState();
}

class _CollaborativeModeState extends State<CollaborativeMode> {
  late CollabSocket _socket;

  // Shared state
  final _noteCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  final _presence = <_User>[];
  final _messages = <_Msg>[];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _socket = CollabSocket(
      wsUrl: '${widget.wsBaseUrl.replaceAll(RegExp(r"/$"), "")}/${Uri.encodeComponent(widget.roomId)}',
      onEvent: _handleEvent,
    );
    _socket.connect();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _noteCtrl.dispose();
    _msgCtrl.dispose();
    _socket.dispose();
    super.dispose();
  }

  void _handleEvent(Map<String, dynamic> e) {
    final t = (e['type'] ?? '').toString();
    if (t == 'presence') {
      final list = (e['users'] as List? ?? const []).map((u) => _User.fromJson(u)).toList();
      setState(() {
        _presence
          ..clear()
          ..addAll(list);
      });
    } else if (t == 'join') {
      final u = _User.fromJson(e['user']);
      setState(() {
        if (_presence.indexWhere((x) => x.id == u.id) == -1) _presence.add(u);
        _messages.add(_Msg.system('${u.name} joined'));
      });
    } else if (t == 'leave') {
      final uid = (e['userId'] ?? '').toString();
      setState(() {
        _presence.removeWhere((x) => x.id == uid);
        _messages.add(_Msg.system('A participant left'));
      });
    } else if (t == 'edit') {
      final note = (e['note'] ?? '').toString();
      if (note != _noteCtrl.text) {
        _noteCtrl.text = note;
      }
    } else if (t == 'message') {
      final u = _User.fromJson(e['user']);
      final text = (e['text'] ?? '').toString();
      setState(() => _messages.add(_Msg.user(u, text)));
    }
  }

  void _onNoteChanged(String s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _socket.send({'type': 'edit', 'note': s});
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _socket.send({'type': 'message', 'text': text});
    setState(() {
      _messages.add(_Msg.user(_User(id: widget.currentUserId, name: widget.currentUserName), text));
      _msgCtrl.clear();
    });
  }

  Future<void> _openInvite() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _InviteSheet(
        link: widget.inviteLink ??
            'https://example.com/join/${Uri.encodeComponent(widget.roomId)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _presence;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.headerTitle),
        actions: [
          IconButton(
            tooltip: 'Invite',
            onPressed: _openInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          StreamBuilder<ConnState>(
            stream: _socket.state$,
            initialData: _socket.state,
            builder: (context, snap) {
              final st = snap.data ?? ConnState.disconnected;
              final color = st == ConnState.connected
                  ? Colors.green
                  : (st == ConnState.connecting ? Colors.orange : Colors.red);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: color),
                    const SizedBox(width: 6),
                    Text(
                      st.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Presence bar
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final u = users[i];
                  return _Avatar(name: u.name);
                },
              ),
            ),

            // Shared note
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _noteCtrl,
                minLines: 4,
                maxLines: 10,
                onChanged: _onNoteChanged,
                decoration: const InputDecoration(
                  labelText: 'Shared note',
                  hintText: 'Brainstorm together…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            // Chat list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  if (m.system != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          m.system!,
                          style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                      ),
                    );
                  }
                  return ListTile(
                    leading: _Avatar(name: m.user!.name),
                    title: Text(m.user!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.text ?? ''),
                  );
                },
              ),
            ),

            // Composer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
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

// --- UI bits

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.toUpperCase()).join();
    return CircleAvatar(
      radius: 20,
      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Invite to collaborate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: link,
            readOnly: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy & close'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Models

class _User {
  final String id;
  final String name;
  _User({required this.id, required this.name});
  factory _User.fromJson(dynamic v) {
    final m = (v as Map).cast<String, dynamic>();
    return _User(id: (m['id'] ?? '').toString(), name: (m['name'] ?? '').toString());
  }
}

class _Msg {
  final _User? user;
  final String? text;
  final String? system;
  _Msg.user(this.user, this.text) : system = null;
  _Msg.system(this.system)
      : user = null,
        text = null;
}

// --- WebSocket wrapper with basic reconnection

enum ConnState { disconnected, connecting, connected }

class CollabSocket {
  CollabSocket({required this.wsUrl, required this.onEvent});

  final String wsUrl;
  final void Function(Map<String, dynamic> event) onEvent;

  WebSocketChannel? _ch;
  final _stateC = StreamController<ConnState>.broadcast();
  ConnState _state = ConnState.disconnected;
  Timer? _retry;
  int _attempt = 0;

  Stream<ConnState> get state$ => _stateC.stream;
  ConnState get state => _state;

  void _set(ConnState s) {
    _state = s;
    _stateC.add(s);
  }

  void connect() {
    if (_state == ConnState.connected || _state == ConnState.connecting) return;
    _set(ConnState.connecting);
    try {
      _ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ch!.stream.listen(
        (data) {
          _set(ConnState.connected);
          _attempt = 0;
          try {
            final m = jsonDecode(data as String) as Map<String, dynamic>;
            onEvent(m);
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _set(ConnState.disconnected);
    _ch?.sink.close();
    _ch = null;
    _attempt = (_attempt + 1).clamp(1, 6);
    _retry?.cancel();
    // Exponential backoff up to ~32s
    final delay = Duration(seconds: 1 << (_attempt - 1));
    _retry = Timer(delay, connect);
  }

  void send(Map<String, dynamic> json) {
    final s = _ch;
    if (s == null) return;
    try {
      s.sink.add(jsonEncode(json));
    } catch (_) {}
  }

  void dispose() {
    _retry?.cancel();
    _ch?.sink.close();
    _stateC.close();
  }
}
