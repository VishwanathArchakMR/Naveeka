// lib/features/places/presentation/widgets/parking_info.dart
import 'package:flutter/material.dart';

import '../../../../models/place.dart';

class ParkingInfo extends StatelessWidget {
  const ParkingInfo({
    super.key,
    this.title = 'Parking',
    this.showTitle = true,

    // Availability
    this.parkingAvailable,
    this.freeParking,

    // Pricing & time
    this.currency = '₹',
    this.hourlyRate,
    this.dailyRate,
    this.pricingNote,
    this.maxStayHours,
    this.openHours,

    // Restrictions
    this.heightRestrictionMeters,

    // Amenities / types
    this.valet,
    this.evCharging,
    this.disabledParking,
    this.streetParking,
    this.lotParking,
    this.garageParking,
    this.twoWheelerParking,
    this.busCoachParking,

    // Extra notes / rules
    this.notes,
  });

  /// Construct from a Place by reading its JSON map keys, supporting common alternatives.
  factory ParkingInfo.fromPlace(
    Place p, {
    Key? key,
    bool showTitle = true,
    String currency = '₹',
  }) {
    // Read a JSON-like map if available; otherwise an empty map.
    Map<String, dynamic> m = const <String, dynamic>{};
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) m = j;
    } catch (_) {
      // No toJson or incompatible shape; leave map empty.
    }

    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is T) return v;
        if (T == double && v is num) return v.toDouble() as T;
        if (T == double && v is String) {
          final d = double.tryParse(v);
          if (d != null) return d as T;
        }
        if (T == String && v != null) return v.toString() as T;
        if (T == bool && v is String) {
          final s = v.toLowerCase();
          if (s == 'true') return true as T;
          if (s == 'false') return false as T;
        }
      }
      return null;
    }

    return ParkingInfo(
      key: key,
      showTitle: showTitle,
      currency: currency,

      // Availability
      parkingAvailable: pick<bool>([
        'parkingAvailable',
        'parking_available',
        'hasParking',
        'parking',
      ]),
      freeParking: pick<bool>([
        'freeParking',
        'free_parking',
        'isFreeParking',
      ]),

      // Pricing & time
      hourlyRate: pick<double>([
        'parkingHourlyRate',
        'parking_hourly_rate',
        'hourlyRate',
      ]),
      dailyRate: pick<double>([
        'parkingDailyRate',
        'parking_daily_rate',
        'dailyRate',
      ]),
      pricingNote: pick<String>([
        'parkingPricingNote',
        'parking_pricing_note',
        'pricingNote',
        'parkingNote',
      ]),
      maxStayHours: pick<double>([
        'parkingMaxStayHours',
        'parking_max_stay_hours',
        'maxStayHours',
      ]),
      openHours: pick<String>([
        'parkingHours',
        'parking_hours',
        'openHours',
        'openingHours',
        'hours',
      ]),

      // Restrictions
      heightRestrictionMeters: pick<double>([
        'parkingHeightMeters',
        'parking_height_meters',
        'heightRestrictionMeters',
      ]),

      // Amenities / types
      valet: pick<bool>([
        'valetParking',
        'valet_parking',
        'valet',
      ]),
      evCharging: pick<bool>([
        'evCharging',
        'ev_charging',
        'ev',
        'charging',
      ]),
      disabledParking: pick<bool>([
        'accessibleParking',
        'accessible_parking',
        'disabledParking',
      ]),
      streetParking: pick<bool>([
        'streetParking',
        'street_parking',
      ]),
      lotParking: pick<bool>([
        'lotParking',
        'lot_parking',
      ]),
      garageParking: pick<bool>([
        'garageParking',
        'garage_parking',
      ]),
      twoWheelerParking: pick<bool>([
        'twoWheelerParking',
        'two_wheeler_parking',
        'bikeParking',
      ]),
      busCoachParking: pick<bool>([
        'busCoachParking',
        'bus_coach_parking',
        'coachParking',
      ]),

      // Notes
      notes: pick<String>([
        'parkingNotes',
        'parking_notes',
        'notes',
      ]),
    );
  }

  final String title;
  final bool showTitle;

  // Availability
  final bool? parkingAvailable;
  final bool? freeParking;

  // Pricing & time
  final String currency;
  final double? hourlyRate;
  final double? dailyRate;
  final String? pricingNote;
  final double? maxStayHours;
  final String? openHours;

  // Restrictions
  final double? heightRestrictionMeters;

  // Amenities / types
  final bool? valet;
  final bool? evCharging;
  final bool? disabledParking;
  final bool? streetParking;
  final bool? lotParking;
  final bool? garageParking;
  final bool? twoWheelerParking;
  final bool? busCoachParking;

  // Extra notes
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final hasAny = _hasAnyData();
    if (!hasAny) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_parking_outlined),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),

            // Availability
            if (parkingAvailable != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  parkingAvailable! ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: parkingAvailable! ? Colors.green : Colors.redAccent,
                ),
                title: Text(parkingAvailable! ? 'Parking available' : 'No parking'),
                subtitle: (freeParking == true)
                    ? const Text('Free parking')
                    : (freeParking == false ? const Text('Paid parking') : null),
              ),

            // Pricing / Rates
            if (hourlyRate != null ||
                dailyRate != null ||
                (pricingNote != null && pricingNote!.trim().isNotEmpty))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: Text(_pricingTitle()),
                subtitle: (pricingNote != null && pricingNote!.trim().isNotEmpty)
                    ? Text(pricingNote!.trim())
                    : null,
              ),

            // Hours & Restrictions
            if ((openHours != null && openHours!.trim().isNotEmpty) ||
                heightRestrictionMeters != null ||
                maxStayHours != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_hoursTitle()),
                subtitle: Text([
                  if (heightRestrictionMeters != null)
                    'Height limit ${heightRestrictionMeters!.toStringAsFixed(2)} m',
                  if (maxStayHours != null) 'Max stay ${_fmtHours(maxStayHours!)}',
                ].join(' • ')),
              ),

            // Amenity chips (types & features)
            final chips = _buildChips(),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],

            // Notes / Rules (expandable if long)
            if (notes != null && notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _NotesExpand(text: notes!.trim()),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasAnyData() {
    return parkingAvailable != null ||
        freeParking != null ||
        hourlyRate != null ||
        dailyRate != null ||
        (pricingNote != null && pricingNote!.trim().isNotEmpty) ||
        (openHours != null && openHours!.trim().isNotEmpty) ||
        heightRestrictionMeters != null ||
        maxStayHours != null ||
        valet == true ||
        evCharging == true ||
        disabledParking == true ||
        streetParking == true ||
        lotParking == true ||
        garageParking == true ||
        twoWheelerParking == true ||
        busCoachParking == true ||
        (notes != null && notes!.trim().isNotEmpty);
  }

  String _pricingTitle() {
    final parts = <String>[];
    if (hourlyRate != null) parts.add('$currency${hourlyRate!.toStringAsFixed(0)}/hr');
    if (dailyRate != null) parts.add('$currency${dailyRate!.toStringAsFixed(0)}/day');
    return parts.isEmpty ? 'Pricing' : parts.join(' • ');
  }

  String _hoursTitle() {
    if (openHours != null && openHours!.trim().isNotEmpty) return openHours!.trim();
    return 'Hours & restrictions';
  }

  String _fmtHours(double h) {
    if (h == h.roundToDouble()) {
      return '${h.toInt()}h';
    }
    return '${h.toStringAsFixed(1)}h';
  }

  // Renamed to match the call site in build() and keep generic syntax straightforward.
  List<Widget> _buildChips() {
    final items = <_ChipItem>[];

    void add(bool? flag, IconData icon, String label) {
      if (flag == true) items.add(_ChipItem(icon: icon, label: label));
    }

    add(streetParking, Icons.directions_car_filled_outlined, 'Street');
    add(lotParking, Icons.local_parking_outlined, 'Lot');
    add(garageParking, Icons.garage_outlined, 'Garage');
    add(valet, Icons.assignment_ind_outlined, 'Valet');
    add(evCharging, Icons.electric_bolt_outlined, 'EV charging');
    add(disabledParking, Icons.accessible_forward_outlined, 'Accessible');
    add(twoWheelerParking, Icons.two_wheeler_outlined, 'Two-wheeler');
    add(busCoachParking, Icons.directions_bus_filled_outlined, 'Bus/Coach');

    return items
        .map((e) => Chip(
              avatar: Icon(e.icon, size: 16),
              label: Text(e.label),
              visualDensity: VisualDensity.compact,
            ))
        .toList(growable: false);
  }
}

class _ChipItem {
  const _ChipItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NotesExpand extends StatefulWidget {
  const _NotesExpand({required this.text});
  final String text;

  @override
  State<_NotesExpand> createState() => _NotesExpandState();
}

class _NotesExpandState extends State<_NotesExpand> with TickerProviderStateMixin {
  bool _open = false;
  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _open ? null : 3,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(_open ? 'Show less' : 'Show more'),
          ),
        ),
      ],
    );
  }
}
