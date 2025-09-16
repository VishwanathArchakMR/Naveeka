// lib/features/quick_actions/presentation/booking/widgets/booking_location_filter.dart

import 'package:flutter/material.dart';

enum UnitSystem { metric, imperial }

/// The chosen location and radius for booking queries.
class BookingLocationSelection {
  const BookingLocationSelection({
    required this.mode,
    this.lat,
    this.lng,
    this.address,
    this.radiusKm,
    this.unit = UnitSystem.metric,
  });

  final LocationMode mode; // nearMe | address | mapPin
  final double? lat;
  final double? lng;
  final String? address;
  final double? radiusKm;
  final UnitSystem unit;

  BookingLocationSelection copyWith({
    LocationMode? mode,
    double? lat,
    double? lng,
    String? address,
    double? radiusKm,
    UnitSystem? unit,
  }) {
    return BookingLocationSelection(
      mode: mode ?? this.mode,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      radiusKm: radiusKm ?? this.radiusKm,
      unit: unit ?? this.unit,
    );
  }

  @override
  String toString() {
    final u = unit == UnitSystem.metric ? 'km' : 'mi';
    final r = radiusKm == null ? 'Any' : _formatDistance(radiusKm!, unit);
    switch (mode) {
      case LocationMode.nearMe:
        return 'Near me · $r $u';
      case LocationMode.address:
        return '${(address ?? '').isEmpty ? 'Address' : address} · $r $u';
      case LocationMode.mapPin:
        return 'Pinned location · $r $u';
    }
  }

  static String _formatDistance(double km, UnitSystem unit) {
    final v = unit == UnitSystem.metric ? km : km * 0.621371;
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

enum LocationMode { nearMe, address, mapPin }

/// A compact field that opens a bottom-sheet location picker and returns a typed BookingLocationSelection.
class BookingLocationFilter extends StatelessWidget {
  const BookingLocationFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Location',
    this.recentAddresses = const <String>[],
    this.onResolveCurrentLocation,
    this.onPickOnMap,
    this.minKm = 0.5,
    this.maxKm = 50.0,
  });

  final BookingLocationSelection value;
  final ValueChanged<BookingLocationSelection> onChanged;
  final String label;

  /// Optional recent addresses displayed as quick chips.
  final List<String> recentAddresses;

  /// Provide current location resolver when user picks “Near me”.
  /// Return lat/lng or null if unavailable/denied.
  final Future<GeoPoint?> Function()? onResolveCurrentLocation;

  /// Provide a map picker for “Choose on map”. Return lat/lng or null if canceled.
  final Future<GeoPoint?> Function()? onPickOnMap;

  final double minKm;
  final double maxKm;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.tune),
      onTap: () async {
        final picked = await BookingLocationFilterSheet.show(
          context,
          initial: value,
          recentAddresses: recentAddresses,
          onResolveCurrentLocation: onResolveCurrentLocation,
          onPickOnMap: onPickOnMap,
          minKm: minKm,
          maxKm: maxKm,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Simple lat/lng holder.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Bottom-sheet picker.
class BookingLocationFilterSheet extends StatefulWidget {
  const BookingLocationFilterSheet({
    super.key,
    required this.initial,
    required this.recentAddresses,
    required this.minKm,
    required this.maxKm,
    this.onResolveCurrentLocation,
    this.onPickOnMap,
  });

  final BookingLocationSelection initial;
  final List<String> recentAddresses;
  final double minKm;
  final double maxKm;
  final Future<GeoPoint?> Function()? onResolveCurrentLocation;
  final Future<GeoPoint?> Function()? onPickOnMap;

  static Future<BookingLocationSelection?> show(
    BuildContext context, {
    required BookingLocationSelection initial,
    List<String> recentAddresses = const <String>[],
    Future<GeoPoint?> Function()? onResolveCurrentLocation,
    Future<GeoPoint?> Function()? onPickOnMap,
    double minKm = 0.5,
    double maxKm = 50.0,
  }) {
    return showModalBottomSheet<BookingLocationSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BookingLocationFilterSheet(
          initial: initial,
          recentAddresses: recentAddresses,
          onResolveCurrentLocation: onResolveCurrentLocation,
          onPickOnMap: onPickOnMap,
          minKm: minKm,
          maxKm: maxKm,
        ),
      ),
    );
  }

  @override
  State<BookingLocationFilterSheet> createState() => _BookingLocationFilterSheetState();
}

class _BookingLocationFilterSheetState extends State<BookingLocationFilterSheet> {
  late LocationMode _mode;
  late UnitSystem _unit;
  late double _radiusKm;
  late TextEditingController _addr;

  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _unit = widget.initial.unit;
    _radiusKm = (widget.initial.radiusKm ?? 5.0).clamp(widget.minKm, widget.maxKm);
    _addr = TextEditingController(text: widget.initial.address ?? '');
  }

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayRadius = _unit == UnitSystem.metric ? _radiusKm : _radiusKm * 0.621371;
    final radiusLabel = _unit == UnitSystem.metric ? 'km' : 'mi';

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text('Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
                ],
              ),

              // Mode selector
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<LocationMode>(
                  segments: const [
                    ButtonSegment(value: LocationMode.nearMe, label: Text('Near me'), icon: Icon(Icons.my_location)),
                    ButtonSegment(value: LocationMode.address, label: Text('Address'), icon: Icon(Icons.home_outlined)),
                    ButtonSegment(value: LocationMode.mapPin, label: Text('On map'), icon: Icon(Icons.add_location_alt_outlined)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ),

              const SizedBox(height: 12),

              // Address entry
              if (_mode == LocationMode.address) ...[
                TextField(
                  controller: _addr,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Enter address or area',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {},
                ),
                if (widget.recentAddresses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.recentAddresses.map((a) {
                        return ActionChip(
                          label: Text(a, overflow: TextOverflow.ellipsis),
                          onPressed: () => setState(() => _addr.text = a),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
              ],

              // Near me resolver
              if (_mode == LocationMode.nearMe) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onResolveCurrentLocation == null || _resolving
                        ? null
                        : () async {
                            setState(() => _resolving = true);
                            try {
                              final pt = await widget.onResolveCurrentLocation!.call();
                              if (pt != null) {
                                // Nothing else to do here; lat/lng will be applied on Apply.
                              }
                            } finally {
                              if (mounted) setState(() => _resolving = false);
                            }
                          },
                    icon: _resolving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: const Text('Use current location'),
                  ),
                ),
              ],

              // Map picker
              if (_mode == LocationMode.mapPin) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onPickOnMap == null
                        ? null
                        : () async {
                            final pt = await widget.onPickOnMap!.call();
                            if (pt != null) {
                              // Nothing else to do here; lat/lng will be applied on Apply via local state handoff.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location pinned')),
                              );
                            }
                          },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Choose on map'),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Unit + radius
              Row(
                children: [
                  const Text('Distance', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  SegmentedButton<UnitSystem>(
                    segments: const [
                      ButtonSegment(value: UnitSystem.metric, label: Text('km')),
                      ButtonSegment(value: UnitSystem.imperial, label: Text('mi')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (s) => setState(() => _unit = s.first),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radiusKm.clamp(widget.minKm, widget.maxKm),
                      min: widget.minKm,
                      max: widget.maxKm,
                      divisions: (widget.maxKm - widget.minKm).round(),
                      label: '${displayRadius.toStringAsFixed(displayRadius >= 10 ? 0 : 1)} $radiusLabel',
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear radius',
                    onPressed: () => setState(() => _radiusKm = widget.minKm),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Apply'),
                  onPressed: () async {
                    // Prepare selection
                    var sel = widget.initial.copyWith(
                      mode: _mode,
                      unit: _unit,
                      radiusKm: _radiusKm,
                      address: _mode == LocationMode.address ? _addr.text.trim() : null,
                    );

                    // Resolve coordinates if needed
                    if (_mode == LocationMode.nearMe && widget.onResolveCurrentLocation != null) {
                      final pt = await widget.onResolveCurrentLocation!.call();
                      sel = sel.copyWith(lat: pt?.lat, lng: pt?.lng);
                    } else if (_mode == LocationMode.mapPin && widget.onPickOnMap != null) {
                      // If map was not launched during this session, allow choosing now.
                      final pt = await widget.onPickOnMap!.call();
                      sel = sel.copyWith(lat: pt?.lat, lng: pt?.lng);
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).maybePop(sel);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
