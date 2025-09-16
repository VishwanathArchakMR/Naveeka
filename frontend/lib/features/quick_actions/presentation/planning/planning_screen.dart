// lib/features/quick_actions/presentation/planning/planning_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/message_item.dart';

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
  const Place({required this.id, this.name, this.photos, this.rating, this.lat, this.lng, this.isFavorite, this.isWishlisted});
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
      // TODO: fetch groups, current group chat, itinerary, map stops, suggestions
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreGroups() async {
    if (!_hasMoreGroups || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of groups and append to _groups
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreSuggested() async {
    if (!_hasMoreSuggested || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of suggested places
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateTrip() {
    // TODO: Navigator.pushNamed(context, '/createTrip')
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Create Trip')));
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
      ), // CustomScrollView slivers let complex pages mix multiple sections efficiently and clearly. [1][2]

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
      ), // RefreshIndicator.adaptive applies platform‑appropriate pull‑to‑refresh visuals on iOS and Android. [7][10]
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
              // TODO: leave group
              await Future.delayed(const Duration(milliseconds: 150));
            },
            onNewGroup: _openCreateTrip,
            sectionTitle: 'Trip groups',
          ),
        ); // Groups list uses ListView.separated and badges within a card section for a clean, scalable list. [1][2]

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
                        // TODO: apply filters to suggestions/map
                        await Future.delayed(const Duration(milliseconds: 150));
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
                        // TODO: request AI plan and hydrate itinerary/stops
                        await Future.delayed(const Duration(milliseconds: 200));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI planning requested')));
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
                  // TODO: send message
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
        ); // The Plan tab composes chat, map, and itinerary into a single scannable column of cards within the scroll. [1][2]

      case _PlanTab.discover:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              InviteFriendsCard(suggested: const []),
              const SizedBox(height: 12),
              PlanningSearchButton(
                onApply: (params) async {
                  // TODO: search and update _suggested
                  await Future.delayed(const Duration(milliseconds: 120));
                },
                initialOrigin: null,
                initialRadiusKm: null,
                mapBuilder: widget.mapBuilder,
                onResolveCurrent: widget.onResolveCurrent,
                onSuggest: widget.onSuggest,
                onGeocode: widget.onGeocode,
              ),
              const SizedBox(height: 12),
              // Placeholder discovery grid/list here or reuse a suggestions widget from Messages if desired.
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Use search above to discover places',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ); // The Discover tab pairs filters and guidance to feed targeted results without leaving the planning context. [1][2]
    }
  }
}
