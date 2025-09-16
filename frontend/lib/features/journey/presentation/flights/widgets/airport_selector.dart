// lib/features/journey/presentation/flights/widgets/airport_selector.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../core/storage/location_cache.dart';

/// Airport selector presented in a modal sheet with:
/// - Debounced text search (calls searchAirports)
/// - Optional popular chips
/// - Optional "Nearby" based on last known location + callback
/// Expected airport item shape:
/// { code, name, city, country, lat?, lng?, terminal? }
class AirportSelector extends StatefulWidget {
  const AirportSelector({
    super.key,
    required this.searchAirports,
    this.popularAirports = const <Map<String, dynamic>>[],
    this.nearbyAirports, // Future<List<Map>> Function(lat, lng)
    this.title = 'Select airport',
    this.initialQuery = '',
  });

  /// Called with the typed query; should return a list of airport maps.
  final Future<List<Map<String, dynamic>>> Function(String query) searchAirports;

  /// Optional popular airports to display as quick chips at the top.
  final List<Map<String, dynamic>> popularAirports;

  /// Optional nearby finder using last known coordinates.
  final Future<List<Map<String, dynamic>>> Function(double lat, double lng)? nearbyAirports;

  final String title;
  final String initialQuery;

  @override
  State<AirportSelector> createState() => _AirportSelectorState();

  /// Helper: show as modal bottom sheet and return a selected airport map:
  /// { code, name, city, country, lat?, lng?, terminal? }
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Future<List<Map<String, dynamic>>> Function(String query) searchAirports,
    List<Map<String, dynamic>> popularAirports = const <Map<String, dynamic>>[],
    Future<List<Map<String, dynamic>>> Function(double lat, double lng)? nearbyAirports,
    String title = 'Select airport',
    String initialQuery = '',
  }) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AirportSelector(
          searchAirports: searchAirports,
          popularAirports: popularAirports,
          nearbyAirports: nearbyAirports,
          title: title,
          initialQuery: initialQuery,
        ),
      ),
    );
  }
}

class _AirportSelectorState extends State<AirportSelector> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  final _debounceDuration = const Duration(milliseconds: 350);

  bool _loading = false;
  List<Map<String, dynamic>> _results = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _performSearch(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      _performSearch(q.trim());
    });
  }

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
      final list = await widget.searchAirports(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _loadNearby() async {
    if (widget.nearbyAirports == null) return;
    setState(() {
      _loading = true;
      _results = const [];
    });
    final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
    if (!mounted) return;
    if (snap == null) {
      setState(() => _loading = false);
      _snack('Location not available yet');
      return;
    }
    try {
      final list = await widget.nearbyAirports!(snap.latitude, snap.longitude);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to load nearby airports');
    }
  }

  void _pick(Map<String, dynamic> airport) {
    Navigator.of(context).pop(airport);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final hasNearby = widget.nearbyAirports != null;

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
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Type city, airport or IATA code',
                isDense: true,
                suffixIcon: hasNearby
                    ? IconButton(
                        tooltip: 'Nearby',
                        icon: const Icon(Icons.my_location),
                        onPressed: _loadNearby,
                      )
                    : null,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Popular chips
          if (widget.popularAirports.isNotEmpty && _searchCtrl.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.popularAirports.map((a) {
                    final code = (a['code'] ?? '').toString();
                    final city = (a['city'] ?? '').toString();
                    return ActionChip(
                      label: Text(code.isNotEmpty ? '$code • $city' : city),
                      onPressed: () => _pick(a),
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
                      Center(child: Text('Search to find airports')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = _results[i];
                      final code = (a['code'] ?? '').toString();
                      final name = (a['name'] ?? '').toString();
                      final city = (a['city'] ?? '').toString();
                      final country = (a['country'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            code.isNotEmpty ? code.substring(0, 2) : '?',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          code.isNotEmpty ? '$code • $name' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          city.isNotEmpty ? '$city, $country' : country,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () => _pick(a),
                      );
                    },
                  ),
          ),

          // Confirm (enabled when single explicit typed code matches in results)
          // For this generic selector, selection happens on tap; no extra confirm button needed.
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
