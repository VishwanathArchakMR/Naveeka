// lib/core/config/constants.dart

import 'package:meta/meta.dart';

import 'app_config.dart';

/// App-wide constants, grouped by domain and safe to import anywhere. [7]
@immutable
class AppConstants {
  const AppConstants._();

  // -------- App --------
  static const String appName = 'Naveeka'; // consistent with App title

  // -------- API base segments (joined via ApiPath below) --------
  static const String apiV1 = '/api';
  static const String apiAuth = '$apiV1/auth';
  static const String apiUsers = '$apiV1/users';
  static const String apiPlaces = '$apiV1/places';
  static const String apiWishlist = '$apiV1/wishlist';
  static const String apiBookings = '$apiV1/bookings';
  static const String apiHotels = '$apiV1/hotels';
  static const String apiRestaurants = '$apiV1/restaurants';
  static const String apiActivities = '$apiV1/activities';
  static const String apiFlights = '$apiV1/flights';
  static const String apiTrains = '$apiV1/trains';
  static const String apiBuses = '$apiV1/buses';
  static const String apiCabs = '$apiV1/cabs';

  // -------- Auth endpoints (relative) --------
  static const String endpointRegister = '$apiAuth/register';
  static const String endpointLogin = '$apiAuth/login';
  static const String endpointMe = '$apiAuth/me';
  static const String endpointProfile = '$apiAuth/profile';
  static const String endpointPassword = '$apiAuth/password';

  // -------- Admin / actions (relative) --------
  static const String endpointDashboardStats = '$apiUsers/dashboard/stats';
  static const String endpointApprovePlace = '$apiPlaces/{id}/approve';

  // -------- UI spacing / shapes / motion --------
  static const double paddingXS = 8.0;
  static const double paddingSM = 12.0;
  static const double padding = 16.0;
  static const double paddingLG = 20.0;
  static const double paddingXL = 24.0;

  static const double radiusSM = 12.0;
  static const double radius = 16.0;
  static const double radiusLG = 20.0;
  static const double elevation = 2.0;

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration anim = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);
  static const Duration debounceFast = Duration(milliseconds: 200);
  static const Duration debounce = Duration(milliseconds: 300);

  // -------- Lists / pagination --------
  static const int pageSizeSmall = 10;
  static const int pageSize = 20;
  static const int pageSizeLarge = 50;

  // -------- Caching TTLs --------
  static const Duration ttlSeedData = Duration(days: 3);
  static const Duration ttlGeocode = Duration(days: 7);
  static const Duration ttlNearby = Duration(hours: 1);

  // -------- Location defaults --------
  static const double defaultNearbyRadiusKm = 5.0;
  static const double maxNearbyRadiusKm = 50.0;

  // -------- Domain: categories/emotions --------
  static const List<String> placeCategories = <String>[
    'Nature',
    'Adventure',
    'Heritage',
    'Stay',
    'Spiritual',
    'Wildlife',
    'Urban',
  ];

  // Emotions used by filters and search; keep strings for theme-decoupling.
  static const List<String> emotionOptions = <String>[
    'Calm',
    'Adventure',
    'Spiritual',
    'Romantic',
    'Family',
    'Solo',
    'Social',
  ];

  // -------- Common UI strings --------
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Check your connection.';
  static const String actionRetry = 'Retry';
  static const String actionApprove = 'Approve';
  static const String actionReject = 'Reject';
  static const String actionDelete = 'Delete';
}

/// Utility to build full API URLs from relative segments using AppConfig.current.apiBaseUrl. [9][12]
@immutable
class ApiPath {
  const ApiPath._();

  static String _join(String segment) {
    final base = AppConfig.current.apiBaseUrl; // configured at bootstrap
    if (segment.isEmpty) return base;
    // Avoid duplicate slashes.
    final needsSlash = !base.endsWith('/') && !segment.startsWith('/');
    return needsSlash ? '$base$segment' : '$base$segment';
  }

  // ----- Auth -----
  static String login() => _join(AppConstants.endpointLogin);
  static String register() => _join(AppConstants.endpointRegister);
  static String me() => _join(AppConstants.endpointMe);
  static String profile() => _join(AppConstants.endpointProfile);

  // ----- Users / Places -----
  static String userById(String id) => _join('${AppConstants.apiUsers}/$id');
  static String placeById(String id) => _join('${AppConstants.apiPlaces}/$id');
  static String approvePlace(String id) =>
      _join(AppConstants.endpointApprovePlace.replaceFirst('{id}', id));

  // ----- Search/list helpers -----
  static String places() => _join(AppConstants.apiPlaces);
  static String hotels() => _join(AppConstants.apiHotels);
  static String restaurants() => _join(AppConstants.apiRestaurants);
  static String activities() => _join(AppConstants.apiActivities);
  static String flights() => _join(AppConstants.apiFlights);
  static String trains() => _join(AppConstants.apiTrains);
  static String buses() => _join(AppConstants.apiBuses);
  static String cabs() => _join(AppConstants.apiCabs);

  // ----- Bookings -----
  static String bookings() => _join(AppConstants.apiBookings);
  static String bookingById(String id) => _join('${AppConstants.apiBookings}/$id');
}
