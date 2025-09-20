// lib/app/router.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Screens - Auth
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';

// Screens - Profile
import '../features/profile/presentation/profile_screen.dart';

// Screens - Main App
import '../features/splash/presentation/splash_screen.dart';
import '../ui/components/common/bottom_navigation.dart';

// Screens - Home & Quick Actions
import '../features/home/presentation/home_screen.dart';

// Update these imports to match actual files/classes if different.
import '../features/quick_actions/presentation/booking/booking_screen.dart'; // class BookingPage or BookingScreen
import '../features/quick_actions/presentation/history/history_screen.dart';
import '../features/quick_actions/presentation/favorites/favorites_screen.dart';
import '../features/quick_actions/presentation/following/following_screen.dart';
import '../features/quick_actions/presentation/planning/planning_screen.dart';
import '../features/quick_actions/presentation/planning/trip_group_screen.dart';
import '../features/quick_actions/presentation/messages/messages_screen.dart';

// Screens - Places
import '../features/places/presentation/place_detail_screen.dart';

// Screens - Trails
import '../features/trails/presentation/trails_screen.dart';

// Screens - Atlas
import '../features/atlas/presentation/atlas_screen.dart';

// Screens - Journey
import '../features/journey/presentation/journey_screen.dart';
import '../features/journey/presentation/flights/flight_search_screen.dart';
import '../features/journey/presentation/flights/flight_results_screen.dart';
import '../features/journey/presentation/flights/flight_booking_screen.dart';
import '../features/journey/presentation/trains/train_search_screen.dart';
import '../features/journey/presentation/trains/train_results_screen.dart';
import '../features/journey/presentation/hotels/hotel_search_screen.dart';
import '../features/journey/presentation/hotels/hotel_results_screen.dart';
import '../features/journey/presentation/restaurants/restaurant_search_screen.dart';
import '../features/journey/presentation/restaurants/restaurant_results_screen.dart';
import '../features/journey/presentation/activities/activity_search_screen.dart';
import '../features/journey/presentation/activities/activity_results_screen.dart';
import '../features/journey/presentation/bookings/my_bookings_screen.dart';

// Screens - Navee AI
import '../features/navee_ai/presentation/navee_ai_screen.dart';

// Screens - Settings
import '../features/settings/presentation/settings_screen.dart';

// Screens - Checkout
import '../features/checkout/presentation/checkout_screen.dart';

// Auth state
import '../features/auth/providers/auth_providers.dart';

// Navee AI providers
import '../features/navee_ai/providers/navee_ai_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authSimpleProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(ref.read(authStreamProvider)),
    routes: [
      // SPLASH
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _fade(const SplashScreen()),
      ),

      // AUTH
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _fade(const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => _fade(const RegisterScreen()),
      ),

      // MAIN SHELL
      ShellRoute(
        builder: (context, state, child) => BottomNavigationShell(child: child),
        routes: [
          // HOME TAB
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => _noTransition(const HomeScreen()),
            routes: [
              // Quick Actions
              GoRoute(
                path: 'booking',
                name: 'booking',
                // If BookingScreen exists, use it; otherwise switch to BookingPage wrapper.
                pageBuilder: (context, state) => _slideUp(const BookingScreen()),
              ),
              GoRoute(
                path: 'history',
                name: 'history',
                pageBuilder: (context, state) => _slideUp(const HistoryScreen()),
              ),
              GoRoute(
                path: 'favorites',
                name: 'favorites',
                pageBuilder: (context, state) => _slideUp(const FavoritesScreen()),
              ),
              GoRoute(
                path: 'following',
                name: 'following',
                pageBuilder: (context, state) => _slideUp(const FollowingScreen()),
              ),
              GoRoute(
                path: 'planning',
                name: 'planning',
                pageBuilder: (context, state) => _slideUp(const PlanningScreen()),
                routes: [
                  GoRoute(
                    path: 'trip/:id',
                    name: 'trip_group',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final title = state.uri.queryParameters['title'] ?? 'Trip Group';
                      return _slideUp(TripGroupScreen(groupId: id, groupTitle: title));
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'messages',
                name: 'messages',
                pageBuilder: (context, state) => _slideUp(const MessagesScreen()),
              ),
            ],
          ),

          // TRAILS TAB
          GoRoute(
            path: '/trails',
            name: 'trails',
            pageBuilder: (context, state) => _noTransition(const TrailsScreen()),
          ),

          // ATLAS TAB
          GoRoute(
            path: '/atlas',
            name: 'atlas',
            pageBuilder: (context, state) => _noTransition(const AtlasScreen()),
          ),

          // JOURNEY TAB
          GoRoute(
            path: '/journey',
            name: 'journey',
            pageBuilder: (context, state) => _noTransition(const JourneyScreen()),
            routes: [
              GoRoute(
                path: 'flights',
                name: 'flight_search',
                pageBuilder: (context, state) => _slideRight(const FlightSearchScreen()),
                routes: [
                  GoRoute(
                    path: 'results',
                    name: 'flight_results',
                    pageBuilder: (context, state) {
                      final qp = state.uri.queryParameters;
                      final from = qp['from'] ?? '';
                      final to = qp['to'] ?? '';
                      final date = qp['date'] ?? DateTime.now().toIso8601String();
                      return _slideRight(FlightResultsScreen(fromCode: from, toCode: to, date: date));
                    },
                    routes: [
                      GoRoute(
                        path: 'book/:id',
                        name: 'flight_booking',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final qp = state.uri.queryParameters;
                          final title = qp['title'] ?? 'Flight Booking';
                          final date = qp['date'] ?? DateTime.now().toIso8601String();
                          return _slideUp(FlightBookingScreen(flightId: id, title: title, date: date));
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'trains',
                name: 'train_search',
                pageBuilder: (context, state) => _slideRight(const TrainSearchScreen()),
                routes: [
                  GoRoute(
                    path: 'results',
                    name: 'train_results',
                    pageBuilder: (context, state) {
                      final qp = state.uri.queryParameters;
                      final from = qp['from'] ?? '';
                      final to = qp['to'] ?? '';
                      final dateIso = qp['date'] ?? DateTime.now().toIso8601String();
                      return _slideRight(TrainResultsScreen(fromCode: from, toCode: to, dateIso: dateIso));
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'hotels',
                name: 'hotel_search',
                pageBuilder: (context, state) => _slideRight(const HotelSearchScreen()),
                routes: [
                  GoRoute(
                    path: 'results',
                    name: 'hotel_results',
                    pageBuilder: (context, state) {
                      final qp = state.uri.queryParameters;
                      final destination = qp['destination'] ?? '';
                      final checkInIso = qp['checkIn'] ?? DateTime.now().toIso8601String();
                      final checkOutIso = qp['checkOut'] ?? DateTime.now().add(const Duration(days: 1)).toIso8601String();
                      return _slideRight(HotelResultsScreen(destination: destination, checkInIso: checkInIso, checkOutIso: checkOutIso));
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'restaurants',
                name: 'restaurant_search',
                pageBuilder: (context, state) => _slideRight(const RestaurantSearchScreen()),
                routes: [
                  GoRoute(
                    path: 'results',
                    name: 'restaurant_results',
                    pageBuilder: (context, state) {
                      final qp = state.uri.queryParameters;
                      final destination = qp['destination'] ?? '';
                      return _slideRight(RestaurantResultsScreen(destination: destination));
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'activities',
                name: 'activity_search',
                pageBuilder: (context, state) => _slideRight(const ActivitySearchScreen()),
                routes: [
                  GoRoute(
                    path: 'results',
                    name: 'activity_results',
                    pageBuilder: (context, state) => _slideRight(const ActivityResultsScreen()),
                  ),
                ],
              ),
              GoRoute(
                path: 'my-bookings',
                name: 'my_bookings',
                pageBuilder: (context, state) => _slideRight(const MyBookingsScreen()),
              ),
            ],
          ),

          // NAVEE.AI TAB
          GoRoute(
            path: '/navee-ai',
            name: 'navee_ai',
            pageBuilder: (context, state) {
              return _noTransition(NaveeAiScreen(api: ref.read(naveeAiApiProvider)));
            },
          ),
        ],
      ),

      // UNIVERSAL PLACE DETAIL
      GoRoute(
        path: '/place/:id',
        name: 'place_detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _slideUp(PlaceDetailScreen(placeId: id));
        },
      ),

      // SETTINGS & PROFILE
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => _slideRight(const SettingsScreen()),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final name = qp['name'] ?? 'Profile';
          return _slideRight(ProfileScreen(name: name));
        },
      ),

      // CHECKOUT
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _slideUp(CheckoutScreen(bookingData: extra));
        },
      ),
    ],

    redirect: (context, state) {
      final isLoading = auth.isLoading;
      final isLoggedIn = auth.isLoggedIn;

      final isSplash = state.matchedLocation == '/splash';
      final isAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (isSplash) return null;
      if (isLoading) return '/splash';
      if (!isLoggedIn) return isAuth ? null : '/login';
      if (isLoggedIn && isAuth) return '/home';
      return null;
    },
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

CustomTransitionPage _noTransition(Widget child) {
  return CustomTransitionPage(
    transitionDuration: Duration.zero,
    child: child,
    transitionsBuilder: (context, animation, secondary, widget) => widget,
  );
}

CustomTransitionPage _fade(Widget child) {
  return CustomTransitionPage(
    transitionDuration: const Duration(milliseconds: 300),
    child: child,
    transitionsBuilder: (context, animation, secondary, widget) {
      return FadeTransition(opacity: animation, child: widget);
    },
  );
}

CustomTransitionPage _slideUp(Widget child) {
  return CustomTransitionPage(
    transitionDuration: const Duration(milliseconds: 380),
    child: child,
    transitionsBuilder: (context, animation, secondary, widget) {
      final tween = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: widget);
    },
  );
}

CustomTransitionPage _slideRight(Widget child) {
  return CustomTransitionPage(
    transitionDuration: const Duration(milliseconds: 350),
    child: child,
    transitionsBuilder: (context, animation, secondary, widget) {
      final tween = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: widget);
    },
  );
}
