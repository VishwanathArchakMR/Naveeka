// lib/features/quick_actions/presentation/booking/booking_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Models
import '../../../../models/place.dart';

// Widgets in this feature
import 'widgets/booking_search_bar.dart';
import 'widgets/booking_location_filter.dart' as loc;
import 'widgets/booking_map_view.dart';
import 'widgets/suggested_bookings.dart';
import 'widgets/recent_bookings.dart';

// Shared types from Places feature (avoid redefining locally)
import '../../../places/presentation/widgets/distance_indicator.dart' as di show UnitSystem;
import '../../../places/presentation/widgets/nearby_places_map.dart' as maps show NearbyMapBuilder;

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    this.initialQuery = '',
    this.initialLocation,
    this.initialDateRange,
    this.initialGuests = 2,
    this.originLat,
    this.originLng,
    this.mapBuilder, // Optional: shared Google/Mapbox builder used across app
  });

  final String initialQuery;
  final loc.BookingLocationSelection? initialLocation;
  final DateTimeRange? initialDateRange;
  final int initialGuests;

  final double? originLat;
  final double? originLng;

  // If you use a shared NearbyMapBuilder (Google/Mapbox), inject it here
  final maps.NearbyMapBuilder? mapBuilder;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Query/filter state
  String _query = '';
  loc.BookingLocationSelection? _location;
  DateTimeRange? _dates;
  int _guests = 2;
  di.UnitSystem _unit = di.UnitSystem.metric;

  // Suggestions debounce
  Timer? _suggestDebounce;

  // Data (wire these to Riverpod providers / APIs in real app)
  bool _loading = false;
  final List<Place> _nearby = <Place>[]; // map + suggestions source
  final List<Place> _suggested = <Place>[]; // horizontal carousel
  final List<BookingRow> _recent = <BookingRow>[]; // recent bookings
  final bool _hasMoreRecent = false;

  // Auxiliary maps for booking info
  final Map<String, DateTime> _nextAvailable = <String, DateTime>{};
  final Map<String, String> _priceFrom = <String, String>{};

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _location = widget.initialLocation;
    _dates = widget.initialDateRange;
    _guests = widget.initialGuests;
    _unit = _location != null ? _toDiUnit(_location!.unit) : di.UnitSystem.metric;

    // Initial fetch
    _refresh();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      // Replace with provider-driven fetches (nearby, suggested, recent)
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Suggestions (replace with backend/autocomplete)
  Future<List<String>> _onSuggest(String q) async {
    _suggestDebounce?.cancel();
    final c = Completer<List<String>>();
    _suggestDebounce = Timer(const Duration(milliseconds: 150), () {
      final base = ['Breakfast', 'Lunch', 'Dinner', 'Cafe', 'Bar', 'Spa', 'Museum'];
      final res = base.where((e) => e.toLowerCase().contains(q.toLowerCase())).take(6).toList();
      c.complete(res);
    });
    return c.future;
  }

  // Adapter: map booking_location_filter.UnitSystem -> distance_indicator.UnitSystem
  di.UnitSystem _toDiUnit(loc.UnitSystem u) {
    return u == loc.UnitSystem.imperial ? di.UnitSystem.imperial : di.UnitSystem.metric;
  }

  // Location picker
  Future<loc.BookingLocationSelection?> _pickLocation() async {
    final sel = await loc.BookingLocationFilterSheet.show(
      context,
      initial: _location ??
          const loc.BookingLocationSelection(
            mode: loc.LocationMode.nearMe,
            radiusKm: 5,
            unit: loc.UnitSystem.metric,
          ),
      recentAddresses: const ['Bandra West, Mumbai', 'Koramangala, Bengaluru', 'Connaught Place, Delhi'],
      onResolveCurrentLocation: () async {
        // request geolocation permission and return device coords
        return const loc.GeoPoint(19.0896, 72.8656); // example: Mumbai
      },
      onPickOnMap: () async {
        // open your map picker and return pinned location
        return const loc.GeoPoint(19.1136, 72.8697);
      },
      minKm: 0.5,
      maxKm: 50,
    );
    if (sel == null) return null;
    setState(() {
      _location = sel;
      _unit = _toDiUnit(sel.unit);
    });
    await _refresh();
    return sel;
  }

  // Dates picker (Material)
  Future<DateTimeRange?> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dates ??
          DateTimeRange(
            start: now.add(const Duration(days: 1)),
            end: now.add(const Duration(days: 3)),
          ),
      saveText: 'Apply',
    );
    if (range != null) {
      setState(() => _dates = range);
      await _refresh();
    }
    return range;
  }

  // Guests picker (simple)
  Future<int?> _pickGuests() async {
    final res = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        int temp = _guests;
        return StatefulBuilder(
          builder: (context, setS) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Guests', style: TextStyle(fontWeight: FontWeight.w800))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: temp > 1 ? () => setS(() => temp--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$temp', style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        onPressed: () => setS(() => temp++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, temp),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (res != null) {
      setState(() => _guests = res);
      await _refresh();
    }
    return res;
  }

  // Booking action
  Future<void> _book(Place p) async {
    // call BookingApi.getQuote / createReservation or open partner link
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking: ${p.name}')),
    );
  }

  // Load more recent bookings
  Future<void> _loadMoreRecent() async {
    if (!_hasMoreRecent || _loading) return;
    setState(() => _loading = true);
    try {
      // fetch next page from BookingApi
      await Future.delayed(const Duration(milliseconds: 400));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Query change (SearchAnchor)
  void _onQueryChanged(String q) {
    setState(() => _query = q);
  }

  void _onSubmit(String q) async {
    setState(() => _query = q.trim());
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Screen uses CustomScrollView slivers for efficient, complex scrolling layout.
    final body = CustomScrollView(
      slivers: [
        // Header area
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: BookingSearchBar(
              query: _query,
              onQueryChanged: _onQueryChanged,
              onSubmitted: _onSubmit,
              onSuggest: _onSuggest,
              location: _location,
              onPickLocation: _pickLocation,
              dateRange: _dates,
              onPickDates: _pickDates,
              guests: _guests,
              onPickGuests: _pickGuests,
              onOpenFilters: _pickLocation, // open full filter as location sheet for now
            ),
          ),
        ),

        // Map view
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BookingMapView(
              places: _nearby,
              mapBuilder: widget.mapBuilder, // typed as maps.NearbyMapBuilder?
              originLat: widget.originLat,
              originLng: widget.originLng,
              onOpenFilters: _pickLocation,
              onOpenPlace: (p) {
                // navigate to details
              },
              onBook: _book,
              nextAvailableById: _nextAvailable,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Suggested bookings carousel
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SuggestedBookings(
              places: _suggested,
              originLat: widget.originLat,
              originLng: widget.originLng,
              unit: _unit, // di.UnitSystem
              onOpenPlace: (p) {
                // navigate
              },
              onBook: _book,
              onSeeAll: () {
                // push see-all list
              },
              nextAvailableById: _nextAvailable,
              priceFromById: _priceFrom,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Recent bookings list
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RecentBookings(
              items: _recent,
              loading: _loading,
              hasMore: _hasMoreRecent,
              onRefresh: _refresh,
              onLoadMore: _loadMoreRecent,
              onOpen: (row) {
                // open reservation details
              },
              onCancel: (row) async {
                // BookingApi.cancelReservation(row.reservationId)
                await Future.delayed(const Duration(milliseconds: 250));
              },
              onRebook: (row) async {
                // prefill booking flow with row details
                await Future.delayed(const Duration(milliseconds: 250));
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: body,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickLocation,
        icon: const Icon(Icons.tune),
        label: const Text('Filters'),
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 1.0),
        foregroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 1.0),
      ),
    );
  }
}
