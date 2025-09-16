// lib/features/home/providers/home_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/constants.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/location_cache.dart';
import '../data/home_api.dart';
import '../data/location_home_api.dart';

/// DI for HomeApi (single-entity endpoints). [Riverpod Provider] [4]
final homeApiProvider = Provider<HomeApi>((ref) => HomeApi());

/// DI for LocationHomeApi (parallel aggregations). [Riverpod Provider] [4]
final locationHomeApiProvider = Provider<LocationHomeApi>(
  (ref) => LocationHomeApi(homeApi: ref.read(homeApiProvider)),
);

/// Parameters for nearby bundle queries. [Family pattern] [6]
class GeoParams {
  final double lat;
  final double lng;
  final double radiusKm;
  final int limit;
  final List<String>? categories;

  const GeoParams({
    required this.lat,
    required this.lng,
    this.radiusKm = AppConstants.defaultNearbyRadiusKm,
    this.limit = AppConstants.pageSize,
    this.categories,
  });
}

/// Location-based bundle: nearby places/hotels/restaurants, trending, top hotels, what's new. [FutureProvider.family] [6]
final nearHomeBundleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, GeoParams>((ref, p) async {
  final api = ref.read(locationHomeApiProvider);
  final res = await api.fetchNearBundle(
    lat: p.lat,
    lng: p.lng,
    radiusKm: p.radiusKm,
    limit: p.limit,
    categories: p.categories,
  );
  return res.fold(
    onSuccess: (data) => data,
    onError: (e) => throw e,
  );
});

/// Region-focused bundle for when GPS is unavailable (explore region + trending + what's new). [FutureProvider.family] [6]
final regionHomeBundleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, region) async {
  final api = ref.read(locationHomeApiProvider);
  final res =
      await api.fetchRegionBundle(region: region, limit: AppConstants.pageSize);
  return res.fold(
    onSuccess: (data) => data,
    onError: (e) => throw e,
  );
});

/// Nearby places list with geo filters (independent list usage). [FutureProvider.family] [6]
final nearbyPlacesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, GeoParams>((ref, p) async {
  final api = ref.read(homeApiProvider);
  final res = await api.nearbyPlaces(
    lat: p.lat,
    lng: p.lng,
    radiusKm: p.radiusKm,
    limit: p.limit,
    categories: p.categories,
  );
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// Nearby hotels list. [FutureProvider.family] [6]
final nearbyHotelsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, GeoParams>((ref, p) async {
  final api = ref.read(homeApiProvider);
  final res = await api.nearbyHotels(
    lat: p.lat,
    lng: p.lng,
    radiusKm: p.radiusKm,
    limit: p.limit,
  );
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// Nearby restaurants list. [FutureProvider.family] [6]
final nearbyRestaurantsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, GeoParams>((ref, p) async {
  final api = ref.read(homeApiProvider);
  final res = await api.nearbyRestaurants(
    lat: p.lat,
    lng: p.lng,
    radiusKm: p.radiusKm,
    limit: p.limit,
  );
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// Trending places, optionally location-biased. [FutureProvider.family] [6]
class TrendingParams {
  final double? lat;
  final double? lng;
  final int limit;
  const TrendingParams(
      {this.lat, this.lng, this.limit = AppConstants.pageSize});
}

final trendingPlacesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, TrendingParams>((ref, p) async {
  final api = ref.read(homeApiProvider);
  final res = await api.trendingPlaces(lat: p.lat, lng: p.lng, limit: p.limit);
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// What's new (recently added places). [FutureProvider] [12]
final whatsNewProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(homeApiProvider);
  final res = await api.whatsNew(limit: AppConstants.pageSize);
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// Explore by region (for category tabs/filters). [FutureProvider.family] [6]
final exploreByRegionProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, region) async {
  final api = ref.read(homeApiProvider);
  final res =
      await api.exploreByRegion(region: region, limit: AppConstants.pageSize);
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
});

/// Last known location with TTL; UI can react with LocationBanner/DistanceIndicator. [Local caching] [13]
final lastLocationProvider =
    FutureProvider.autoDispose<LocationSnapshot?>((ref) async {
  // TTL aligns with nearby freshness window from constants; adjust if needed.
  return LocationCache.instance.getLast(maxAge: AppConstants.ttlNearby);
});

/// Convenience provider: choose near-bundle if recent location exists, else region bundle. [AsyncValue flow] [20]
final homeBootstrapProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final last = await ref.watch(lastLocationProvider.future);
  if (last != null) {
    final geo = GeoParams(
      lat: last.latitude,
      lng: last.longitude,
      radiusKm: AppConstants.defaultNearbyRadiusKm,
      limit: AppConstants.pageSize,
    );
    return await ref.watch(nearHomeBundleProvider(geo).future);
  } else {
    // Fallback region; replace with device locale region or a saved preference as needed.
    return await ref.watch(regionHomeBundleProvider('India').future);
  }
});

/// Helper to convert ApiResult to AsyncValue-friendly behavior when composing custom flows. [Result pattern] [22]
extension ApiResultX<T> on ApiResult<T> {
  T requireData() {
    return fold(
      onSuccess: (v) => v,
      onError: (e) => throw e,
    );
  }
}
