// lib/features/places/presentation/widgets/place_filters.dart

import 'package:flutter/material.dart';

/// Immutable filter model for places search/listing.
class PlaceFilters {
  const PlaceFilters({
    this.query,
    this.categories = const <String>{},
    this.maxDistanceKm,
    this.openNow = false,
    this.minRating,
    this.priceLevels = const <int>{}, // 1..4
    this.amenities = const <String>{},
    this.sortBy = 'distance', // distance | rating | relevance
  });

  final String? query;
  final Set<String> categories;
  final double? maxDistanceKm;
  final bool openNow;
  final double? minRating;
  final Set<int> priceLevels;
  final Set<String> amenities;
  final String sortBy;

  PlaceFilters copyWith({
    String? query,
    Set<String>? categories,
    double? maxDistanceKm,
    bool? openNow,
    double? minRating,
    Set<int>? priceLevels,
    Set<String>? amenities,
    String? sortBy,
  }) {
    return PlaceFilters(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      openNow: openNow ?? this.openNow,
      minRating: minRating ?? this.minRating,
      priceLevels: priceLevels ?? this.priceLevels,
      amenities: amenities ?? this.amenities,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      categories.isEmpty &&
      maxDistanceKm == null &&
      !openNow &&
      minRating == null &&
      priceLevels.isEmpty &&
      amenities.isEmpty &&
      (sortBy == 'distance');

  int get badgeCount {
    var c = 0;
    if (query != null && query!.trim().isNotEmpty) c++;
    if (categories.isNotEmpty) c++;
    if (maxDistanceKm != null) c++;
    if (openNow) c++;
    if (minRating != null) c++;
    if (priceLevels.isNotEmpty) c++;
    if (amenities.isNotEmpty) c++;
    if (sortBy != 'distance') c++;
    return c;
  }

  /// Map to query parameters for your data layer.
  /// radiusMeters is derived from maxDistanceKm; unknown keys are ignored by servers that don’t use them.
  Map<String, dynamic> toQuery() {
    return {
      if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
      if (categories.isNotEmpty) 'categories': categories.join(','),
      if (maxDistanceKm != null) 'radiusMeters': (maxDistanceKm! * 1000).round(),
      if (openNow) 'open_now': true,
      if (minRating != null) 'min_rating': minRating,
      if (priceLevels.isNotEmpty) 'price': priceLevels.toList(), // e.g., [1,2]
      if (amenities.isNotEmpty) 'amenities': amenities.join(','),
      if (sortBy.isNotEmpty) 'sort': sortBy,
    };
  }

  static const PlaceFilters empty = PlaceFilters();
}

/// A shaped modal sheet with common place filters: query, categories, distance, open-now, rating, price, amenities, and sorting.
/// Returns PlaceFilters via Navigator.pop on Apply.
class PlaceFiltersSheet extends StatefulWidget {
  const PlaceFiltersSheet({
    super.key,
    required this.initial,
    this.availableCategories = const <String>['food', 'coffee', 'sights', 'shopping', 'nightlife', 'outdoors'],
    this.availableAmenities = const <String>['parking', 'wheelchair', 'family', 'ev', 'wifi'],
    this.title = 'Filters',
    this.maxDistanceKm = 20.0,
  });

  final PlaceFilters initial;
  final List<String> availableCategories;
  final List<String> availableAmenities;
  final String title;
  final double maxDistanceKm;

  /// Convenience presenter that returns PlaceFilters on save.
  static Future<PlaceFilters?> show(
    BuildContext context, {
    required PlaceFilters initial,
    List<String> availableCategories = const <String>['food', 'coffee', 'sights', 'shopping', 'nightlife', 'outdoors'],
    List<String> availableAmenities = const <String>['parking', 'wheelchair', 'family', 'ev', 'wifi'],
    String title = 'Filters',
    double maxDistanceKm = 20.0,
  }) {
    return showModalBottomSheet<PlaceFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PlaceFiltersSheet(
          initial: initial,
          availableCategories: availableCategories,
          availableAmenities: availableAmenities,
          title: title,
          maxDistanceKm: maxDistanceKm,
        ),
      ),
    );
  }

  @override
  State<PlaceFiltersSheet> createState() => _PlaceFiltersSheetState();
}

class _PlaceFiltersSheetState extends State<PlaceFiltersSheet> {
  late TextEditingController _qCtrl;
  late Set<String> _cats;
  double? _distanceKm;
  bool _openNow = false;
  double? _minRating;
  late Set<int> _priceLevels;
  late Set<String> _amenities;
  String _sortBy = 'distance';

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.initial.query ?? '');
    _cats = {...widget.initial.categories};
    _distanceKm = widget.initial.maxDistanceKm;
    _openNow = widget.initial.openNow;
    _minRating = widget.initial.minRating;
    _priceLevels = {...widget.initial.priceLevels};
    _amenities = {...widget.initial.amenities};
    _sortBy = widget.initial.sortBy;
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _qCtrl.clear();
      _cats.clear();
      _distanceKm = null;
      _openNow = false;
      _minRating = null;
      _priceLevels.clear();
      _amenities.clear();
      _sortBy = 'distance';
    });
  }

  void _apply() {
    final out = PlaceFilters(
      query: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      categories: _cats,
      maxDistanceKm: _distanceKm,
      openNow: _openNow,
      minRating: _minRating,
      priceLevels: _priceLevels,
      amenities: _amenities,
      sortBy: _sortBy,
    );
    Navigator.of(context).maybePop(out);
  }

  @override
  Widget build(BuildContext context) {
    final badge = PlaceFilters(
      query: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      categories: _cats,
      maxDistanceKm: _distanceKm,
      openNow: _openNow,
      minRating: _minRating,
      priceLevels: _priceLevels,
      amenities: _amenities,
      sortBy: _sortBy,
    ).badgeCount;

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
                  ],
                ),

                // Query
                TextField(
                  controller: _qCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Categories'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableCategories.map((c) {
                    final selected = _cats.contains(c);
                    return FilterChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        on ? _cats.add(c) : _cats.remove(c);
                      }),
                    );
                  }).toList(growable: false),
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Distance'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: (_distanceKm ?? 5.0).clamp(0.5, widget.maxDistanceKm),
                        min: 0.5,
                        max: widget.maxDistanceKm,
                        divisions: (widget.maxDistanceKm * 2).round(),
                        label: _distanceKm == null ? 'Any' : '${_distanceKm!.toStringAsFixed(1)} km',
                        onChanged: (v) => setState(() => _distanceKm = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: _distanceKm == null ? null : () => setState(() => _distanceKm = null),
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                SwitchListTile(
                  value: _openNow,
                  onChanged: (v) => setState(() => _openNow = v),
                  title: const Text('Open now'),
                  secondary: const Icon(Icons.access_time),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),
                const _SectionHeader('Rating'),
                Wrap(
                  spacing: 8,
                  children: [
                    _ratingChip(null, 'Any'),
                    _ratingChip(3.0, '3.0+'),
                    _ratingChip(4.0, '4.0+'),
                    _ratingChip(4.5, '4.5+'),
                  ],
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Price'),
                Wrap(
                  spacing: 8,
                  children: List.generate(4, (i) {
                    final level = i + 1;
                    final selected = _priceLevels.contains(level);
                    return FilterChip(
                      label: Text('\$' * level),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        on ? _priceLevels.add(level) : _priceLevels.remove(level);
                      }),
                    );
                  }),
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Amenities'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableAmenities.map((a) {
                    final selected = _amenities.contains(a);
                    return FilterChip(
                      label: Text(a),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        on ? _amenities.add(a) : _amenities.remove(a);
                      }),
                    );
                  }).toList(growable: false),
                ),

                const SizedBox(height: 12),
                const _SectionHeader('Sort by'),
                DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text('Distance')),
                    DropdownMenuItem(value: 'rating', child: Text('Rating')),
                    DropdownMenuItem(value: 'relevance', child: Text('Relevance')),
                  ],
                  onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(badge > 0 ? 'Apply ($badge)' : 'Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingChip(double? value, String label) {
    final selected = _minRating == value || (_minRating == null && value == null);
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _minRating = value),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
