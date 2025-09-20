// lib/features/journey/presentation/cabs/cab_options_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/cabs_api.dart';
import 'cab_booking_screen.dart';

class CabOptionsScreen extends StatefulWidget {
  const CabOptionsScreen({
    super.key,
    required this.title,
    this.defaultPickup, // {lat,lng,address}
    this.defaultDrop, // {lat,lng,address}
    this.defaultProvider, // preselect/filter providers
    this.currency = '₹',
  });

  final String title;
  final Map<String, dynamic>? defaultPickup;
  final Map<String, dynamic>? defaultDrop;
  final String? defaultProvider;
  final String currency;

  @override
  State<CabOptionsScreen> createState() => _CabOptionsScreenState();
}

enum _WhenMode { now, later }

class _CabOptionsScreenState extends State<CabOptionsScreen> {
  // Pickup / Drop
  final _pickupAddrCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();

  final _dropAddrCtrl = TextEditingController();
  final _dropLatCtrl = TextEditingController();
  final _dropLngCtrl = TextEditingController();

  // When
  _WhenMode _mode = _WhenMode.now;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 20));

  // Results
  bool _loading = false;
  List<Map<String, dynamic>> _all = const [];
  List<Map<String, dynamic>> _visible = const [];

  // Filters / sort
  final Set<String> _providers = {};
  final Set<String> _vehicles = {};
  String _sort = 'price_asc'; // price_asc | eta_asc

  @override
  void initState() {
    super.initState();
    if (widget.defaultPickup != null) {
      _pickupAddrCtrl.text = (widget.defaultPickup!['address'] ?? '').toString();
      final la = widget.defaultPickup!['lat'], ln = widget.defaultPickup!['lng'];
      if (la != null) _pickupLatCtrl.text = la.toString();
      if (ln != null) _pickupLngCtrl.text = ln.toString();
    }
    if (widget.defaultDrop != null) {
      _dropAddrCtrl.text = (widget.defaultDrop!['address'] ?? '').toString();
      final la = widget.defaultDrop!['lat'], ln = widget.defaultDrop!['lng'];
      if (la != null) _dropLatCtrl.text = la.toString();
      if (ln != null) _dropLngCtrl.text = ln.toString();
    }
  }

  @override
  void dispose() {
    _pickupAddrCtrl.dispose();
    _pickupLatCtrl.dispose();
    _pickupLngCtrl.dispose();
    _dropAddrCtrl.dispose();
    _dropLatCtrl.dispose();
    _dropLngCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return; // Guard context usage
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double? _d(String s) => double.tryParse(s.trim());

  Future<void> _pickDateTime() async {
    // Date
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt.isBefore(now) ? now : _scheduledAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    ); // Material date picker for scheduling "Later" rides
    if (date == null) return;

    // Guard context usage before showing time picker (this fixes line 102)
    if (!mounted) return;

    // Time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    ); // Material time picker to finalize scheduled pickup time
    if (time == null) return;

    if (!mounted) return; // Guard setState after awaits
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _fetch() async {
    final lat1 = _d(_pickupLatCtrl.text);
    final lng1 = _d(_pickupLngCtrl.text);
    final lat2 = _d(_dropLatCtrl.text);
    final lng2 = _d(_dropLngCtrl.text);

    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      _snack('Please enter valid pickup and drop coordinates'); // Validation simplifies estimate errors
      return;
    }

    setState(() {
      _loading = true;
      _all = const [];
      _visible = const [];
      _providers.clear();
      _vehicles.clear();
    });

    final api = CabsApi();
    final whenIso = _mode == _WhenMode.later ? _scheduledAt.toIso8601String() : null;
    final providerFilter = widget.defaultProvider != null ? [widget.defaultProvider!] : null;

    final res = await api.priceEstimates(
      pickupLat: lat1,
      pickupLng: lng1,
      dropLat: lat2,
      dropLng: lng2,
      whenIso: whenIso,
      providers: providerFilter,
    );

    if (!mounted) return; // Guard after await

    res.fold(
      onSuccess: (list) {
        final items = list.map(_normalize).toList(growable: false);
        // Seed filters
        for (final e in items) {
          final p = (e['provider'] ?? '').toString();
          final v = (e['vehicle'] ?? '').toString();
          if (p.isNotEmpty) _providers.add(p);
          if (v.isNotEmpty) _vehicles.add(v);
        }
        if (!mounted) return; // Guard setState
        setState(() {
          _all = items;
          _visible = _apply(items);
          _loading = false;
        });
      },
      onError: (e) {
        if (!mounted) return; // Guard setState/snack
        setState(() => _loading = false);
        _snack(e.safeMessage);
      },
    );
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> m) {
    String? s(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    double? dnum(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // Example normalized shape
    return {
      'provider': s(['provider', 'source']) ?? 'provider',
      'vehicle': s(['vehicle', 'product', 'displayName']) ?? 'Ride',
      'productId': s(['productId', 'product_id']),
      'price': dnum(m['price'] ?? m['estimate']),
      'currency': s(['currency']) ?? widget.currency,
      'etaText': s(['etaText', 'eta']),
      'etaMinutes': dnum(m['etaMinutes'])?.round(),
    };
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> items) {
    var out = items.where((e) {
      final p = (e['provider'] ?? '').toString();
      final v = (e['vehicle'] ?? '').toString();
      final passProvider = _providers.isEmpty || _providers.contains(p);
      final passVehicle = _vehicles.isEmpty || _vehicles.contains(v);
      return passProvider && passVehicle;
    }).toList(growable: false);

    out.sort((a, b) {
      if (_sort == 'eta_asc') {
        final ea = a['etaMinutes'] as int? ?? 1 << 20;
        final eb = b['etaMinutes'] as int? ?? 1 << 20;
        return ea.compareTo(eb);
      }
      final pa = a['price'] as double? ?? 1e12;
      final pb = b['price'] as double? ?? 1e12;
      return pa.compareTo(pb);
    });

    return out;
  }

  void _toggleProvider(String p) {
    setState(() {
      if (_providers.contains(p)) {
        _providers.remove(p);
      } else {
        _providers.add(p);
      }
      _visible = _apply(_all);
    });
  }

  void _toggleVehicle(String v) {
    setState(() {
      if (_vehicles.contains(v)) {
        _vehicles.remove(v);
      } else {
        _vehicles.add(v);
      }
      _visible = _apply(_all);
    });
  }

  void _book(Map<String, dynamic> e) {
    final pickup = {
      'lat': _d(_pickupLatCtrl.text),
      'lng': _d(_pickupLngCtrl.text),
      'address': _pickupAddrCtrl.text.trim(),
    };
    final drop = {
      'lat': _d(_dropLatCtrl.text),
      'lng': _d(_dropLngCtrl.text),
      'address': _dropAddrCtrl.text.trim(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CabBookingScreen(
        title: 'Cab booking',
        defaultPickup: pickup,
        defaultDrop: drop,
        defaultProvider: (e['provider'] ?? '').toString(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd().add_jm();
    final whenLabel = _mode == _WhenMode.now ? 'Now' : df.format(_scheduledAt);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Pickup
            Text('Pickup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _pickupAddrCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pickupLatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Lat',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pickupLngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Lng',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Drop
            Text('Drop', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _dropAddrCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dropLatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Lat',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dropLngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Lng',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // When + fetch
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                SegmentedButton<_WhenMode>(
                  segments: const [
                    ButtonSegment(value: _WhenMode.now, label: Text('Now')),
                    ButtonSegment(value: _WhenMode.later, label: Text('Later')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ), // SegmentedButton is ideal for a small fixed set of choices
                const Spacer(),
                if (_mode == _WhenMode.later)
                  TextButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(whenLabel),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _fetch,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_loading ? 'Fetching options...' : 'Get options'),
              ),
            ),

            const SizedBox(height: 16),
            if (_all.isNotEmpty) _FiltersBar(
              all: _all,
              providers: _providers,
              vehicles: _vehicles,
              sort: _sort,
              onToggleProvider: _toggleProvider,
              onToggleVehicle: _toggleVehicle,
              onSortChanged: (v) => setState(() {
                _sort = v ?? 'price_asc';
                _visible = _apply(_all);
              }),
            ),

            const SizedBox(height: 8),
            if (_visible.isEmpty && _loading == false && _all.isNotEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No options match current filters'),
              )),

            if (_visible.isNotEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = _visible[i];
                    final currency = (e['currency'] ?? widget.currency).toString();
                    final price = e['price'] as double?;
                    final provider = (e['provider'] ?? '').toString();
                    final vehicle = (e['vehicle'] ?? '').toString();
                    final etaText = (e['etaText'] ?? '').toString();

                    return ListTile(
                      leading: CircleAvatar(child: Text(provider.isNotEmpty ? provider.toUpperCase() : '?')),
                      title: Text('$vehicle • $provider'),
                      subtitle: etaText.isEmpty ? null : Text('ETA: $etaText'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(price != null ? '$currency${price.toStringAsFixed(0)}' : '--',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _book(e),
                            child: const Text('Book'),
                          ),
                        ],
                      ),
                      onTap: () => _book(e),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.all,
    required this.providers,
    required this.vehicles,
    required this.sort,
    required this.onToggleProvider,
    required this.onToggleVehicle,
    required this.onSortChanged,
  });

  final List<Map<String, dynamic>> all;
  final Set<String> providers;
  final Set<String> vehicles;
  final String sort;
  final ValueChanged<String> onToggleProvider;
  final ValueChanged<String> onToggleVehicle;
  final ValueChanged<String?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final allProviders = <String>{};
    final allVehicles = <String>{};
    for (final e in all) {
      final p = (e['provider'] ?? '').toString();
      final v = (e['vehicle'] ?? '').toString();
      if (p.isNotEmpty) allProviders.add(p);
      if (v.isNotEmpty) allVehicles.add(v);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sort
        Row(
          children: [
            const Text('Sort:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: sort,
              items: const [
                DropdownMenuItem(value: 'price_asc', child: Text('Price (low → high)')),
                DropdownMenuItem(value: 'eta_asc', child: Text('ETA (soonest)')),
              ],
              onChanged: onSortChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Providers
        if (allProviders.isNotEmpty) ...[
          const Text('Providers', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allProviders.map((p) {
              final sel = providers.contains(p);
              return FilterChip(
                label: Text(p),
                selected: sel,
                onSelected: (_) => onToggleProvider(p),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        // Vehicles
        if (allVehicles.isNotEmpty) ...[
          const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allVehicles.map((v) {
              final sel = vehicles.contains(v);
              return FilterChip(
                label: Text(v),
                selected: sel,
                onSelected: (_) => onToggleVehicle(v),
              );
            }).toList(growable: false),
          ),
        ],
      ],
    );
  }
}
