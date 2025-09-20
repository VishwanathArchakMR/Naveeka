// lib/features/profile/providers/profile_providers.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/place.dart';

/// API contract to be implemented in features/profile/data/profile_api.dart and injected via override.
abstract class ProfileApi {
  Future<dynamic> getIdentity({required String userId});
  Future<dynamic> getCounts({required String userId});
  Future<dynamic> getTravelStats({required String userId});

  Future<List<Place>> getVisitedPlaces({required String userId});
  Future<List<Place>> getContributionPlaces({required String userId, required int page, required int limit});
  Future<List<dynamic>> getContributionReviews({required String userId, required int page, required int limit});
  Future<List<String>> getContributionPhotos({required String userId, required int page, required int limit});
  Future<List<dynamic>> getJourneys({required String userId, required int page, required int limit});
  Future<List<dynamic>> getActivity({required String userId, required int page, required int limit});
} // Define the surface area used by providers; override with a concrete implementation at app bootstrap.

/// DI: Profile API client (override in main/bootstrap with a concrete implementation)
final profileApiProvider = Provider<ProfileApi>((ref) {
  throw UnimplementedError('Provide ProfileApi via override');
}); // Throwing by default makes missing overrides explicit during boot.

/// Current user id (inject/override from auth layer)
final currentUserIdProvider = Provider<String?>((ref) => null);

/// ----------------------------
/// Models for typed state
/// ----------------------------

class ProfileIdentity {
  const ProfileIdentity({
    required this.name,
    this.username,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.location,
    this.joinedOn,
    this.verified = false,
  });

  final String name;
  final String? username;
  final String? headline;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? location;
  final DateTime? joinedOn;
  final bool verified;
}

class TravelStatsData {
  const TravelStatsData({
    this.totalDistanceKm = 0,
    this.totalDays = 0,
    this.totalTrips = 0,
    this.countries = 0,
    this.cities = 0,
    this.continentCounts = const <String, int>{},
    this.transportMix = const <String, double>{},
  });

  final double totalDistanceKm;
  final int totalDays;
  final int totalTrips;
  final int countries;
  final int cities;
  final Map<String, int> continentCounts;
  final Map<String, double> transportMix;
}

class ContributionReview {
  const ContributionReview({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
}

class JourneyStopDto {
  const JourneyStopDto({
    required this.title,
    this.subtitle,
    this.timeLabel,
    this.iconName, // Optional string name; map to IconData in UI layer.
  });

  final String title;
  final String? subtitle;
  final String? timeLabel;
  final String? iconName;
}

class JourneyDto {
  const JourneyDto({
    required this.id,
    required this.title,
    this.coverUrl,
    this.dateRange,
    this.days,
    this.places,
    this.distanceKm,
    this.stops = const <JourneyStopDto>[],
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? dateRange;
  final int? days;
  final int? places;
  final double? distanceKm;
  final List<JourneyStopDto> stops;
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.type, // e.g., 'review' | 'favorite' | 'placeCreated' ...
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.thumbnailUrl,
    this.targetId,
    this.targetType,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? thumbnailUrl;
  final String? targetId;
  final String? targetType;
}

class ProfileCounts {
  const ProfileCounts({
    this.places = 0,
    this.reviews = 0,
    this.photos = 0,
    this.followers = 0,
    this.following = 0,
    this.journeys = 0,
  });

  final int places;
  final int reviews;
  final int photos;
  final int followers;
  final int following;
  final int journeys;
}

class ProfileBundle {
  const ProfileBundle({
    required this.identity,
    required this.counts,
    required this.travel,
    required this.visitedPlaces,
    required this.contribPlaces,
    required this.contribReviews,
    required this.contribPhotos,
    required this.journeys,
    required this.activity,
  });

  final ProfileIdentity identity;
  final ProfileCounts counts;
  final TravelStatsData travel;
  final List<Place> visitedPlaces;
  final List<Place> contribPlaces;
  final List<ContributionReview> contribReviews;
  final List<String> contribPhotos;
  final List<JourneyDto> journeys;
  final List<ActivityEntry> activity;
}

/// ----------------------------
/// Family providers by userId
/// ----------------------------

/// Identity
final profileIdentityProvider =
    FutureProvider.autoDispose.family<ProfileIdentity, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final dto = await api.getIdentity(userId: userId);
  // Keep successful loads cached with autoDispose by enabling keepAlive after success.
  ref.keepAlive(); // Keeps state alive until an explicit invalidate/refresh. [Riverpod docs]
  return ProfileIdentity(
    name: dto.name ?? '',
    username: dto.username,
    headline: dto.headline,
    bio: dto.bio,
    avatarUrl: dto.avatarUrl,
    coverUrl: dto.coverUrl,
    location: dto.location,
    joinedOn: dto.joinedOn,
    verified: dto.verified ?? false,
  );
});

/// Counts
final profileCountsProvider =
    FutureProvider.autoDispose.family<ProfileCounts, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final dto = await api.getCounts(userId: userId);
  return ProfileCounts(
    places: dto.places ?? 0,
    reviews: dto.reviews ?? 0,
    photos: dto.photos ?? 0,
    followers: dto.followers ?? 0,
    following: dto.following ?? 0,
    journeys: dto.journeys ?? 0,
  );
});

/// Travel stats
final travelStatsProvider =
    FutureProvider.autoDispose.family<TravelStatsData, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final t = await api.getTravelStats(userId: userId);
  return TravelStatsData(
    totalDistanceKm: (t.totalDistanceKm ?? 0).toDouble(),
    totalDays: t.totalDays ?? 0,
    totalTrips: t.totalTrips ?? 0,
    countries: t.countries ?? 0,
    cities: t.cities ?? 0,
    continentCounts: t.continentCounts ?? const {},
    transportMix: t.transportMix ?? const {},
  );
});

/// Visited places
final visitedPlacesProvider =
    FutureProvider.autoDispose.family<List<Place>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  return await api.getVisitedPlaces(userId: userId);
});

/// Contribution: places
final contributionPlacesProvider =
    FutureProvider.autoDispose.family<List<Place>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  return await api.getContributionPlaces(userId: userId, page: 1, limit: 100);
});

/// Contribution: reviews
final contributionReviewsProvider =
    FutureProvider.autoDispose.family<List<ContributionReview>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final list = await api.getContributionReviews(userId: userId, page: 1, limit: 100);
  return list
      .map((e) => ContributionReview(id: e.id, title: e.title ?? '', subtitle: e.subtitle ?? ''))
      .toList(growable: false);
});

/// Contribution: photo URLs
final contributionPhotosProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  return await api.getContributionPhotos(userId: userId, page: 1, limit: 200);
});

/// Journeys
final profileJourneysProvider =
    FutureProvider.autoDispose.family<List<JourneyDto>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final list = await api.getJourneys(userId: userId, page: 1, limit: 50);
  return list
      .map((j) => JourneyDto(
            id: j.id,
            title: j.title ?? 'Journey',
            coverUrl: j.coverUrl,
            dateRange: j.dateRange,
            days: j.days,
            places: j.places,
            distanceKm: (j.distanceKm ?? 0).toDouble(),
            stops: (j.stops ?? const [])
                .map((s) => JourneyStopDto(
                      title: s.title ?? 'Stop',
                      subtitle: s.subtitle,
                      timeLabel: s.timeLabel,
                      iconName: s.iconName,
                    ))
                .toList(growable: false),
          ))
      .toList(growable: false);
});

/// Activity feed
final profileActivityProvider =
    FutureProvider.autoDispose.family<List<ActivityEntry>, String>((ref, userId) async {
  final api = ref.watch(profileApiProvider);
  final list = await api.getActivity(userId: userId, page: 1, limit: 50);
  return list
      .map((a) => ActivityEntry(
            id: a.id,
            type: a.type ?? 'event',
            title: a.title ?? '',
            subtitle: a.subtitle ?? '',
            timestamp: a.timestamp ?? DateTime.now(),
            thumbnailUrl: a.thumbnailUrl,
            targetId: a.targetId,
            targetType: a.targetType,
          ))
      .toList(growable: false);
});

/// Combined bundle (load in parallel, preserve strong types)
final profileBundleProvider =
    FutureProvider.autoDispose.family<ProfileBundle, String>((ref, userId) async {
  final identityF = ref.watch(profileIdentityProvider(userId).future);
  final countsF = ref.watch(profileCountsProvider(userId).future);
  final travelF = ref.watch(travelStatsProvider(userId).future);
  final visitedF = ref.watch(visitedPlacesProvider(userId).future);
  final contribPlacesF = ref.watch(contributionPlacesProvider(userId).future);
  final contribReviewsF = ref.watch(contributionReviewsProvider(userId).future);
  final contribPhotosF = ref.watch(contributionPhotosProvider(userId).future);
  final journeysF = ref.watch(profileJourneysProvider(userId).future);
  final activityF = ref.watch(profileActivityProvider(userId).future);

  // Await each future for type safety, instead of downcasting from a heterogeneous List.
  final identity = await identityF;
  final counts = await countsF;
  final travel = await travelF;
  final visited = await visitedF;
  final contribPlaces = await contribPlacesF;
  final contribReviews = await contribReviewsF;
  final contribPhotos = await contribPhotosF;
  final journeys = await journeysF;
  final activity = await activityF;

  return ProfileBundle(
    identity: identity,
    counts: counts,
    travel: travel,
    visitedPlaces: visited,
    contribPlaces: contribPlaces,
    contribReviews: contribReviews,
    contribPhotos: contribPhotos,
    journeys: journeys,
    activity: activity,
  );
}); // Avoids unsafe casts from Future.wait with heterogenous types; uses typed awaits instead.

/// ----------------------------
/// Refresh-all helper
/// ----------------------------

class ProfileRefresher {
  const ProfileRefresher(this.ref, this.userId);
  final Ref ref;
  final String userId;

  /// Invalidate all profile providers for a user to force fresh loads.
  void refreshAll() {
    ref.invalidate(profileIdentityProvider(userId));
    ref.invalidate(profileCountsProvider(userId));
    ref.invalidate(travelStatsProvider(userId));
    ref.invalidate(visitedPlacesProvider(userId));
    ref.invalidate(contributionPlacesProvider(userId));
    ref.invalidate(contributionReviewsProvider(userId));
    ref.invalidate(contributionPhotosProvider(userId));
    ref.invalidate(profileJourneysProvider(userId));
    ref.invalidate(profileActivityProvider(userId));
    ref.invalidate(profileBundleProvider(userId));
  }
}

final profileRefresherProvider =
    Provider.autoDispose.family<ProfileRefresher, String>((ref, userId) {
  return ProfileRefresher(ref, userId);
});
