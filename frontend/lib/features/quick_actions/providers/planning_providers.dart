// lib/features/quick_actions/providers/planning_providers.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ---------------- Shared value types (align with your backend DTOs) ----------------

@immutable
class TripGroupSummary {
  const TripGroupSummary({
    required this.id,
    required this.title,
    required this.memberCount,
    required this.lastActivityAt,
    this.coverImageUrl,
    this.destination,
    this.dateRange,
    this.unreadCount = 0,
    this.isOwner = false,
    this.isActive = true,
    this.planSummary,
  });

  final String id;
  final String title;
  final int memberCount;
  final DateTime lastActivityAt;

  final String? coverImageUrl;
  final String? destination;
  final DateTimeRange? dateRange;

  final int unreadCount;
  final bool isOwner;
  final bool isActive;
  final String? planSummary;

  TripGroupSummary copyWith({
    String? title,
    int? memberCount,
    DateTime? lastActivityAt,
    String? coverImageUrl,
    String? destination,
    DateTimeRange? dateRange,
    int? unreadCount,
    bool? isOwner,
    bool? isActive,
    String? planSummary,
  }) {
    return TripGroupSummary(
      id: id,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      destination: destination ?? this.destination,
      dateRange: dateRange ?? this.dateRange,
      unreadCount: unreadCount ?? this.unreadCount,
      isOwner: isOwner ?? this.isOwner,
      isActive: isActive ?? this.isActive,
      planSummary: planSummary ?? this.planSummary,
    );
  }
}

@immutable
class TripStop {
  const TripStop({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    this.subtitle,
    this.dayIndex,
    this.icon,
  });

  final String id;
  final double lat;
  final double lng;
  final String title;
  final String? subtitle;
  final int? dayIndex; // 1-based
  final String? icon;
}

@immutable
class ItineraryActivity {
  const ItineraryActivity({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.icon,
    this.thumbnailUrl,
    this.bookable = false,
    this.notes,
  });

  final String id;
  final TimeOfDay start;
  final TimeOfDay end;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? thumbnailUrl;
  final bool bookable;
  final String? notes;

  ItineraryActivity copyWith({String? notes}) {
    return ItineraryActivity(
      id: id,
      start: start,
      end: end,
      title: title,
      subtitle: subtitle,
      icon: icon,
      thumbnailUrl: thumbnailUrl,
      bookable: bookable,
      notes: notes ?? this.notes,
    );
  }
}

@immutable
class ItineraryDay {
  const ItineraryDay(
      {required this.date, required this.activities, this.title, this.summary});

  final DateTime date;
  final List<ItineraryActivity> activities;
  final String? title;
  final String? summary;
}

@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.name,
    this.rating,
    this.photos = const <String>[],
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final double? rating;
  final List<String> photos;
  final double? lat;
  final double? lng;
}

@immutable
class PlanningSearchParams {
  const PlanningSearchParams({
    required this.query,
    required this.categories,
    this.originLat,
    this.originLng,
    this.radiusKm,
    this.openNow = false,
    this.minRating,
    this.dateRange,
    this.partySize,
    this.tags = const <String>[],
  });

  final String query;
  final Set<String> categories;
  final double? originLat;
  final double? originLng;
  final double? radiusKm;
  final bool openNow;
  final double? minRating;
  final DateTimeRange? dateRange;
  final int? partySize;
  final List<String> tags;
}

@immutable
class PollDraft {
  const PollDraft({required this.question, required this.options});
  final String question;
  final List<String> options;
}

@immutable
class ScheduleProposal {
  const ScheduleProposal({required this.range, required this.proposedBy});
  final DateTimeRange range;
  final String proposedBy;
}

/// AI planning
@immutable
class NaveeAiPlanRequest {
  const NaveeAiPlanRequest({
    required this.mode,
    required this.prompt,
    required this.partySize,
    this.budgetPerPerson,
    this.dates,
    this.originLat,
    this.originLng,
    this.radiusKm,
    this.preferences = const <String>[],
    this.needAccessibility = false,
    this.preferPublicTransit = false,
  });

  final String mode;
  final String prompt;
  final int partySize;
  final double? budgetPerPerson;
  final DateTimeRange? dates;
  final double? originLat;
  final double? originLng;
  final double? radiusKm;
  final List<String> preferences;
  final bool needAccessibility;
  final bool preferPublicTransit;
}

@immutable
class AiPlanJob {
  const AiPlanJob({
    required this.jobId,
    required this.status, // queued | running | completed | failed
    this.summary,
    this.generatedStops = const <TripStop>[],
    this.generatedDays = const <ItineraryDay>[],
    this.error,
  });

  final String jobId;
  final String status;
  final String? summary;
  final List<TripStop> generatedStops;
  final List<ItineraryDay> generatedDays;
  final String? error;
}

@immutable
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;

  CursorPage<T> merge(CursorPage<T> next) => CursorPage<T>(
      items: [...items, ...next.items], nextCursor: next.nextCursor);
}

/// ---------------- Repository contract ----------------

abstract class PlanningRepository {
  // Groups
  Future<CursorPage<TripGroupSummary>> listGroups(
      {String? cursor, int limit = 20, String? query});
  Future<TripGroupSummary> getGroup(String groupId);
  Future<String> createTrip({
    required String title,
    DateTimeRange? range,
    int? partySize,
    double? originLat,
    double? originLng,
    double? radiusKm,
    List<String>? tags,
  });
  Future<bool> inviteUsers(
      {required String groupId, required List<String> userIds});
  Future<bool> leaveGroup({required String groupId});

  // Map + itinerary
  Future<CursorPage<TripStop>> listStops(
      {required String groupId, String? cursor, int limit = 200});
  Future<List<ItineraryDay>> getItinerary({required String groupId});
  Future<bool> reorderActivity(
      {required String groupId,
      required DateTime day,
      required int oldIndex,
      required int newIndex});
  Future<bool> editNotes(
      {required String groupId,
      required DateTime day,
      required String activityId,
      required String notes});

  // Polls + schedule
  Future<bool> createPoll({required String groupId, required PollDraft draft});
  Future<bool> proposeSchedule(
      {required String groupId, required DateTimeRange range});

  // Search/suggestions
  Future<CursorPage<PlaceSuggestion>> searchSuggestions(
      {required PlanningSearchParams params, String? cursor, int limit = 30});

  // AI plan
  Future<AiPlanJob> startAiPlan({required NaveeAiPlanRequest request});
  Future<AiPlanJob> getAiPlanJob({required String jobId});
}

/// Provide a concrete implementation higher in the tree with overrideWithValue.
final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  throw UnimplementedError(
      'Provide PlanningRepository via override in main/bootstrap');
}); // Central repository Provider pattern for overrides in tests/environments. [web:5777]

/// ---------------- Generic paging state ----------------

@immutable
class PagedState<T> {
  const PagedState(
      {required this.items,
      required this.cursor,
      required this.loading,
      this.error});
  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy(
          {List<T>? items, String? cursor, bool? loading, Object? error}) =>
      PagedState<T>(
          items: items ?? this.items,
          cursor: cursor ?? this.cursor,
          loading: loading ?? this.loading,
          error: error);

  static PagedState<T> empty<T>() => PagedState<T>(
      items: const <dynamic>[] as List<T>, cursor: null, loading: false);
} // Remove const generic literal to satisfy Dart’s invalid_type_argument_in_const_literal rule. [web:5888]

/// ---------------- Conversations-level filters or selections ----------------

/// Currently selected planning group in the app context.
final selectedGroupIdProvider = StateProvider<String?>((ref) =>
    null); // Local selection state used by dependent providers. [web:5777]

/// ---------------- Groups list controller ----------------

@immutable
class GroupsQuery {
  const GroupsQuery({this.search, this.pageSize = 20});
  final String? search;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is GroupsQuery &&
      other.search == search &&
      other.pageSize == pageSize;
  @override
  int get hashCode => Object.hash(search, pageSize);
}

class GroupsController extends AsyncNotifier<PagedState<TripGroupSummary>> {
  GroupsQuery _q = const GroupsQuery();

  @override
  FutureOr<PagedState<TripGroupSummary>> build() async {
    return PagedState.empty();
  } // AsyncNotifier build sets initial state; methods drive transitions. [web:5774]

  Future<void> init(GroupsQuery q) async {
    _q = q;
    await refresh();
  }

  Future<void> refresh() async {
    final repo = ref.read(planningRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listGroups(
        cursor: null,
        limit: _q.pageSize,
        query: (_q.search ?? '').trim().isEmpty ? null : _q.search!.trim()));
    state = res.whenData((page) => PagedState<TripGroupSummary>(
        items: page.items, cursor: page.nextCursor, loading: false));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<TripGroupSummary>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(planningRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listGroups(
        cursor: current.cursor,
        limit: _q.pageSize,
        query: (_q.search ?? '').trim().isEmpty ? null : _q.search!.trim()));
    res.when(
      data: (page) => state = AsyncData(current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }
}

final groupsControllerProvider = AsyncNotifierProvider<GroupsController,
        PagedState<TripGroupSummary>>(
    GroupsController
        .new); // AsyncNotifierProvider exposes state and notifier. [web:5774]

/// ---------------- Group-specific data: stops and itinerary (family controllers) ----------------

class StopsController
    extends FamilyAsyncNotifier<PagedState<TripStop>, String> {
  @override
  FutureOr<PagedState<TripStop>> build(String groupId) async {
    return PagedState.empty();
  } // FamilyAsyncNotifier receives the argument in build and exposes it via this.arg. [web:5912][web:5913]

  Future<void> refresh() async {
    final repo = ref.read(planningRepositoryProvider);
    final res = await AsyncValue.guard(
        () => repo.listStops(groupId: arg, cursor: null));
    state = res.whenData((page) => PagedState<TripStop>(
        items: page.items, cursor: page.nextCursor, loading: false));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<TripStop>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(planningRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(
        () => repo.listStops(groupId: arg, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }
}

final stopsControllerProvider = AsyncNotifierProvider
    .family<StopsController, PagedState<TripStop>, String>(StopsController
        .new); // Family provider bound to FamilyAsyncNotifier type. [web:5911][web:5912]

class ItineraryController
    extends FamilyAsyncNotifier<List<ItineraryDay>, String> {
  @override
  FutureOr<List<ItineraryDay>> build(String groupId) async {
    return const <ItineraryDay>[];
  } // FamilyAsyncNotifier for per-group itinerary state. [web:5912]

  Future<void> refresh() async {
    final repo = ref.read(planningRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.getItinerary(groupId: arg));
    state = res.whenData((days) => days);
  }

  Future<bool> reorder(DateTime day, int oldIndex, int newIndex) async {
    final repo = ref.read(planningRepositoryProvider);
    final prev = state.valueOrNull ?? const <ItineraryDay>[];
    // Local reorder
    final idx = prev.indexWhere((d) =>
        DateTime(d.date.year, d.date.month, d.date.day) ==
        DateTime(day.year, day.month, day.day));
    if (idx < 0) return false;
    final list = [...prev];
    final dayCopy = list[idx];
    final acts = [...dayCopy.activities];
    if (newIndex > oldIndex) newIndex -= 1;
    final it = acts.removeAt(oldIndex);
    acts.insert(newIndex, it);
    list[idx] = ItineraryDay(
        date: dayCopy.date,
        activities: acts,
        title: dayCopy.title,
        summary: dayCopy.summary);
    state = AsyncData(list);
    final ok = await AsyncValue.guard(() => repo.reorderActivity(
        groupId: arg, day: day, oldIndex: oldIndex, newIndex: newIndex));
    if (ok.hasError || (ok.value ?? false) == false) {
      state = AsyncData(prev);
      return false;
    }
    return true;
  }

  Future<bool> editNotes(DateTime day, String activityId, String notes) async {
    final repo = ref.read(planningRepositoryProvider);
    final prev = state.valueOrNull ?? const <ItineraryDay>[];
    final list = [...prev];
    final idx = list.indexWhere((d) =>
        DateTime(d.date.year, d.date.month, d.date.day) ==
        DateTime(day.year, day.month, day.day));
    if (idx < 0) return false;
    final acts = [...list[idx].activities];
    final aIdx = acts.indexWhere((a) => a.id == activityId);
    if (aIdx < 0) return false;
    acts[aIdx] = acts[aIdx].copyWith(notes: notes);
    list[idx] = ItineraryDay(
        date: list[idx].date,
        activities: acts,
        title: list[idx].title,
        summary: list[idx].summary);
    state = AsyncData(list);
    final ok = await AsyncValue.guard(() => repo.editNotes(
        groupId: arg, day: day, activityId: activityId, notes: notes));
    if (ok.hasError || (ok.value ?? false) == false) {
      state = AsyncData(prev);
      return false;
    }
    return true;
  }
}

final itineraryControllerProvider = AsyncNotifierProvider
    .family<ItineraryController, List<ItineraryDay>, String>(ItineraryController
        .new); // Family provider for itinerary controller with String key. [web:5911][web:5912]

/// ---------------- Polls and schedules (fire-and-forget actions) ----------------

final createPollProvider = FutureProvider.family
    .autoDispose<bool, ({String groupId, PollDraft draft})>((ref, args) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.createPoll(groupId: args.groupId, draft: args.draft);
}); // One-shot family mutation with autoDispose for clear UI states. [web:5770]

final proposeScheduleProvider = FutureProvider.family
    .autoDispose<bool, ({String groupId, DateTimeRange range})>(
        (ref, args) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.proposeSchedule(groupId: args.groupId, range: args.range);
}); // Family FutureProvider for proposing schedules with argument. [web:5770]

/// ---------------- Discovery search (params + paging) ----------------

final planningSearchParamsProvider = StateProvider<PlanningSearchParams?>(
    (ref) => null); // Holds current search params as SoT. [web:5770]

class SuggestionsController extends AsyncNotifier<PagedState<PlaceSuggestion>> {
  @override
  FutureOr<PagedState<PlaceSuggestion>> build() async {
    return PagedState.empty();
  } // AsyncNotifier state for discovery results. [web:5774]

  PlanningSearchParams? get _params => ref.read(planningSearchParamsProvider);

  Future<void> refresh() async {
    final p = _params;
    if (p == null) {
      state = AsyncData(PagedState.empty());
      return;
    }
    final repo = ref.read(planningRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(
        () => repo.searchSuggestions(params: p, cursor: null));
    state = res.whenData((page) => PagedState<PlaceSuggestion>(
        items: page.items, cursor: page.nextCursor, loading: false));
  }

  Future<void> loadMore() async {
    final p = _params;
    final current = state.valueOrNull ?? PagedState.empty<PlaceSuggestion>();
    if (p == null || current.loading || current.cursor == null) return;
    final repo = ref.read(planningRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(
        () => repo.searchSuggestions(params: p, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }
}

final suggestionsControllerProvider = AsyncNotifierProvider<
        SuggestionsController, PagedState<PlaceSuggestion>>(
    SuggestionsController
        .new); // Discovery paging controller under AsyncNotifier. [web:5774]

/// ---------------- AI planning job controller ----------------

@immutable
class AiPlanState {
  const AiPlanState._({required this.stage, this.job, this.error});
  final String stage; // idle | running | completed | failed
  final AiPlanJob? job;
  final Object? error;

  const AiPlanState.idle() : this._(stage: 'idle');
  const AiPlanState.running(AiPlanJob j) : this._(stage: 'running', job: j);
  const AiPlanState.completed(AiPlanJob j) : this._(stage: 'completed', job: j);
  const AiPlanState.failed(Object e) : this._(stage: 'failed', error: e);
}

class AiPlanController extends AsyncNotifier<AiPlanState> {
  @override
  FutureOr<AiPlanState> build() {
    return const AiPlanState.idle();
  } // AsyncNotifier lifecycle for job states. [web:5774]

  Future<AiPlanJob> start(NaveeAiPlanRequest req) async {
    final repo = ref.read(planningRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.startAiPlan(request: req));
    return res.when(
      data: (job) {
        state = AsyncData(AiPlanState.running(job));
        return job;
      },
      loading: () => const AiPlanJob(jobId: 'pending', status: 'queued'),
      error: (e, st) {
        state = AsyncError(e, st);
        state =
            const AsyncData(AiPlanState.failed('Failed to start AI planning'));
        throw e;
      },
    );
  }

  Future<AiPlanJob?> poll(String jobId) async {
    final repo = ref.read(planningRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.getAiPlanJob(jobId: jobId));
    return res.when(
      data: (job) {
        if (job.status == 'completed') {
          state = AsyncData(AiPlanState.completed(job));
        } else if (job.status == 'failed') {
          state = const AsyncData(AiPlanState.failed('AI planning failed'));
        } else {
          state = AsyncData(AiPlanState.running(job));
        }
        return job;
      },
      loading: () => state.valueOrNull?.job,
      error: (e, st) {
        state = AsyncError(e, st);
        return null;
      },
    );
  }

  void reset() {
    state = const AsyncData(AiPlanState.idle());
  }
}

final aiPlanControllerProvider =
    AsyncNotifierProvider<AiPlanController, AiPlanState>(AiPlanController
        .new); // Job lifecycle provider using AsyncNotifier. [web:5774]

/// ---------------- Create trip action (facade) ----------------

final createTripProvider = FutureProvider.family.autoDispose<
    String,
    ({
      String title,
      DateTimeRange? range,
      int? partySize,
      double? originLat,
      double? originLng,
      double? radiusKm,
      List<String>? tags,
    })>((ref, args) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.createTrip(
    title: args.title,
    range: args.range,
    partySize: args.partySize,
    originLat: args.originLat,
    originLng: args.originLng,
    radiusKm: args.radiusKm,
    tags: args.tags,
  );
}); // One-shot trip creation via FutureProvider.family. [web:5770]

/// ---------------- Invite/leave simple actions ----------------

final inviteUsersProvider = FutureProvider.family
    .autoDispose<bool, ({String groupId, List<String> userIds})>(
        (ref, args) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.inviteUsers(groupId: args.groupId, userIds: args.userIds);
}); // Family mutation provider for user invitations. [web:5770]

final leaveGroupProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, groupId) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.leaveGroup(groupId: groupId);
}); // Isolated leave action with its own loading/error via family. [web:5770]

/// ---------------- Facade for widgets/screens ----------------

typedef Reader = T Function<T>(ProviderListenable<T> provider);

class PlanningActions {
  PlanningActions(this._read);
  final Reader _read;

  // Groups
  Future<void> initGroups(GroupsQuery q) =>
      _read(groupsControllerProvider.notifier).init(q);
  Future<void> refreshGroups() =>
      _read(groupsControllerProvider.notifier).refresh();
  Future<void> loadMoreGroups() =>
      _read(groupsControllerProvider.notifier).loadMore();

  // Selection
  void selectGroup(String? groupId) =>
      _read(selectedGroupIdProvider.notifier).state = groupId;

  // Stops
  Future<void> initStops(String gid) =>
      _read(stopsControllerProvider(gid).notifier).refresh();
  Future<void> refreshStops(String gid) =>
      _read(stopsControllerProvider(gid).notifier).refresh();
  Future<void> loadMoreStops(String gid) =>
      _read(stopsControllerProvider(gid).notifier).loadMore();

  // Itinerary
  Future<void> initItinerary(String gid) =>
      _read(itineraryControllerProvider(gid).notifier).refresh();
  Future<void> refreshItinerary(String gid) =>
      _read(itineraryControllerProvider(gid).notifier).refresh();
  Future<bool> reorderActivity(
          String gid, DateTime day, int oldIndex, int newIndex) =>
      _read(itineraryControllerProvider(gid).notifier)
          .reorder(day, oldIndex, newIndex);
  Future<bool> editActivityNotes(
          String gid, DateTime day, String activityId, String notes) =>
      _read(itineraryControllerProvider(gid).notifier)
          .editNotes(day, activityId, notes);

  // Polls / schedule
  Future<bool> createPoll(String gid, PollDraft draft) =>
      _read(createPollProvider((groupId: gid, draft: draft)).future);
  Future<bool> proposeSchedule(String gid, DateTimeRange r) =>
      _read(proposeScheduleProvider((groupId: gid, range: r)).future);

  // Discovery
  void setSearchParams(PlanningSearchParams? p) =>
      _read(planningSearchParamsProvider.notifier).state = p;
  Future<void> refreshSuggestions() =>
      _read(suggestionsControllerProvider.notifier).refresh();
  Future<void> loadMoreSuggestions() =>
      _read(suggestionsControllerProvider.notifier).loadMore();

  // AI Planning
  Future<AiPlanJob> startAi(NaveeAiPlanRequest req) =>
      _read(aiPlanControllerProvider.notifier).start(req);
  Future<AiPlanJob?> pollAi(String jobId) =>
      _read(aiPlanControllerProvider.notifier).poll(jobId);
  void resetAi() => _read(aiPlanControllerProvider.notifier).reset();

  // Create / invite / leave direct
  Future<String> createTripDirect({
    required String title,
    DateTimeRange? range,
    int? partySize,
    double? originLat,
    double? originLng,
    double? radiusKm,
    List<String>? tags,
  }) =>
      _read(createTripProvider((
        title: title,
        range: range,
        partySize: partySize,
        originLat: originLat,
        originLng: originLng,
        radiusKm: radiusKm,
        tags: tags,
      )).future);

  Future<bool> inviteUsersDirect(String groupId, List<String> userIds) =>
      _read(inviteUsersProvider((groupId: groupId, userIds: userIds)).future);

  Future<bool> leaveGroupDirect(String groupId) =>
      _read(leaveGroupProvider(groupId).future);
}

final planningActionsProvider = Provider<PlanningActions>((ref) =>
    PlanningActions(ref
        .read)); // Pass Reader (ref.read) so facade methods can call _read(provider.notifier). [web:5777]
