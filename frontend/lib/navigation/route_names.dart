// lib/navigation/route_names.dart

/// Centralized route names used with go_router's goNamed/pushNamed. [1]
class RouteNames {
  RouteNames._(); // no instances

  // ---------- AUTH & SPLASH ----------
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';

  // ---------- MAIN TABS ----------
  static const String home = 'home';
  static const String trails = 'trails';
  static const String atlas = 'atlas';
  static const String journey = 'journey';
  static const String naveeAI = 'navee_ai';

  // ---------- HOME QUICK ACTIONS ----------
  static const String booking = 'booking';
  static const String history = 'history';
  static const String favorites = 'favorites';
  static const String following = 'following';
  static const String planning = 'planning';
  static const String tripGroup = 'trip_group';
  static const String messages = 'messages';

  // ---------- JOURNEY BOOKING FLOWS ----------
  // Flights
  static const String flightSearch = 'flight_search';
  static const String flightResults = 'flight_results';
  static const String flightBooking = 'flight_booking';

  // Trains
  static const String trainSearch = 'train_search';
  static const String trainResults = 'train_results';
  static const String trainBooking = 'train_booking';

  // Buses
  static const String busSearch = 'bus_search';
  static const String busResults = 'bus_results';
  static const String busBooking = 'bus_booking';

  // Cabs
  static const String cabSearch = 'cab_search';
  static const String cabOptions = 'cab_options';
  static const String cabBooking = 'cab_booking';

  // Hotels
  static const String hotelSearch = 'hotel_search';
  static const String hotelResults = 'hotel_results';
  static const String hotelBooking = 'hotel_booking';

  // Restaurants
  static const String restaurantSearch = 'restaurant_search';
  static const String restaurantResults = 'restaurant_results';
  static const String restaurantBooking = 'restaurant_booking';

  // Activities
  static const String activitySearch = 'activity_search';
  static const String activityResults = 'activity_results';
  static const String activityBooking = 'activity_booking';

  // Places
  static const String placeSearch = 'place_search';
  static const String placeResults = 'place_results';
  static const String placeBooking = 'place_booking';

  // My Bookings
  static const String myBookings = 'my_bookings';

  // ---------- UNIVERSAL SCREENS ----------
  static const String placeDetail = 'place_detail';
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String checkout = 'checkout';
}

/// Centralized paths for go_router route path configuration and manual linking. [4]
class RoutePaths {
  RoutePaths._(); // no instances

  // ---------- AUTH & SPLASH ----------
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';

  // ---------- MAIN TABS ----------
  static const String home = '/home';
  static const String trails = '/trails';
  static const String atlas = '/atlas';
  static const String journey = '/journey';
  static const String naveeAI = '/navee-ai';

  // ---------- HOME QUICK ACTIONS ----------
  static const String booking = '/home/booking';
  static const String history = '/home/history';
  static const String favorites = '/home/favorites';
  static const String following = '/home/following';
  static const String planning = '/home/planning';
  static const String tripGroup = '/home/planning/trip';
  static const String messages = '/home/messages';

  // ---------- JOURNEY BOOKING FLOWS ----------
  // Flights
  static const String flightSearch = '/journey/flights';
  static const String flightResults = '/journey/flights/results';
  static const String flightBooking = '/journey/flights/results/book';

  // Trains
  static const String trainSearch = '/journey/trains';
  static const String trainResults = '/journey/trains/results';
  static const String trainBooking = '/journey/trains/results/book';

  // Buses
  static const String busSearch = '/journey/buses';
  static const String busResults = '/journey/buses/results';
  static const String busBooking = '/journey/buses/results/book';

  // Cabs
  static const String cabSearch = '/journey/cabs';
  static const String cabOptions = '/journey/cabs/options';
  static const String cabBooking = '/journey/cabs/options/book';

  // Hotels
  static const String hotelSearch = '/journey/hotels';
  static const String hotelResults = '/journey/hotels/results';
  static const String hotelBooking = '/journey/hotels/results/book';

  // Restaurants
  static const String restaurantSearch = '/journey/restaurants';
  static const String restaurantResults = '/journey/restaurants/results';
  static const String restaurantBooking = '/journey/restaurants/results/book';

  // Activities
  static const String activitySearch = '/journey/activities';
  static const String activityResults = '/journey/activities/results';
  static const String activityBooking = '/journey/activities/results/book';

  // Places
  static const String placeSearch = '/journey/places';
  static const String placeResults = '/journey/places/results';
  static const String placeBooking = '/journey/places/results/book';

  // My Bookings
  static const String myBookings = '/journey/my-bookings';

  // ---------- UNIVERSAL SCREENS ----------
  // place_detail is typically configured as '/place/:id' with a named route [1]
  static const String placeDetail = '/place';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String checkout = '/checkout';

  // ---------- HELPERS ----------
  static String placeDetailWithId(String placeId) => '$placeDetail/$placeId';
  static String tripGroupWithId(String tripId) => '$tripGroup/$tripId';
  static String flightBookingWithId(String flightId) => '$flightBooking/$flightId';
  static String hotelBookingWithId(String hotelId) => '$hotelBooking/$hotelId';
  static String restaurantBookingWithId(String restaurantId) => '$restaurantBooking/$restaurantId';
  static String activityBookingWithId(String activityId) => '$activityBooking/$activityId';
}

/// Common parameter keys for pathParameters and queryParameters with go_router. [1][7]
class RouteParams {
  RouteParams._(); // no instances

  // Path parameters (used with state.pathParameters and pushNamed/goNamed) [1]
  static const String id = 'id';
  static const String placeId = 'id';
  static const String tripId = 'id';
  static const String flightId = 'id';
  static const String hotelId = 'id';
  static const String restaurantId = 'id';
  static const String activityId = 'id';

  // Query parameters (used with state.uri.queryParameters in newer go_router) [2][10]
  static const String q = 'q'; // universal search
  static const String from = 'from';
  static const String to = 'to';
  static const String date = 'date';
  static const String guests = 'guests';
  static const String budget = 'budget';

  // Atlas / Filters
  static const String region = 'region';
  static const String nearby = 'nearby';
  static const String trending = 'trending';
  static const String featured = 'featured';
  static const String emotion = 'emotion';
  static const String category = 'category';
  static const String sort = 'sort';
  static const String radius = 'radius';
  static const String openNow = 'openNow';
  static const String price = 'price';
  static const String rating = 'rating';

  // Map context
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String zoom = 'zoom';
}
