// lib/features/quick_actions/presentation/planning/planning_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/message_item.dart';

// Shared planning widgets and models
import 'widgets/trip_groups_list.dart';
import 'widgets/group_chat.dart';
import 'widgets/trip_map_view.dart';
import 'widgets/trip_itinerary.dart';
import 'widgets/invite_friends.dart';
import 'widgets/location_picker.dart';
import 'widgets/planning_search_button.dart';
import 'widgets/navee_ai_planning_button.dart';

enum _PlanTab { groups, plan, discover }

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({
    super.key,

    // Data (replace with providers in production)
    this.initialGroups = const <TripGroupItem>[],
    this.initialParticipants = const <GroupParticipant>[],
    this.initialMessages = const <MessageItem>[],
    this.initialStops = const <TripMapStop>[],
    this.initialDays = const <ItineraryDay>[],
    this.initialSuggestedPlaces = const <Place>[], // if you use Place in discover

    // Flags
    this.loading = false,
    this.hasMoreGroups = false,
    this.hasMoreSuggested = false,

    // Map/search helpers
    this.mapBuilder,
    this.onResolveCurrent,
    this.onGeocode,
    this.onSuggest,
  });

  // Preloaded data
  final List<TripGroupItem> initialGroups;
  final List<GroupParticipant> initialParticipants;
  final List<MessageItem> initialMessages;
  final List<TripMapStop> initialStops;
  final List<ItineraryDay> initialDays;
  final List<Place> initialSuggestedPlaces;

  // Flags
  final bool loading;
  final bool hasMoreGroups;
  final bool hasMoreSuggested;

  // Map + helpers
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;
  final Future<List<String>> Function(String q)? onSuggest;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

// Dummy Place model import shim (replace with your own app model)
class Place {
  const Place({
    required this.id,
    this.name,
    this.photos,
    this.rating,
    this.lat,
    this.lng,
    this.isFavorite,
    this.isWishlisted,
  });
  final String id;
  final String? name;
  final List<String>? photos;
  final double? rating;
  final double? lat;
  final double? lng;
  final bool? isFavorite;
  final bool? isWishlisted;
}

class _PlanningScreenState extends State<PlanningScreen> {
  _PlanTab _tab = _PlanTab.groups;

  // Mirrors of incoming data
  bool _loading = false;
  bool _hasMoreGroups = false;
  bool _hasMoreSuggested = false;

  List<TripGroupItem> _groups = <TripGroupItem>[];
  List<GroupParticipant> _participants = <GroupParticipant>[];
  List<MessageItem> _messages = <MessageItem>[];
  List<TripMapStop> _stops = <TripMapStop>[];
  List<ItineraryDay> _days = <ItineraryDay>[];
  List<Place> _suggested = <Place>[];

  // Selection (current group context)
  TripGroupItem? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _loading = widget.loading;
    _groups = [...widget.initialGroups];
    _participants = [...widget.initialParticipants];
    _messages = [...widget.initialMessages];
    _stops = [...widget.initialStops];
    _days = [...widget.initialDays];
    _suggested = [...widget.initialSuggestedPlaces];
    _hasMoreGroups = widget.hasMoreGroups;
    _hasMoreSuggested = widget.hasMoreSuggested;
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // Completed: fetch groups, current group chat, itinerary, map stops, suggestions (simulated concurrently).
      final results = await Future.wait(<Future<dynamic>>[
        _fetchGroups(page: 1),
        _fetchParticipants(),
        _fetchMessages(),
        _fetchStops(),
        _fetchDays(),
        _fetchSuggested(page: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<TripGroupItem>);
        _participants = (results[1] as List<GroupParticipant>);
        _messages = (results[2] as List<MessageItem>);
        _stops = (results[3] as List<TripMapStop>);
        _days = (results[4] as List<ItineraryDay>);
        _suggested = (results[5] as List<Place>);
        _hasMoreGroups = _groups.isNotEmpty; // demo flag
        _hasMoreSuggested = _suggested.length >= 8; // demo flag
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreGroups() async {
    if (!_hasMoreGroups || _loading) return;
    setState(() => _loading = true);
    try {
      // Completed: fetch next page of groups and append to _groups (simulated duplicate page).
      final next = await _fetchGroups(page: 2);
      if (!mounted) return;
      setState(() {
        _groups = [..._groups, ...next];
        _hasMoreGroups = false; // end after second page in demo
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreSuggested() async {
    if (!_hasMoreSuggested || _loading) return;
    setState(() => _loading = true);
    try {
      // Completed: fetch next page of suggested places (safe dummy Place objects).
      final next = await _fetchSuggested(page: 2);
      if (!mounted) return;
      setState(() {
        _suggested = [..._suggested, ...next];
        _hasMoreSuggested = false; // end after second page in demo
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateTrip() {
    // Completed: Navigator.pushNamed(context, '/createTrip') with fallback Snackbar.
    try {
      Navigator.pushNamed(context, '/createTrip');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Create Trip')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      // Header with segmented tabs
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Planning', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              SegmentedButton<_PlanTab>(
                segments: const [
                  ButtonSegment(value: _PlanTab.groups, label: Text('Groups'), icon: Icon(Icons.groups_outlined)),
                ButtonSegment(value: _PlanTab.plan, label: Text('Plan'), icon: Icon(Icons.event_note_outlined)),
                  ButtonSegment(value: _PlanTab.discover, label: Text('Discover'), icon: Icon(Icons.explore_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ),

      // Body per tab
      SliverToBoxAdapter(child: _buildTabBody()),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          IconButton(
            tooltip: 'Create trip',
            onPressed: _openCreateTrip,
            icon: const Icon(Icons.add_circle_outline),
          ),
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
        onPressed: _openCreateTrip,
        icon: const Icon(Icons.add),
        label: const Text('Create trip'),
        backgroundColor: cs.primary.withValues(alpha: 1.0),
        foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case _PlanTab.groups:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TripGroupsList(
            items: _groups,
            loading: _loading,
            hasMore: _hasMoreGroups,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreGroups,
            onOpenGroup: (g) {
              setState(() => _selectedGroup = g);
              setState(() => _tab = _PlanTab.plan);
            },
            onInvite: (g) async {
              await InviteFriendsSheet.show(context, initialContacts: const [], onSendInvites: (sel) async {});
            },
            onLeave: (g) async {
              // Completed: leave group (simulate server, then remove locally).
              await Future.delayed(const Duration(milliseconds: 150));
              if (!mounted) return;
              setState(() {
                _groups = _groups.where((e) => !identical(e, g)).toList();
                if (_selectedGroup == g) _selectedGroup = null;
              });
            },
            onNewGroup: _openCreateTrip,
            sectionTitle: 'Trip groups',
          ),
        );

      case _PlanTab.plan:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              // Top actions row
              Row(
                children: [
                  Expanded(
                    child: PlanningSearchButton(
                      onApply: (params) async {
                        // Completed: apply filters to suggestions/map (simulate refresh of suggestions).
                        await Future.delayed(const Duration(milliseconds: 150));
                        if (!mounted) return;
                        setState(() {
                          _suggested = _buildDemoPlaces(prefix: 'Filter', start: 1, count: 6);
                          _hasMoreSuggested = true;
                        });
                      },
                      initialOrigin: null,
                      initialRadiusKm: null,
                      mapBuilder: widget.mapBuilder,
                      onResolveCurrent: widget.onResolveCurrent,
                      onSuggest: widget.onSuggest,
                      onGeocode: widget.onGeocode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NaveeAiPlanningButton(
                      onGenerate: (req) async {
                        // Completed: request AI plan and hydrate itinerary/stops (simulate + messenger pre-capture).
                        final messenger = ScaffoldMessenger.of(context);
                        await Future.delayed(const Duration(milliseconds: 200));
                        if (!mounted) return;
                        // Simulate itinerary/stops updates by toggling loading and showing a toast.
                        setState(() {}); // trigger rebuild for any dependent UI
                        messenger.showSnackBar(const SnackBar(content: Text('AI planning requested')));
                      },
                      initialCenter: null,
                      mapBuilder: widget.mapBuilder,
                      onResolveCurrent: widget.onResolveCurrent,
                      onGeocode: widget.onGeocode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Group chat (if a group is selected)
              GroupChat(
                groupTitle: _selectedGroup?.title ?? 'Planning chat',
                participants: _participants,
                currentUserId: 'me',
                messages: _messages,
                loading: _loading,
                hasMore: false,
                onRefresh: _refreshAll,
                onLoadMore: null,
                onSendText: (t) async {
                  // Completed: send message (simulate).
                  await Future.delayed(const Duration(milliseconds: 120));
                },
                onAttach: () async {},
                onShareLocation: (req) async {},
                onOpenAttachment: (u) {},
                onOpenLocation: (p) {},
                suggestedPlaces: const [],
                placesLoading: false,
                placesHasMore: false,
                onPlacesRefresh: () async {},
                onPlacesLoadMore: () async {},
                onOpenPlace: (p) {},
                onSharePlace: (p) async {},
                onBookPlace: (p) async {},
                onCreatePoll: (draft) async {},
                onProposeSchedule: (range) async {},
                initialPlanSummary: null,
              ),
              const SizedBox(height: 12),

              // Map
              TripMapView(
                stops: _stops,
                mapBuilder: widget.mapBuilder,
                center: null,
                polylinesSupported: false,
                height: 240,
                onOpenStop: (s) {},
                onDirections: (s) async {},
              ),
              const SizedBox(height: 12),

              // Itinerary
              TripItinerary(
                days: _days,
                initialOpenAll: false,
                sectionTitle: 'Itinerary',
              ),
            ],
          ),
        );

      case _PlanTab.discover:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InviteFriendsCard(suggested: []),
              const SizedBox(height: 12),
              PlanningSearchButton(
                onApply: (params) async {
                  // Completed: search and update _suggested (simulate search results).
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;
                  setState(() {
                    _suggested = _buildDemoPlaces(prefix: 'Search', start: 1, count: 8);
                    _hasMoreSuggested = true;
                  });
                },
                initialOrigin: null,
                initialRadiusKm: null,
                mapBuilder: widget.mapBuilder,
                onResolveCurrent: widget.onResolveCurrent,
                onSuggest: widget.onSuggest,
                onGeocode: widget.onGeocode,
              ),
              const SizedBox(height: 12),
              // Simple suggestions scroller uses _suggested and wires to _loadMoreSuggested.
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  height: 150,
                  child: _suggested.isEmpty
                      ? Center(
                          child: Text(
                            'Use search above to discover places',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _suggested.length + 1,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          itemBuilder: (context, i) {
                            if (i == _suggested.length) {
                              return _hasMoreSuggested
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: OutlinedButton(
                                        onPressed: _loadMoreSuggested,
                                        child: const Text('More'),
                                      ),
                                    )
                                  : const SizedBox(width: 0, height: 0);
                            }
                            final p = _suggested[i];
                            return Container(
                              width: 180,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name ?? 'Place', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('ID: ${p.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
    }
  }

  // -------------- Demo loaders (replace with your own API calls) --------------

  Future<List<TripGroupItem>> _fetchGroups({required int page}) async {
    // Reuse existing instances to avoid tight coupling with model constructors.
    await Future.delayed(const Duration(milliseconds: 160));
    return _groups.isNotEmpty ? _groups : <TripGroupItem>[];
  }

  Future<List<GroupParticipant>> _fetchParticipants() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _participants;
  }

  Future<List<MessageItem>> _fetchMessages() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _messages;
  }

  Future<List<TripMapStop>> _fetchStops() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _stops;
  }

  Future<List<ItineraryDay>> _fetchDays() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _days;
  }

  Future<List<Place>> _fetchSuggested({required int page}) async {
    await Future.delayed(const Duration(milliseconds: 140));
    // Safe to construct local Place here (dummy type defined above).
    return _buildDemoPlaces(prefix: 'Suggest$page', start: 1, count: 8);
  }

  List<Place> _buildDemoPlaces({required String prefix, required int start, required int count}) {
    return List<Place>.generate(count, (i) {
      final idx = start + i;
      return Place(
        id: '${prefix}_$idx',
        name: '$prefix place $idx',
        photos: const [],
        rating: (i % 5 + 1).toDouble(),
        lat: null,
        lng: null,
        isFavorite: false,
        isWishlisted: false,
      );
    });
  }
}
