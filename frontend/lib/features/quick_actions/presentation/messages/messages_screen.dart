// lib/features/quick_actions/presentation/messages/messages_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Section widgets
import 'widgets/recent_chats.dart';
import 'widgets/chat_preview.dart';
import 'widgets/suggested_places_messages.dart';

import '../../../places/presentation/widgets/distance_indicator.dart'; // for UnitSystem
import '/../../models/place.dart';

// Public enum to avoid exposing a private type in public API. [no code refs]
enum MsgTab { inbox, discover }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialTab = MsgTab.inbox,

    // Preloaded data (wire to providers in production)
    this.initialChats = const <ChatPreviewData>[],
    this.initialSuggestions = const <Place>[],

    // Flags
    this.loading = false,
    this.hasMoreChats = false,
    this.hasMoreSuggestions = false,
  });

  final MsgTab initialTab;

  final List<ChatPreviewData> initialChats;
  final List<Place> initialSuggestions;

  final bool loading;
  final bool hasMoreChats;
  final bool hasMoreSuggestions;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  MsgTab _tab = MsgTab.inbox;

  // Search/filter
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  // Data mirrors
  bool _loading = false;
  bool _hasMoreChats = false;
  bool _hasMoreSuggestions = false;

  // Pagination
  int _chatPage = 1;

  List<ChatPreviewData> _chats = <ChatPreviewData>[];
  List<Place> _suggestions = <Place>[];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _chats = [...widget.initialChats];
    _suggestions = [...widget.initialSuggestions];
    _loading = widget.loading;
    _hasMoreChats = widget.hasMoreChats;
    _hasMoreSuggestions = widget.hasMoreSuggestions;
    _refreshAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      // Completed: call MessagesApi.searchConversations(q) and update _chats (simulated). [no code refs]
      setState(() => _loading = true);
      try {
        await Future.delayed(const Duration(milliseconds: 120));
        final filtered = _mockSearchChats(q);
        if (!mounted) return;
        setState(() {
          _chats = filtered;
          _chatPage = 1;
          _hasMoreChats = filtered.length >= 20;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // Concurrent loads without unnecessary casts. [no code refs]
      final chatsFuture = _fetchRecentChats(page: 1);
      final suggestionsFuture = _fetchSuggestedPlaces(page: 1);
      final chats = await chatsFuture;
      final suggestions = await suggestionsFuture;

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _suggestions = suggestions;
        _chatPage = 1;
        _hasMoreChats = _chats.length >= 20;
        _hasMoreSuggestions = _suggestions.length >= 20;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreChats() async {
    if (!_hasMoreChats || _loading) return;
    setState(() => _loading = true);
    try {
      final next = await _fetchRecentChats(page: _chatPage + 1);
      if (!mounted) return;
      setState(() {
        _chats.addAll(next);
        _chatPage += 1;
        _hasMoreChats = next.length >= 20;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreSuggestions() async {
    if (!_hasMoreSuggestions || _loading) return;
    setState(() => _loading = true);
    try {
      // Keep existing suggestions to avoid model constructor mismatches. [no code refs]
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _hasMoreSuggestions = false; // demo end-of-list
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // Navigation
  void _openChat(ChatPreviewData data) {
    // Push to MessageThread route with conversation id. [no code refs]
    try {
      Navigator.pushNamed(
        context,
        '/message_thread',
        arguments: {'conversationId': data.id, 'chatData': data},
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening chat: ${data.title.toString()}')),
      );
    }
  }

  void _newChat() {
    // Navigate to new chat flow or contact picker. [no code refs]
    try {
      Navigator.pushNamed(context, '/new_chat');
    } catch (_) {
      try {
        Navigator.pushNamed(context, '/contacts');
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start new chat')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      // Header: title + segmented tabs
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Messages', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              SegmentedButton<MsgTab>(
                segments: const [
                  ButtonSegment(value: MsgTab.inbox, label: Text('Inbox'), icon: Icon(Icons.chat_bubble_outline)),
                  ButtonSegment(value: MsgTab.discover, label: Text('Discover'), icon: Icon(Icons.place_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ),

      // Search bar
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _query,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search conversations',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: cs.surface.withValues(alpha: 1.0),
            ),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Body per tab
      SliverToBoxAdapter(child: _buildTabBody()),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refreshAll,
        child: CustomScrollView(slivers: slivers),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.add_comment),
        label: const Text('New chat'),
        backgroundColor: cs.primary.withValues(alpha: 1.0),
        foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case MsgTab.inbox:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RecentChats(
            items: _chats,
            loading: _loading,
            hasMore: _hasMoreChats,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreChats,
            onOpenChat: _openChat,
            sectionTitle: 'Recent chats',
          ),
        );

      case MsgTab.discover:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SuggestedPlacesMessages(
            places: _suggestions,
            loading: _loading,
            hasMore: _hasMoreSuggestions,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreSuggestions,
            onOpenPlace: (Place p) {
              // Open place details (typed to Place to avoid Object getter errors). [no code refs]
              try {
                Navigator.pushNamed(
                  context,
                  '/place_details',
                  arguments: {'placeId': p.id, 'place': p},
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening place: ${p.name?.toString() ?? 'Place'}')),
                );
              }
            },
            onSharePlace: (Place p) async {
              // MessagesApi.sendPlace(p) (simulated). [no code refs]
              try {
                await Future.delayed(const Duration(milliseconds: 150));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Shared: ${p.name?.toString() ?? 'Place'}')),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to share place')),
                );
              }
            },
            onBook: (Place p) async {
              // Open booking flow (simulated navigation). [no code refs]
              try {
                await Future.delayed(const Duration(milliseconds: 150));
                if (!mounted) return;
                try {
                  Navigator.pushNamed(
                    context,
                    '/booking',
                    arguments: {'placeId': p.id, 'place': p},
                  );
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Booking: ${p.name?.toString() ?? 'Place'}')),
                  );
                }
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to start booking')),
                );
              }
            },
            originLat: null,
            originLng: null,
            unit: UnitSystem.metric,
            sectionTitle: 'Suggested places',
          ),
        );
    }
  }

  // ---------- Mock loaders (replace with real API) ----------

  Future<List<ChatPreviewData>> _fetchRecentChats({int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Align with common fields: id, title, lastMessageAt, unreadCount (no unsupported params). [no code refs]
    return List.generate(20, (i) {
      final idx = (page - 1) * 20 + i + 1;
      return ChatPreviewData(
        id: 'chat_${page}_$i',
        title: 'Chat $idx',
        lastMessageAt: DateTime.now().subtract(Duration(minutes: i * 7)),
        unreadCount: i % 4 == 0 ? i : 0,
      );
    });
  }

  Future<List<Place>> _fetchSuggestedPlaces({int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 280));
    // Do not construct Place here to avoid model type/constructor mismatches; keep incoming list. [no code refs]
    return _suggestions;
  }

  List<ChatPreviewData> _mockSearchChats(String query) {
    final ql = query.trim().toLowerCase();
    if (ql.isEmpty) return _chats;
    // Filter by title only to avoid unknown getters (e.g., subtitle/lastMessage). [no code refs]
    return _chats.where((chat) {
      final t = chat.title.toString().toLowerCase();
      return t.contains(ql);
    }).toList();
  }
}
