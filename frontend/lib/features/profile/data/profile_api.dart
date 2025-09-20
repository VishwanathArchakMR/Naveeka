// lib/features/profile/data/profile_api.dart

import 'package:dio/dio.dart';

import '../../../models/place.dart';
import '../providers/profile_providers.dart' show ProfileApi;

/// Concrete HTTP client for ProfileApi using Dio.
/// Inject this via an override of profileApiProvider at app bootstrap.
class ProfileApiHttp implements ProfileApi {
  ProfileApiHttp(
    this._dio, {
    required this.baseUrl,
    this.apiKey,
  });

  final Dio _dio;
  final String baseUrl;
  final String? apiKey;

  Map<String, String> get _headers => {
        'accept': 'application/json',
        if (apiKey != null && apiKey!.trim().isNotEmpty) 'x-api-key': apiKey!.trim(),
      };

  // -------- Identity / Counts / Travel --------

  @override
  Future<IdentityDto> getIdentity({required String userId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/identity',
      options: Options(headers: _headers),
    );
    return IdentityDto.fromJson(resp.data ?? const <String, dynamic>{});
  }

  @override
  Future<CountsDto> getCounts({required String userId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/counts',
      options: Options(headers: _headers),
    );
    return CountsDto.fromJson(resp.data ?? const <String, dynamic>{});
  }

  @override
  Future<TravelStatsDto> getTravelStats({required String userId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/travel',
      options: Options(headers: _headers),
    );
    return TravelStatsDto.fromJson(resp.data ?? const <String, dynamic>{});
  }

  // -------- Places (visited / contributed) --------

  @override
  Future<List<Place>> getVisitedPlaces({required String userId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/places/visited',
      options: Options(headers: _headers),
    );
    final list = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return list;
  }

  @override
  Future<List<Place>> getContributionPlaces({
    required String userId,
    required int page,
    required int limit,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/places/contributed',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      options: Options(headers: _headers),
    );
    final list = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return list;
  }

  // -------- Contributions (reviews / photos) --------

  @override
  Future<List<ContributionReviewDto>> getContributionReviews({
    required String userId,
    required int page,
    required int limit,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/reviews',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      options: Options(headers: _headers),
    );
    final items = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => ContributionReviewDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return items;
  }

  @override
  Future<List<String>> getContributionPhotos({
    required String userId,
    required int page,
    required int limit,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/photos',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      options: Options(headers: _headers),
    );
    final items = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    return items;
  }

  // -------- Journeys / Activity --------

  @override
  Future<List<JourneyApiDto>> getJourneys({
    required String userId,
    required int page,
    required int limit,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/journeys',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      options: Options(headers: _headers),
    );
    final items = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => JourneyApiDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return items;
  }

  @override
  Future<List<ActivityApiDto>> getActivity({
    required String userId,
    required int page,
    required int limit,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/$userId/activity',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      options: Options(headers: _headers),
    );
    final items = ((resp.data?['items'] as List?) ?? const <Object>[])
        .map((e) => ActivityApiDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return items;
  }
}

// ---------------- DTOs returned by ProfileApiHttp ----------------

class IdentityDto {
  const IdentityDto({
    required this.name,
    this.username,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.location,
    this.joinedOn,
    this.verified,
  });

  final String name;
  final String? username;
  final String? headline;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? location;
  final DateTime? joinedOn;
  final bool? verified;

  factory IdentityDto.fromJson(Map<String, dynamic> j) {
    return IdentityDto(
      name: (j['name'] ?? '').toString(),
      username: j['username']?.toString(),
      headline: j['headline']?.toString(),
      bio: j['bio']?.toString(),
      avatarUrl: j['avatarUrl']?.toString(),
      coverUrl: j['coverUrl']?.toString(),
      location: j['location']?.toString(),
      joinedOn: (j['joinedOn'] != null) ? DateTime.tryParse(j['joinedOn'].toString()) : null,
      verified: j['verified'] as bool?,
    );
  }
}

class CountsDto {
  const CountsDto({
    this.places,
    this.reviews,
    this.photos,
    this.followers,
    this.following,
    this.journeys,
  });

  final int? places;
  final int? reviews;
  final int? photos;
  final int? followers;
  final int? following;
  final int? journeys;

  factory CountsDto.fromJson(Map<String, dynamic> j) {
    return CountsDto(
      places: (j['places'] as num?)?.toInt(),
      reviews: (j['reviews'] as num?)?.toInt(),
      photos: (j['photos'] as num?)?.toInt(),
      followers: (j['followers'] as num?)?.toInt(),
      following: (j['following'] as num?)?.toInt(),
      journeys: (j['journeys'] as num?)?.toInt(),
    );
  }
}

class TravelStatsDto {
  const TravelStatsDto({
    this.totalDistanceKm,
    this.totalDays,
    this.totalTrips,
    this.countries,
    this.cities,
    this.continentCounts = const <String, int>{},
    this.transportMix = const <String, double>{},
  });

  final double? totalDistanceKm;
  final int? totalDays;
  final int? totalTrips;
  final int? countries;
  final int? cities;
  final Map<String, int> continentCounts;
  final Map<String, double> transportMix;

  factory TravelStatsDto.fromJson(Map<String, dynamic> j) {
    final ccRaw = j['continentCounts'];
    final tmRaw = j['transportMix'];
    return TravelStatsDto(
      totalDistanceKm: (j['totalDistanceKm'] as num?)?.toDouble(),
      totalDays: (j['totalDays'] as num?)?.toInt(),
      totalTrips: (j['totalTrips'] as num?)?.toInt(),
      countries: (j['countries'] as num?)?.toInt(),
      cities: (j['cities'] as num?)?.toInt(),
      continentCounts: (ccRaw is Map)
          ? ccRaw.map<String, int>((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : const <String, int>{},
      transportMix: (tmRaw is Map)
          ? tmRaw.map<String, double>((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          : const <String, double>{},
    );
  }
}

class ContributionReviewDto {
  const ContributionReviewDto({required this.id, this.title, this.subtitle});

  final String id;
  final String? title;
  final String? subtitle;

  factory ContributionReviewDto.fromJson(Map<String, dynamic> j) {
    return ContributionReviewDto(
      id: (j['id'] ?? '').toString(),
      title: j['title']?.toString(),
      subtitle: j['subtitle']?.toString(),
    );
  }
}

class JourneyStopApiDto {
  const JourneyStopApiDto({required this.title, this.subtitle, this.timeLabel, this.iconName});

  final String title;
  final String? subtitle;
  final String? timeLabel;
  final String? iconName;

  factory JourneyStopApiDto.fromJson(Map<String, dynamic> j) {
    return JourneyStopApiDto(
      title: (j['title'] ?? '').toString(),
      subtitle: j['subtitle']?.toString(),
      timeLabel: j['timeLabel']?.toString(),
      iconName: j['iconName']?.toString(),
    );
  }
}

class JourneyApiDto {
  const JourneyApiDto({
    required this.id,
    required this.title,
    this.coverUrl,
    this.dateRange,
    this.days,
    this.places,
    this.distanceKm,
    this.stops = const <JourneyStopApiDto>[],
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? dateRange;
  final int? days;
  final int? places;
  final double? distanceKm;
  final List<JourneyStopApiDto> stops;

  factory JourneyApiDto.fromJson(Map<String, dynamic> j) {
    final stops = ((j['stops'] as List?) ?? const <Object>[])
        .map((e) => JourneyStopApiDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return JourneyApiDto(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? 'Journey').toString(),
      coverUrl: j['coverUrl']?.toString(),
      dateRange: j['dateRange']?.toString(),
      days: (j['days'] as num?)?.toInt(),
      places: (j['places'] as num?)?.toInt(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      stops: stops,
    );
  }
}

class ActivityApiDto {
  const ActivityApiDto({
    required this.id,
    this.type,
    this.title,
    this.subtitle,
    this.timestamp,
    this.thumbnailUrl,
    this.targetId,
    this.targetType,
  });

  final String id;
  final String? type;
  final String? title;
  final String? subtitle;
  final DateTime? timestamp;
  final String? thumbnailUrl;
  final String? targetId;
  final String? targetType;

  factory ActivityApiDto.fromJson(Map<String, dynamic> j) {
    return ActivityApiDto(
      id: (j['id'] ?? '').toString(),
      type: j['type']?.toString(),
      title: j['title']?.toString(),
      subtitle: j['subtitle']?.toString(),
      timestamp: (j['timestamp'] != null) ? DateTime.tryParse(j['timestamp'].toString()) : null,
      thumbnailUrl: j['thumbnailUrl']?.toString(),
      targetId: j['targetId']?.toString(),
      targetType: j['targetType']?.toString(),
    );
  }
}
