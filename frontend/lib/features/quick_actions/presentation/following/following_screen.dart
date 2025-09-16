// lib/features/quick_actions/presentation/following/following_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Section widgets
import 'widgets/go_to_trail_cta.dart';
import 'widgets/following_feed.dart';
import 'widgets/recent_posts.dart';
import 'widgets/suggested_accounts.dart';

enum _FollowTab { feed, posts, people }

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
    this.initialTab = _FollowTab.feed,

    // Preload data (wire these to providers in the real app)
    this.initialFeedItems = const <FollowingFeedItem>[],
    this.initialPosts = const <RecentPost>[],
    this.initialAccounts = const <SuggestedAccount>[],

    // Loading/pagination flags
    this.loading = false,
    this.hasMoreFeed = false,
    this.hasMorePosts = false,
    this.hasMoreAccounts = false,
  });

  final _FollowTab initialTab;

  final List<FollowingFeedItem> initialFeedItems;
  final List<RecentPost> initialPosts;
  final List<SuggestedAccount> initialAccounts;

  final bool loading;
  final bool hasMoreFeed;
  final bool hasMorePosts;
  final bool hasMoreAccounts;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  _FollowTab _tab = _FollowTab.feed;

  // State mirrors (replace with Riverpod/Bloc in production)
  bool _loading = false;
  bool _hasMoreFeed = false;
  bool _hasMorePosts = false;
  bool _hasMoreAccounts = false;

  List<FollowingFeedItem> _feed = <FollowingFeedItem>[];
  List<RecentPost> _posts = <RecentPost>[];
  List<SuggestedAccount> _accounts = <SuggestedAccount>[];

  // Example filter state for feed types
  final List<String> _types = const ['review', 'photo', 'place', 'journey'];
  Set<String> _selectedTypes = const {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _feed = [...widget.initialFeedItems];
    _posts = [...widget.initialPosts];
    _accounts = [...widget.initialAccounts];
    _loading = widget.loading;
    _hasMoreFeed = widget.hasMoreFeed;
    _hasMorePosts = widget.hasMorePosts;
    _hasMoreAccounts = widget.hasMoreAccounts;
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // TODO: invalidate providers and refetch feed/posts/accounts
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreFeed() async {
    if (!_hasMoreFeed || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page for feed
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page for posts
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreAccounts() async {
    if (!_hasMoreAccounts || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page for accounts
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Feed interactions
  Future<bool> _toggleLike(FollowingFeedItem item, bool next) async {
    // TODO: call API; keep optimistic state handled in tile
    await Future.delayed(const Duration(milliseconds: 150));
    return true;
  }

  // Posts interactions
  Future<bool> _toggleLikePost(RecentPost p, bool next) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return true;
  }

  // Accounts interactions
  Future<bool> _toggleFollow(SuggestedAccount acc, bool next) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      // Header: title + segmented view
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Following', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              SegmentedButton<_FollowTab>(
                segments: const [
                  ButtonSegment(value: _FollowTab.feed, label: Text('Feed'), icon: Icon(Icons.dynamic_feed_outlined)),
                  ButtonSegment(value: _FollowTab.posts, label: Text('Posts'), icon: Icon(Icons.collections_outlined)),
                  ButtonSegment(value: _FollowTab.people, label: Text('People'), icon: Icon(Icons.group_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ), // CustomScrollView slivers let the screen combine multiple sections and layouts in a single performant scroll. [1][2]

      // Optional CTA banner/card
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GoToTrailCta(
            onPrimary: () async {
              // TODO: navigate to "trail" route
              await Future.delayed(const Duration(milliseconds: 150));
            },
            onSecondary: () {
              // TODO: persist hidden flag
            },
          ),
        ),
      ), // Banners/CTAs sit naturally as top slivers and keep content scannable below. [1]

      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Body per tab
      SliverToBoxAdapter(child: _buildTabBody()),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
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
        onPressed: _refreshAll,
        icon: const Icon(Icons.sync),
        label: const Text('Sync'),
        backgroundColor: cs.primary.withValues(alpha: 1.0),
        foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
      ),
    ); // RefreshIndicator.adaptive adds platform-appropriate pull-to-refresh behavior for a unified UX. [6][12]
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case _FollowTab.feed:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FollowingFeed(
            items: _feed,
            loading: _loading,
            hasMore: _hasMoreFeed,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreFeed,
            onOpenItem: (it) {
              // TODO: navigate to the referenced content
            },
            onOpenAuthor: (id) {
              // TODO: open profile
            },
            onToggleLike: (it, next) => _toggleLike(it, next),
            onComment: (it) {
              // TODO: open comments
            },
            types: _types,
            selectedTypes: _selectedTypes,
            onChangeTypes: (s) => setState(() => _selectedTypes = s),
            sectionTitle: 'Activity',
          ),
        ); // The feed uses ListView.separated inside a section card with infinite scroll for long streams. [21][22]

      case _FollowTab.posts:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RecentPosts(
            items: _posts,
            loading: _loading,
            hasMore: _hasMorePosts,
            onRefresh: _refreshAll,
            onLoadMore: _loadMorePosts,
            onOpenPost: (p) {
              // TODO: open post viewer
            },
            onOpenAuthor: (id) {
              // TODO: open profile
            },
            onToggleLike: (p, next) => _toggleLikePost(p, next),
            onComment: (p) {
              // TODO: open comments
            },
            onShare: (p) {
              // TODO: share
            },
            sectionTitle: 'Recent posts',
          ),
        ); // Horizontal ListView.builder supports a compact, immersive media row for recent content. [23][22]

      case _FollowTab.people:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SuggestedAccounts(
            items: _accounts,
            loading: _loading,
            hasMore: _hasMoreAccounts,
            onLoadMore: _loadMoreAccounts,
            onOpenProfile: (acc) {
              // TODO: open profile
            },
            onToggleFollow: (acc, next) => _toggleFollow(acc, next),
            onSeeAll: () {
              // TODO: navigate to people discovery
            },
            sectionTitle: 'Suggested accounts',
          ),
        ); // A horizontally scrolling accounts row pairs with modern Follow/Following buttons for quick actions. [24][23]
    }
  }
}
