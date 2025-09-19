// lib/features/journey/presentation/hotels/widgets/hotel_filters.dart

import 'package:flutter/material.dart';

class HotelFilters extends StatefulWidget {
  const HotelFilters({
    super.key,
    // Price
    this.minPrice = 0,
    this.maxPrice = 200000,
    this.initialPriceMin,
    this.initialPriceMax,

    // Stars (1–5)
    this.initialStars = const <int>{},

    // Guest rating (0–10)
    this.initialGuestRatingMin = 0,
    this.initialGuestRatingMax = 10,

    // Distance from center (km)
    this.minDistanceKm = 0,
    this.maxDistanceKm = 30,
    this.initialDistanceMinKm,
    this.initialDistanceMaxKm,

    // Amenities, property types, chains
    this.amenities = const <String>[],
    this.initialAmenities = const <String>{},

    this.propertyTypes = const <String>['Hotel', 'Apartment', 'Resort', 'Villa', 'Hostel'],
    this.initialPropertyTypes = const <String>{},

    this.chains = const <String>[],
    this.initialChains = const <String>{},

    // Toggles (tri‑state via Yes/No/Any)
    this.initialRefundable,
    this.initialPayAtHotel,
    this.initialBreakfast,

    this.currency = '₹',
    this.title = 'Filters',
  });

  // Price
  final double minPrice;
  final double maxPrice;
  final double? initialPriceMin;
  final double? initialPriceMax;

  // Stars
  final Set<int> initialStars;

  // Guest rating
  final int initialGuestRatingMin;
  final int initialGuestRatingMax;

  // Distance (km)
  final double minDistanceKm;
  final double maxDistanceKm;
  final double? initialDistanceMinKm;
  final double? initialDistanceMaxKm;

  // Amenities / property types / chains
  final List<String> amenities;
  final Set<String> initialAmenities;

  final List<String> propertyTypes;
  final Set<String> initialPropertyTypes;

  final List<String> chains;
  final Set<String> initialChains;

  // Tri‑state toggles
  final bool? initialRefundable;
  final bool? initialPayAtHotel;
  final bool? initialBreakfast;

  final String currency;
  final String title;

  @override
  State<HotelFilters> createState() => _HotelFiltersState();

  /// Helper to present as modal sheet; returns:
  /// {
  ///   'price': {'min': double, 'max': double},
  ///   'stars': Set<int>,
  ///   'guestRating': {'min': int, 'max': int},
  ///   'distanceKm': {'min': double, 'max': double},
  ///   'amenities': Set<String>,
  ///   'propertyTypes': Set<String>,
  ///   'chains': Set<String>,
  ///   'refundable': bool|null,
  ///   'payAtHotel': bool|null,
  ///   'breakfastIncluded': bool|null
  /// }
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    double minPrice = 0,
    double maxPrice = 200000,
    double? initialPriceMin,
    double? initialPriceMax,
    Set<int> initialStars = const <int>{},
    int initialGuestRatingMin = 0,
    int initialGuestRatingMax = 10,
    double minDistanceKm = 0,
    double maxDistanceKm = 30,
    double? initialDistanceMinKm,
    double? initialDistanceMaxKm,
    List<String> amenities = const <String>[],
    Set<String> initialAmenities = const <String>{},
    List<String> propertyTypes = const <String>['Hotel', 'Apartment', 'Resort', 'Villa', 'Hostel'],
    Set<String> initialPropertyTypes = const <String>{},
    List<String> chains = const <String>[],
    Set<String> initialChains = const <String>{},
    bool? initialRefundable,
    bool? initialPayAtHotel,
    bool? initialBreakfast,
    String currency = '₹',
    String title = 'Filters',
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
        child: HotelFilters(
          minPrice: minPrice,
          maxPrice: maxPrice,
          initialPriceMin: initialPriceMin,
          initialPriceMax: initialPriceMax,
          initialStars: initialStars,
          initialGuestRatingMin: initialGuestRatingMin,
          initialGuestRatingMax: initialGuestRatingMax,
          minDistanceKm: minDistanceKm,
          maxDistanceKm: maxDistanceKm,
          initialDistanceMinKm: initialDistanceMinKm,
          initialDistanceMaxKm: initialDistanceMaxKm,
          amenities: amenities,
          initialAmenities: initialAmenities,
          propertyTypes: propertyTypes,
          initialPropertyTypes: initialPropertyTypes,
          chains: chains,
          initialChains: initialChains,
          initialRefundable: initialRefundable,
          initialPayAtHotel: initialPayAtHotel,
          initialBreakfast: initialBreakfast,
          currency: currency,
          title: title,
        ),
      ),
    );
  }
}

class _HotelFiltersState extends State<HotelFilters> {
  late RangeValues _price;
  late Set<int> _stars;

  late RangeValues _guestRating; // 0..10
  late RangeValues _distance; // km

  late Set<String> _amenities;
  late Set<String> _propertyTypes;
  late Set<String> _chains;

  int _refundableTri = -1; // 1 yes, 0 no, -1 any
  int _payAtHotelTri = -1;
  int _breakfastTri = -1;

  @override
  void initState() {
    super.initState();
    final pMin = widget.initialPriceMin ?? widget.minPrice;
    final pMax = widget.initialPriceMax ?? widget.maxPrice;
    _price = RangeValues(
      pMin.clamp(widget.minPrice, widget.maxPrice),
      pMax.clamp(widget.minPrice, widget.maxPrice),
    );

    _stars = {...widget.initialStars};

    _guestRating = RangeValues(
      widget.initialGuestRatingMin.toDouble().clamp(0, 10),
      widget.initialGuestRatingMax.toDouble().clamp(0, 10),
    );

    final dMin = (widget.initialDistanceMinKm ?? widget.minDistanceKm).clamp(widget.minDistanceKm, widget.maxDistanceKm);
    final dMax = (widget.initialDistanceMaxKm ?? widget.maxDistanceKm).clamp(widget.minDistanceKm, widget.maxDistanceKm);
    _distance = RangeValues(dMin, dMax);

    _amenities = {...widget.initialAmenities};
    _propertyTypes = {...widget.initialPropertyTypes};
    _chains = {...widget.initialChains};

    _refundableTri = _triFromBool(widget.initialRefundable);
    _payAtHotelTri = _triFromBool(widget.initialPayAtHotel);
    _breakfastTri = _triFromBool(widget.initialBreakfast);
  }

  int _triFromBool(bool? v) => v == null ? -1 : (v ? 1 : 0);
  bool? _boolFromTri(int v) => v == -1 ? null : (v == 1);

  void _reset() {
    setState(() {
      _price = RangeValues(widget.minPrice, widget.maxPrice);
      _stars.clear();
      _guestRating = const RangeValues(0, 10);
      _distance = RangeValues(widget.minDistanceKm, widget.maxDistanceKm);
      _amenities.clear();
      _propertyTypes.clear();
      _chains.clear();
      _refundableTri = -1;
      _payAtHotelTri = -1;
      _breakfastTri = -1;
    });
  }

  void _apply() {
    Navigator.of(context).pop(<String, dynamic>{
      'price': {'min': _price.start, 'max': _price.end},
      'stars': _stars,
      'guestRating': {'min': _guestRating.start.round(), 'max': _guestRating.end.round()},
      'distanceKm': {'min': _distance.start, 'max': _distance.end},
      'amenities': _amenities,
      'propertyTypes': _propertyTypes,
      'chains': _chains,
      'refundable': _boolFromTri(_refundableTri),
      'payAtHotel': _boolFromTri(_payAtHotelTri),
      'breakfastIncluded': _boolFromTri(_breakfastTri),
    });
  }

  @override
  Widget build(BuildContext context) {
    const chipSpace = 8.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),

            const SizedBox(height: 8),

            // Price
            const _Section('Price'),
            RangeSlider(
              values: _price,
              min: widget.minPrice,
              max: widget.maxPrice,
              divisions: 20,
              labels: RangeLabels(
                '${widget.currency}${_price.start.round()}',
                '${widget.currency}${_price.end.round()}',
              ),
              onChanged: (v) => setState(() => _price = v),
            ),
            Row(
              children: [
                Text('${widget.currency}${_price.start.round()}'),
                const Spacer(),
                Text('${widget.currency}${_price.end.round()}'),
              ],
            ),

            const SizedBox(height: 12),

            // Stars
            const _Section('Star rating'),
            Wrap(
              spacing: chipSpace,
              runSpacing: chipSpace,
              children: List.generate(5, (i) {
                final star = 5 - i; // show 5★ first
                final sel = _stars.contains(star);
                return FilterChip(
                  label: Text('$star★'),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _stars.remove(star);
                    } else {
                      _stars.add(star);
                    }
                  }),
                );
              }),
            ),

            const SizedBox(height: 12),

            // Guest rating
            const _Section('Guest rating'),
            RangeSlider(
              values: _guestRating,
              min: 0,
              max: 10,
              divisions: 10,
              labels: RangeLabels('${_guestRating.start.round()}', '${_guestRating.end.round()}'),
              onChanged: (v) => setState(() => _guestRating = v),
            ),
            Row(
              children: [
                Text('${_guestRating.start.round()}'),
                const Spacer(),
                Text('${_guestRating.end.round()}'),
              ],
            ),

            const SizedBox(height: 12),

            // Distance
            const _Section('Distance from center'),
            RangeSlider(
              values: _distance,
              min: widget.minDistanceKm,
              max: widget.maxDistanceKm,
              divisions: 30,
              labels: RangeLabels(
                '${_distance.start.toStringAsFixed(0)} km',
                '${_distance.end.toStringAsFixed(0)} km',
              ),
              onChanged: (v) => setState(() => _distance = v),
            ),
            Row(
              children: [
                Text('${_distance.start.toStringAsFixed(0)} km'),
                const Spacer(),
                Text('${_distance.end.toStringAsFixed(0)} km'),
              ],
            ),

            const SizedBox(height: 12),

            // Amenities
            if (widget.amenities.isNotEmpty) ...[
              const _Section('Amenities'),
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: chipSpace,
                    runSpacing: chipSpace,
                    children: widget.amenities.map((a) {
                      final sel = _amenities.contains(a);
                      return FilterChip(
                        label: Text(a),
                        selected: sel,
                        onSelected: (_) => setState(() {
                          if (sel) {
                            _amenities.remove(a);
                          } else {
                            _amenities.add(a);
                          }
                        }),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Property types
            const _Section('Property type'),
            Wrap(
              spacing: chipSpace,
              runSpacing: chipSpace,
              children: widget.propertyTypes.map((t) {
                final sel = _propertyTypes.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _propertyTypes.remove(t);
                    } else {
                      _propertyTypes.add(t);
                    }
                  }),
                );
              }).toList(growable: false),
            ),

            const SizedBox(height: 12),

            // Chains
            if (widget.chains.isNotEmpty) ...[
              const _Section('Chains'),
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: chipSpace,
                    runSpacing: chipSpace,
                    children: widget.chains.map((c) {
                      final sel = _chains.contains(c);
                      return FilterChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (_) => setState(() {
                          if (sel) {
                            _chains.remove(c);
                          } else {
                            _chains.add(c);
                          }
                        }),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Tri‑state toggles
            const _Section('Payment & policies'),
            Row(
              children: [
                const Icon(Icons.currency_exchange, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Text('Refundable'),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Yes')),
                    ButtonSegment(value: 0, label: Text('No')),
                    ButtonSegment(value: -1, label: Text('Any')),
                  ],
                  selected: {_refundableTri},
                  onSelectionChanged: (s) => setState(() => _refundableTri = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Text('Pay at hotel'),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Yes')),
                    ButtonSegment(value: 0, label: Text('No')),
                    ButtonSegment(value: -1, label: Text('Any')),
                  ],
                  selected: {_payAtHotelTri},
                  onSelectionChanged: (s) => setState(() => _payAtHotelTri = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.free_breakfast_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Text('Breakfast included'),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Yes')),
                    ButtonSegment(value: 0, label: Text('No')),
                    ButtonSegment(value: -1, label: Text('Any')),
                  ],
                  selected: {_breakfastTri},
                  onSelectionChanged: (s) => setState(() => _breakfastTri = s.first),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Apply
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
