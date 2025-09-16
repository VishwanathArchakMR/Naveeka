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

  /// Convenience: construct from Place if the fields exist in the model.
  factory ParkingInfo.fromPlace(Place p, {Key? key, bool showTitle = true, String currency = '₹'}) {
    return ParkingInfo(
      key: key,
      showTitle: showTitle,
      currency: currency,
      parkingAvailable: p.parkingAvailable,            // optional in your model
      freeParking: p.freeParking,                      // optional
      hourlyRate: p.parkingHourlyRate,                 // optional
      dailyRate: p.parkingDailyRate,                   // optional
      pricingNote: p.parkingPricingNote,               // optional
      maxStayHours: p.parkingMaxStayHours,             // optional
      openHours: p.parkingHours ?? p.openingHours,     // fallback to general hours if present
      heightRestrictionMeters: p.parkingHeightMeters,  // optional
      valet: p.valetParking,                           // optional
      evCharging: p.evCharging,                        // optional
      disabledParking: p.accessibleParking,            // optional
      streetParking: p.streetParking,                  // optional
      lotParking: p.lotParking,                        // optional
      garageParking: p.garageParking,                  // optional
      twoWheelerParking: p.twoWheelerParking,          // optional
      busCoachParking: p.busCoachParking,              // optional
      notes: p.parkingNotes,                           // optional
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
    if (!hasAny) return const SizedBox.shrink();

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
              ), // Availability presented with a ListTile for clear label + status icon per Material list patterns. [1]

            // Pricing / Rates
            if (hourlyRate != null || dailyRate != null || (pricingNote != null && pricingNote!.trim().isNotEmpty))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: Text(_pricingTitle()),
                subtitle: (pricingNote != null && pricingNote!.trim().isNotEmpty) ? Text(pricingNote!.trim()) : null,
              ), // Pricing uses a second ListTile to show hour/day rates and optional notes in a familiar list row layout. [1]

            // Hours & Restrictions
            if ((openHours != null && openHours!.trim().isNotEmpty) || heightRestrictionMeters != null || maxStayHours != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_hoursTitle()),
                subtitle: Text(
                  [
                    if (heightRestrictionMeters != null) 'Height limit ${heightRestrictionMeters!.toStringAsFixed(2)} m',
                    if (maxStayHours != null) 'Max stay ${_fmtHours(maxStayHours!)}',
                  ].join(' • '),
                ),
              ), // Hours and restrictions are grouped into a single row for concise scanning in list-heavy UIs. [1]

            // Amenity chips (types & features)
            final chips = _buildChips();
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ], // Chips compactly represent parking types and amenities, matching Material chip guidance for attributes. [13][7]

            // Notes / Rules (expandable if long)
            if (notes != null && notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _NotesExpand(text: notes!.trim()),
            ], // An expandable notes section keeps long content tidy while still discoverable beneath the summary. [12]
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
    add(twoWheelerParking, Icons.two_wheeler_outlined, 'Two‑wheeler');
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
    ); // Animated expand/collapse keeps long parking notes tidy while discoverable with a clear control. [12]
  }
}
