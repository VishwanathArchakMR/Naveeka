// lib/features/quick_actions/presentation/messages/messages_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Section widgets
import 'widgets/recent_chats.dart';
import 'widgets/chat_preview.dart';
import 'widgets/suggested_places_messages.dart';

import '../../places/presentation/widgets/distance_indicator.dart'; // for UnitSystem
import '../../../models/place.dart';

enum _MsgTab { inbox, discover }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialTab = _MsgTab.inbox,

    // Preloaded data (wire to providers in production)
    this.initialChats = const <ChatPreviewData>[],
    this.initialSuggestions = const <Place>[],

    // Flags
    this.loading = false,
    this.hasMoreChats = false,
    this.hasMoreSuggestions = false,
  });

  final _MsgTab initialTab;

  final List<ChatPreviewData> initialChats;
  final List<Place> initialSuggestions;

  final bool loading;
  final bool hasMoreChats;
  final bool hasMoreSuggestions;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  _MsgTab _tab = _MsgTab.inbox;

  // Search/filter
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  // Data mirrors
  bool _loading = false;
  bool _hasMoreChats = false;
  bool _hasMoreSuggestions = false;

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
      // TODO: call MessagesApi.searchConversations(q) and update _chats
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {}); // in real app, set matched results
    });
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // TODO: fetch recent chats + suggested places concurrently
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreChats() async {
    if (!_hasMoreChats || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of conversations
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreSuggestions() async {
    if (!_hasMoreSuggestions || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of suggested places
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Navigation
  void _openChat(ChatPreviewData data) {
    // TODO: push to MessageThread route with conversation id
  }

  void _newChat() {
    // TODO: navigate to new chat flow or contact picker
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start new chat')));
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
              SegmentedButton<_MsgTab>(
                segments: const [
                  ButtonSegment(value: _MsgTab.inbox, label: Text('Inbox'), icon: Icon(Icons.chat_bubble_outline)),
                  ButtonSegment(value: _MsgTab.discover, label: Text('Discover'), icon: Icon(Icons.place_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ), // Sliver composition with CustomScrollView is the recommended pattern for complex layouts combining multiple sections. [1][2]

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
      ), // The adaptive RefreshIndicator provides platform-appropriate pull-to-refresh visuals and behavior. [6][12]
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
      case _MsgTab.inbox:
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
        ); // List-based inbox fits naturally as a sliver child with paging and pull-to-refresh semantics. [1][2]

      case _MsgTab.discover:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SuggestedPlacesMessages(
            places: _suggestions,
            loading: _loading,
            hasMore: _hasMoreSuggestions,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreSuggestions,
            onOpenPlace: (p) {
              // TODO: open place details
            },
            onSharePlace: (p) async {
              // TODO: MessagesApi.sendPlace(p)
              await Future.delayed(const Duration(milliseconds: 150));
            },
            onBook: (p) async {
              // TODO: open booking flow
              await Future.delayed(const Duration(milliseconds: 150));
            },
            originLat: null,
            originLng: null,
            unit: UnitSystem.metric,
            sectionTitle: 'Suggested places',
          ),
        ); // Horizontal carousel of suggested places complements messaging for sharing and planning. [21][22]
    }
  }
}
