// lib/features/quick_actions/presentation/planning/trip_group_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Shared planning widgets and contracts
import 'widgets/group_chat.dart';
import 'widgets/trip_map_view.dart';
import 'widgets/trip_itinerary.dart';
import 'widgets/invite_friends.dart';
import 'widgets/location_picker.dart';

// If your app defines its own message/place models, import them instead.
class MessageItem {
  const MessageItem({
    required this.id,
    required this.senderId,
    required this.sentAt,
    this.text,
    this.isMine = false,
    this.attachmentUrls = const <String>[],
    this.location,
  });

  final String id;
  final String senderId;
  final DateTime sentAt;
  final String? text;
  final bool isMine;
  final List<String> attachmentUrls;
  final GeoPoint? location;
}

class TripGroupScreen extends StatefulWidget {
  const TripGroupScreen({
    super.key,

    // Group identity
    required this.groupId,
    required this.groupTitle,
    this.coverImageUrl,

    // Participants & chat
    this.participants = const <GroupParticipant>[],
    this.messages = const <MessageItem>[],
    this.loadingMessages = false,
    this.hasMoreMessages = false,

    // Map & itinerary
    this.stops = const <TripMapStop>[],
    this.days = const <ItineraryDay>[],
    this.initialDayFilter,

    // Map/search helpers
    this.mapBuilder,
    this.onResolveCurrent,

    // Actions
    this.onRefreshAll,
    this.onLoadMoreMessages,
    this.onSendText,
    this.onAttach,
    this.onShareLocation,
    this.onOpenAttachment,
    this.onOpenLocation,
    this.onOpenStop,
    this.onDirections,
    this.onReorderActivity,
    this.onEditNotes,

    // Group actions
    this.onInviteFriends,
    this.onLeaveGroup,
  });

  // Group identity
  final String groupId;
  final String groupTitle;
  final String? coverImageUrl;

  // Participants & chat
  final List<GroupParticipant> participants;
  final List<MessageItem> messages;
  final bool loadingMessages;
  final bool hasMoreMessages;

  // Map & itinerary
  final List<TripMapStop> stops;
  final List<ItineraryDay> days;
  final int? initialDayFilter;

  // Map/search helpers
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;

  // Page-level refresh
  final Future<void> Function()? onRefreshAll;

  // Chat actions
  final Future<void> Function()? onLoadMoreMessages;
  final Future<void> Function(String text)? onSendText;
  final Future<void> Function()? onAttach;
  final Future<void> Function(ShareLocationRequest req)? onShareLocation;
  final void Function(String url)? onOpenAttachment;
  final void Function(GeoPoint point)? onOpenLocation;

  // Map actions
  final void Function(TripMapStop stop)? onOpenStop;
  final Future<void> Function(TripMapStop stop)? onDirections;

  // Itinerary actions
  final Future<void> Function(DateTime day, int oldIndex, int newIndex)? onReorderActivity;
  final Future<void> Function(DateTime day, ItineraryActivity activity, String nextNotes)? onEditNotes;

  // Group actions
  final Future<void> Function()? onInviteFriends;
  final Future<void> Function()? onLeaveGroup;

  @override
  State<TripGroupScreen> createState() => _TripGroupScreenState();
}

class _TripGroupScreenState extends State<TripGroupScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (widget.onRefreshAll != null) {
      await widget.onRefreshAll!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: _refreshAll,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: (widget.coverImageUrl ?? '').trim().isEmpty ? 96 : 200,
              flexibleSpace: (widget.coverImageUrl ?? '').trim().isEmpty
                  ? null
                  : FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                          ),
                          Container(color: Colors.black.withValues(alpha: 0.25)),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                widget.groupTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              title: (widget.coverImageUrl ?? '').trim().isEmpty
                  ? Text(widget.groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              actions: [
                IconButton(
                  tooltip: 'Invite',
                  onPressed: widget.onInviteFriends,
                  icon: const Icon(Icons.person_add_alt_1),
                ),
                IconButton(
                  tooltip: 'Leave',
                  onPressed: widget.onLeaveGroup,
                  icon: const Icon(Icons.logout),
                ),
              ],
              bottom: TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
                  Tab(text: 'Map', icon: Icon(Icons.map_outlined)),
                  Tab(text: 'Itinerary', icon: Icon(Icons.event_note_outlined)),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabs,
            children: [
              // Chat tab
              _ChatTab(
                participants: widget.participants,
                messages: widget.messages,
                loading: widget.loadingMessages,
                hasMore: widget.hasMoreMessages,
                onRefresh: _refreshAll,
                onLoadMore: widget.onLoadMoreMessages,
                onSendText: widget.onSendText,
                onAttach: widget.onAttach,
                onShareLocation: widget.onShareLocation,
                onOpenAttachment: widget.onOpenAttachment,
                onOpenLocation: widget.onOpenLocation,
              ),

              // Map tab
              _MapTab(
                stops: widget.stops,
                mapBuilder: widget.mapBuilder,
                initialDayFilter: widget.initialDayFilter,
                onOpenStop: widget.onOpenStop,
                onDirections: widget.onDirections,
              ),

              // Itinerary tab
              _ItineraryTab(
                days: widget.days,
                onReorder: widget.onReorderActivity,
                onEditNotes: widget.onEditNotes,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onInviteFriends,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite'),
        backgroundColor: cs.primary.withValues(alpha: 1.0),
        foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
      ),
    );
  }
}

// ---------------- Tabs ----------------

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.participants,
    required this.messages,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onSendText,
    this.onAttach,
    this.onShareLocation,
    this.onOpenAttachment,
    this.onOpenLocation,
  });

  final List<GroupParticipant> participants;
  final List<MessageItem> messages;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final Future<void> Function(String text)? onSendText;
  final Future<void> Function()? onAttach;
  final Future<void> Function(ShareLocationRequest req)? onShareLocation;

  final void Function(String url)? onOpenAttachment;
  final void Function(GeoPoint point)? onOpenLocation;

  @override
  Widget build(BuildContext context) {
    return GroupChat(
      groupTitle: 'Group chat',
      participants: participants,
      currentUserId: 'me',
      messages: messages,
      loading: loading,
      hasMore: hasMore,
      onRefresh: onRefresh,
      onLoadMore: onLoadMore,
      onSendText: onSendText,
      onAttach: onAttach,
      onShareLocation: onShareLocation,
      onOpenAttachment: onOpenAttachment,
      onOpenLocation: onOpenLocation,
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
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({
    required this.stops,
    required this.mapBuilder,
    required this.initialDayFilter,
    this.onOpenStop,
    this.onDirections,
  });

  final List<TripMapStop> stops;
  final NearbyMapBuilder? mapBuilder;
  final int? initialDayFilter;

  final void Function(TripMapStop stop)? onOpenStop;
  final Future<void> Function(TripMapStop stop)? onDirections;

  @override
  Widget build(BuildContext context) {
    return TripMapView(
      stops: stops,
      mapBuilder: mapBuilder,
      center: null,
      polylinesSupported: false,
      height: double.infinity, // fills tab
      onOpenStop: onOpenStop,
      onDirections: onDirections,
      dayFilter: initialDayFilter,
    );
  }
}

class _ItineraryTab extends StatelessWidget {
  const _ItineraryTab({
    required this.days,
    this.onReorder,
    this.onEditNotes,
  });

  final List<ItineraryDay> days;
  final Future<void> Function(DateTime day, int oldIndex, int newIndex)? onReorder;
  final Future<void> Function(DateTime day, ItineraryActivity activity, String nextNotes)? onEditNotes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (days.isEmpty) {
      return Center(
        child: Text('No itinerary yet', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return TripItinerary(
      days: days,
      initialOpenAll: false,
      onReorder: onReorder,
      onEditNotes: onEditNotes,
      sectionTitle: 'Itinerary',
    );
  }
}
