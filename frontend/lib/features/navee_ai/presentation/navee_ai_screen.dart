// lib/features/navee_ai/presentation/navee_ai_screen.dart

import 'package:flutter/material.dart';

import '../data/navee_ai_api.dart';

// Widgets we built earlier
import 'widgets/chat_interface.dart';
import 'widgets/explore_mode.dart';
import 'widgets/chat_threads.dart';
import 'widgets/collaborative_mode.dart';
import 'widgets/navee_ai_button.dart';
import 'widgets/ai_settings.dart';
import 'widgets/voice_input.dart';

class NaveeAiScreen extends StatefulWidget {
  const NaveeAiScreen({
    super.key,
    required this.api,
    this.title = 'Navee AI',
    this.initialTabIndex = 0,
    this.roomId = 'public-room',
    this.currentUserId = 'me',
    this.currentUserName = 'Me',
    this.wsBaseUrl = 'wss://collab.example.com/ws',
    this.settings,
  });

  final NaveeAiApi api;
  final String title;
  final int initialTabIndex;

  // Collaborative mode
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String wsBaseUrl;

  // Optional persisted settings for AI client
  final AiSettings? settings;

  @override
  State<NaveeAiScreen> createState() => _NaveeAiScreenState();
}

class _NaveeAiScreenState extends State<NaveeAiScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late AiSettings _settings;

  // Thread list data is delegated; here a simple in-memory list for wiring
  final List<ChatThread> _threads = <ChatThread>[];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 4,
        vsync: this,
        initialIndex: widget.initialTabIndex.clamp(0, 3));
    _settings = widget.settings ??
        const AiSettings(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: '',
          model: 'gpt-4o-mini',
          temperature: 0.6,
          jsonOnly: true,
          stripFences: true,
        );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final res = await AiSettingsSheet.show(context, initial: _settings);
    if (res != null) {
      setState(() => _settings = res);
    }
  } // Settings are presented via a shaped modal bottom sheet and return updated values using Navigator.pop for clean state handoff. [10]

  NaveeAiApi get _api => NaveeAiApi(
      baseUrl: _settings.baseUrl,
      apiKey: _settings.apiKey,
      defaultModel: _settings.model);

  void _addThreadFromPrompt(String prompt) {
    setState(() {
      final t = ChatThread(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: prompt.length > 28 ? '${prompt.substring(0, 28)}…' : prompt,
        preview: prompt,
        updatedAt: DateTime.now(),
        pinned: false,
        unread: 0,
        messageCount: 0,
      );
      _threads.insert(0, t);
      _tabs.index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabs: const [
        Tab(icon: Icon(Icons.forum_outlined), text: 'Chat'),
        Tab(icon: Icon(Icons.explore_outlined), text: 'Explore'),
        Tab(icon: Icon(Icons.list_alt_outlined), text: 'Threads'),
        Tab(icon: Icon(Icons.group_work_outlined), text: 'Collaborate'),
      ],
    ); // TabBar relies on a TabController from DefaultTabController or an explicit controller to keep tabs and view in sync. [1][2]

    final body = TabBarView(
      controller: _tabs,
      children: [
        // Chat
        ChatInterface(
          api: _api,
          initialSettings: _settings,
          title: 'Chat',
        ),

        // Explore
        ExploreMode(
          api: _api,
          title: 'Explore ideas',
        ),

        // Threads
        ChatThreadsScreen(
          threads: _threads,
          onOpen: (t) {
            // Navigate to chat with prefilled topic or hydrate chat history (hook up to storage layer)
            _tabs.index = 0;
          },
          onCreateNew: () {
            setState(() {
              _threads.insert(
                0,
                ChatThread(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: 'New conversation',
                  preview: '',
                  updatedAt: DateTime.now(),
                ),
              );
              _tabs.index = 0;
            });
          },
          onDelete: (t) =>
              setState(() => _threads.removeWhere((x) => x.id == t.id)),
          onRename: (t, name) {
            final i = _threads.indexWhere((x) => x.id == t.id);
            if (i != -1) {
              setState(() => _threads[i] =
                  _threads[i].copyWith(title: name, updatedAt: DateTime.now()));
            }
          },
          onTogglePin: (t, pinned) {
            final i = _threads.indexWhere((x) => x.id == t.id);
            if (i != -1) {
              setState(() => _threads[i] = _threads[i]
                  .copyWith(pinned: pinned, updatedAt: DateTime.now()));
            }
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final item = _threads.removeAt(oldIndex);
              _threads.insert(newIndex, item);
            });
          },
          onDuplicate: (t) {
            setState(() {
              final copy = t.copyWith(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: '${t.title} (copy)',
                updatedAt: DateTime.now(),
              );
              _threads.insert(0, copy);
            });
          },
        ),

        // Collaborative planning
        CollaborativeMode(
          roomId: widget.roomId,
          wsBaseUrl: widget.wsBaseUrl,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          headerTitle: 'Collaborative planning',
        ),
      ],
    ); // TabBarView holds the content pages and stays synchronized with the TabBar via the same TabController. [1][2]

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: tabBar,
        actions: [
          IconButton(
            tooltip: 'AI settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ), // Editing settings uses a modal bottom sheet and returns values with Navigator.pop. [10]
          VoiceInputButton(
            label: '',
            tooltip: 'Voice input',
            icon: Icons.mic_none,
            onFinal: (text) {
              // Default behavior: switch to Chat and prefill a new thread
              _addThreadFromPrompt(text);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice captured')));
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: NaveeAiButton(
        extended: true,
        label: 'Ask Navee',
        tooltip: 'Ask AI',
        onQuickAsk: (prompt) async {
          _addThreadFromPrompt(prompt);
        },
        onOpenChat: () => _tabs.index = 0,
        onOpenExplore: () => _tabs.index = 1,
        onOpenCollaborate: () => _tabs.index = 3,
        onOpenSettings: _openSettings,
      ), // The FAB launches a “Quick Ask” bottom sheet via showModalBottomSheet and routes to Chat/Explore/Collaborate as shortcuts. [10][21]
    );
  }
}
