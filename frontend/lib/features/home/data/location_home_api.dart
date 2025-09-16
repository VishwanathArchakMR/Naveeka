// lib/features/home/data/location_home_api.dart

import '../../../core/network/api_result.dart';
import 'home_api.dart';

/// Aggregates multiple home sections in parallel for a fast, location-aware load. [1]
class LocationHomeApi {
  LocationHomeApi({HomeApi? homeApi}) : _home = homeApi ?? HomeApi();

  final HomeApi _home;

  /// Fetches a bundled payload for the Home screen based on location:
  /// nearby places/hotels/restaurants, trending places (location-biased), top hotels, and what's new. [12]
  Future<ApiResult<Map<String, dynamic>>> fetchNearBundle({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    int limit = 20,
    List<String>? categories, // optional filter for nearby places
  }) {
    return ApiResult.guardFuture(() async {
      // Kick off independent requests concurrently. [1]
      final futures = await Future.wait([
        _home.nearbyPlaces(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          limit: limit,
          categories: categories,
        ),
        _home.nearbyHotels(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          limit: limit,
        ),
        _home.nearbyRestaurants(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          limit: limit,
        ),
        _home.trendingPlaces(
          lat: lat,
          lng: lng,
          limit: limit,
        ),
        _home.topHotelsNear(
          lat: lat,
          lng: lng,
          limit: limit,
        ),
        _home.whatsNew(
          limit: limit,
        ),
      ]);

      // Unpack each ApiResult, collecting partial errors but not failing the whole bundle. [21]
      final errors = <String>[];
      List<Map<String, dynamic>> asList(dynamic v) => v is List ? List<Map<String, dynamic>>.from(v) : const [];

      List<Map<String, dynamic>> _okOrEmpty(ApiResult<List<Map<String, dynamic>>> r, String key) {
        return r.fold(
          onSuccess: (list) => list,
          onError: (e) {
            errors.add('$key: ${e.safeMessage}');
            return const <Map<String, dynamic>>[];
          },
        );
      }

      final nearbyPlacesRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final nearbyHotelsRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final nearbyRestaurantsRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final trendingPlacesRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final topHotelsRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final whatsNewRes = futures as ApiResult<List<Map<String, dynamic>>>;

      final payload = <String, dynamic>{
        'nearbyPlaces': _okOrEmpty(nearbyPlacesRes, 'nearbyPlaces'),
        'nearbyHotels': _okOrEmpty(nearbyHotelsRes, 'nearbyHotels'),
        'nearbyRestaurants': _okOrEmpty(nearbyRestaurantsRes, 'nearbyRestaurants'),
        'trendingPlaces': _okOrEmpty(trendingPlacesRes, 'trendingPlaces'),
        'topHotels': _okOrEmpty(topHotelsRes, 'topHotels'),
        'whatsNew': _okOrEmpty(whatsNewRes, 'whatsNew'),
        if (errors.isNotEmpty) 'errors': errors,
      };

      return payload;
    });
  }

  /// Region-focused bundle (non-GPS): explore by region plus trending and what's new to populate Home without location. [12]
  Future<ApiResult<Map<String, dynamic>>> fetchRegionBundle({
    required String region,
    int limit = 20,
  }) {
    return ApiResult.guardFuture(() async {
      // Run independent region-friendly calls concurrently. [1]
      final futures = await Future.wait([
        _home.exploreByRegion(region: region, limit: limit),
        _home.trendingPlaces(limit: limit),
        _home.whatsNew(limit: limit),
      ]);

      final errors = <String>[];

      List<Map<String, dynamic>> _okOrEmpty(ApiResult<List<Map<String, dynamic>>> r, String key) {
        return r.fold(
          onSuccess: (list) => list,
          onError: (e) {
            errors.add('$key: ${e.safeMessage}');
            return const <Map<String, dynamic>>[];
          },
        );
      }

      final exploreRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final trendingRes = futures as ApiResult<List<Map<String, dynamic>>>;
      final newRes = futures as ApiResult<List<Map<String, dynamic>>>;

      final payload = <String, dynamic>{
        'exploreByRegion': _okOrEmpty(exploreRes, 'exploreByRegion'),
        'trendingPlaces': _okOrEmpty(trendingRes, 'trendingPlaces'),
        'whatsNew': _okOrEmpty(newRes, 'whatsNew'),
        if (errors.isNotEmpty) 'errors': errors,
      };

      return payload;
    });
  }
}
