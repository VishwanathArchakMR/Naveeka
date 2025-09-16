// lib/features/navee_ai/presentation/widgets/location_suggestions.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../journey/core/storage/location_cache.dart';

/// A debounced, bottom-sheet-friendly location suggester with:
/// - Debounced text search via a callback
/// - Optional "Use my location" to seed nearby suggestions
/// - Optional popular chips
/// - Returns a normalized map on selection via Navigator.pop
///
/// Expected suggestion shape (normalized on selection):
/// { name, secondary?, city?, region?, country?, lat?, lng?, placeId? }
class LocationSuggestions extends StatefulWidget {
  const LocationSuggestions({
    super.key,
    required this.searchLocations, // Future<List<Map<String,dynamic>>> Function(String q, {double? lat, double? lng})
    this.popular = const <Map<String, dynamic>>[], // [{name, secondary?, country?, lat?, lng?}]
    this.reverseGeocode, // Future<Map<String,dynamic>?> Function(double lat,double lng)
    this.title = 'Pick a location',
    this.initialQuery = '',
  });

  final Future<List<Map<String, dynamic>>> Function(
    String query, {
    double? lat,
    double? lng,
  }) searchLocations;

  final List<Map<String, dynamic>> popular;

  final Future<Map<String, dynamic>?> Function(double lat, double lng)? reverseGeocode;

  final String title;
  final String initialQuery;

  /// Helper to show in a shaped modal bottom sheet and return a place map.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Future<List<Map<String, dynamic>>> Function(
      String query, {
      double? lat,
      double? lng,
    })
        searchLocations,
    List<Map<String, dynamic>> popular = const <Map<String, dynamic>>[],
    Future<Map<String, dynamic>?> Function(double lat, double lng)? reverseGeocode,
    String title = 'Pick a location',
    String initialQuery = '',
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: LocationSuggestions(
          searchLocations: searchLocations,
          popular: popular,
          reverseGeocode: reverseGeocode,
          title: title,
          initialQuery: initialQuery,
        ),
      ),
    ); // Present a modal bottom sheet and return the selection via Navigator.pop for a focused, contextual picker flow. [12][15]
  }

  @override
  State<LocationSuggestions> createState() => _LocationSuggestionsState();
}

class _LocationSuggestionsState extends State<LocationSuggestions> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  final _debounceDuration = const Duration(milliseconds: 350);

  bool _loading = false;
  List<Map<String, dynamic>> _results = const <Map<String, dynamic>>[];

  double? _hintLat;
  double? _hintLng;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _performSearch(widget.initialQuery.trim());
    }
    _seedLastKnown();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _seedLastKnown() async {
    final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
    if (!mounted || snap == null) return;
    setState(() {
      _hintLat = snap.latitude;
      _hintLng = snap.longitude;
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      _performSearch(q.trim());
    });
  } // Debouncing the TextField onChanged avoids excessive API calls while the user types and improves responsiveness. [10][19]

  Future<void> _performSearch(String q) async {
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _results = const [];
    });
    try {
      final list = await widget.searchLocations(q, lat: _hintLat, lng: _hintLng);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load locations'))); // SnackBars give simple, route-safe feedback for failed network calls. [1]
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _loading = true);
    try {
      final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
      if (!mounted) return;
      if (snap == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available yet')));
        return;
      }
      _hintLat = snap.latitude;
      _hintLng = snap.longitude;

      if (widget.reverseGeocode != null) {
        final m = await widget.reverseGeocode!(snap.latitude, snap.longitude);
        if (!mounted) return;
        if (m != null) {
          Navigator.of(context).maybePop(_normalize(m));
          return;
        }
      }

      // Fallback: run an empty query to fetch nearby suggestions
      final list = await widget.searchLocations('', lat: snap.latitude, lng: snap.longitude);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to use current location')));
    }
  }

  void _pick(Map<String, dynamic> m) {
    Navigator.of(context).pop(_normalize(m));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> m) {
    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null) return v as T?;
      }
      return null;
    }

    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return {
      'name': (pick<String>(['name', 'title']) ?? '').toString(),
      'secondary': pick<String>(['secondary', 'subtitle']),
      'city': pick<String>(['city', 'locality']),
      'region': pick<String>(['region', 'state']),
      'country': pick<String>(['country']),
      'lat': d(pick(['lat', 'latitude'])),
      'lng': d(pick(['lng', 'longitude'])),
      'placeId': (pick<String>(['placeId', 'id']) ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final hasNearby = _hintLat != null && _hintLng != null;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focus,
              onChanged: _onChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Type a city, area, or landmark',
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasNearby)
                      IconButton(
                        tooltip: 'Use my location',
                        icon: const Icon(Icons.my_location),
                        onPressed: _useMyLocation,
                      ),
                    if (query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _results = const []);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Popular chips (when idle)
          if (!_loading && _results.isEmpty && widget.popular.isNotEmpty && query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.popular.map((m) {
                    final name = (m['name'] ?? '').toString();
                    final secondary = (m['secondary'] ?? '').toString();
                    return ActionChip(
                      label: Text(secondary.isEmpty ? name : '$name • $secondary'),
                      onPressed: () => _pick(m),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),

          // Results
          SizedBox(
            height: 420,
            child: _results.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 12),
                      Center(child: Text('Search to find locations')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = _results[i];
                      final name = (m['name'] ?? '').toString();
                      final secondary = (m['secondary'] ?? '').toString();
                      final city = (m['city'] ?? '').toString();
                      final region = (m['region'] ?? '').toString();
                      final country = (m['country'] ?? '').toString();

                      final subtitle = [
                        if (secondary.isNotEmpty) secondary,
                        if (city.isNotEmpty) city,
                        if (region.isNotEmpty) region,
                        if (country.isNotEmpty) country,
                      ].where((e) => e.isNotEmpty).join(' • ');

                      return ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(name.isEmpty ? (city.isEmpty ? 'Location' : city) : name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () => _pick(m),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ); // ListTile rows offer a compact, accessible pattern for list results with leading icons, title, subtitle, and trailing indicators in Material apps. [1][11]
  }
}
