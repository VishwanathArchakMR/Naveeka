// lib/features/journey/providers/journey_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/hotels_api.dart';
import '../data/places_api.dart';
import '../data/restaurants_api.dart';
import '../data/trains_api.dart';

// Optional: used by StationSelector and other "nearby" features.
// If not present yet, comment this import and the provider using it.
import '../../core/storage/location_cache.dart';

// -------------------------------
// App-level settings & formatters
// -------------------------------

/// Global currency code/symbol (e.g., '₹' or '$').
final currencyProvider = StateProvider<String>((ref) => '₹');

/// Long date formatter (e.g., Jan 12, 2026).
final longDateFormatterProvider = Provider<DateFormat>((ref) => DateFormat.yMMMEd());

/// ISO date formatter (YYYY-MM-DD).
final isoDateFormatterProvider = Provider<DateFormat>((ref) => DateFormat('yyyy-MM-dd'));

// -------------------------------
// APIs as dependencies
// -------------------------------

/// Hotels API dependency (override for tests/mocks if needed).
final hotelsApiProvider = Provider<HotelsApi>((ref) => HotelsApi());

/// Places API dependency (override for tests/mocks if needed).
final placesApiProvider = Provider<PlacesApi>((ref) => PlacesApi());

/// Restaurants API dependency (override for tests/mocks if needed).
final restaurantsApiProvider = Provider<RestaurantsApi>((ref) => RestaurantsApi());

/// Trains API dependency (override for tests/mocks if needed).
final trainsApiProvider = Provider<TrainsApi>((ref) => TrainsApi());

// -------------------------------
// Location (last known, optional)
// -------------------------------

/// Last-known location snapshot (cached), or null if unavailable.
///
/// Returned shape:
/// { 'lat': double, 'lng': double, 'timestamp': DateTime }
final lastKnownLocationProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
    if (snap == null) return null;
    return {
      'lat': snap.latitude,
      'lng': snap.longitude,
      'timestamp': snap.timestamp,
    };
  } catch (_) {
    return null;
  }
});

// -------------------------------
// Recent searches (simple store)
// -------------------------------

/// A lightweight model for recent searches across modules.
class RecentSearch {
  const RecentSearch({
    required this.module, // 'Hotels' | 'Places' | 'Restaurants' | 'Trains' | 'Flights'
    required this.query,  // free-form, e.g., 'Bengaluru → Goa • 2025-11-18'
    this.params = const <String, dynamic>{},
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String module;
  final String query;
  final Map<String, dynamic> params;
  final DateTime at;
}

class RecentSearchesNotifier extends StateNotifier<List<RecentSearch>> {
  RecentSearchesNotifier() : super(const <RecentSearch>[]);

  /// Add/Promote a recent search (keeps unique by module+query, most recent first).
  void add(RecentSearch item, {int maxItems = 20}) {
    final next = [
      item,
      ...state.where((e) => !(e.module == item.module && e.query == item.query)),
    ];
    state = next.take(maxItems).toList(growable: false);
  }

  /// Remove by index (bounds-safe).
  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    state = next;
  }

  /// Clear all.
  void clear() => state = const <RecentSearch>[];
}

/// Notifier-backed store for recent searches across journey modules.
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<RecentSearch>>((ref) {
  return RecentSearchesNotifier();
});

// -------------------------------
// Suggested journeys (hook)
// -------------------------------

/// Repository hook that returns suggested journey payloads.
/// Override this with a real implementation at runtime/tests:
/// ProviderScope(overrides: [suggestedJourneysRepoProvider.overrideWithValue(myLoader)])
final suggestedJourneysRepoProvider =
    Provider<Future<List<Map<String, dynamic>>> Function()>((ref) {
  // Default: no suggestions loaded; replace/override with app logic.
  return () async => <Map<String, dynamic>>[];
});

/// Async provider exposing suggested journeys as normalized maps.
/// Each item includes:
/// { id, title, city, imageUrl, startDate (DateTime), endDate (DateTime),
///   flights (bool), hotels (bool), activitiesCount (int),
///   estimatedBudget (num?), currency (String), tags (List<String>) }
final suggestedJourneysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loader = ref.watch(suggestedJourneysRepoProvider);
  final list = await loader();
  // Basic normalization to avoid nulls on required fields.
  return list.map<Map<String, dynamic>>((m) {
    T? pick<T>(String k) => (m[k] is T) ? m[k] as T : null;
    DateTime? dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return {
      'id': (pick<String>('id') ?? '').toString(),
      'title': (pick<String>('title') ?? '').toString(),
      'city': (pick<String>('city') ?? '').toString(),
      'imageUrl': (pick<String>('imageUrl') ?? '').toString(),
      'startDate': dt(m['startDate']) ?? DateTime.now(),
      'endDate': dt(m['endDate']) ?? DateTime.now().add(const Duration(days: 2)),
      'flights': m['flights'] == true,
      'hotels': m['hotels'] == true,
      'activitiesCount': (m['activitiesCount'] is int) ? m['activitiesCount'] as int : 0,
      'estimatedBudget': m['estimatedBudget'] is num ? m['estimatedBudget'] as num : null,
      'currency': (pick<String>('currency') ?? '₹').toString(),
      'tags': (m['tags'] is List) ? List<String>.from(m['tags']) : const <String>[],
    };
  }).toList(growable: false);
});
