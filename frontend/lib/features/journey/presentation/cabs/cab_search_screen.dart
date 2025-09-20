// lib/features/journey/presentation/cabs/cab_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cab_options_screen.dart';

class CabSearchScreen extends StatefulWidget {
  const CabSearchScreen({
    super.key,
    this.title = 'Search cabs',
    this.defaultProvider, // e.g., 'inhouse'|'ola'|'uber'
  });

  final String title;
  final String? defaultProvider;

  @override
  State<CabSearchScreen> createState() => _CabSearchScreenState();
}

enum _WhenMode { now, later }

class _CabSearchScreenState extends State<CabSearchScreen> {
  // Pickup
  final _pickupAddrCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();

  // Drop
  final _dropAddrCtrl = TextEditingController();
  final _dropLatCtrl = TextEditingController();
  final _dropLngCtrl = TextEditingController();

  // When
  _WhenMode _mode = _WhenMode.now;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 20));

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

  void _swapEnds() {
    final pa = _pickupAddrCtrl.text, pla = _pickupLatCtrl.text, pln = _pickupLngCtrl.text;
    setState(() {
      _pickupAddrCtrl.text = _dropAddrCtrl.text;
      _pickupLatCtrl.text = _dropLatCtrl.text;
      _pickupLngCtrl.text = _dropLngCtrl.text;
      _dropAddrCtrl.text = pa;
      _dropLatCtrl.text = pla;
      _dropLngCtrl.text = pln;
    });
  } // Simple swap action improves UX for reversed routes without retyping

  double? _d(String s) => double.tryParse(s.trim());

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt.isBefore(now) ? now : _scheduledAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    ); // Use showDatePicker for selecting a scheduled pickup date in a Material-compliant dialog
    if (date == null) return;

    // Guard context usage before showing time picker (this fixes line 78)
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    ); // Use showTimePicker to capture the pickup time for "Later" flow
    if (time == null) return;

    if (!mounted) return; // Guard setState after awaits
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _continue() {
    // Basic validation: coordinates are strongly recommended for accurate estimates
    final lat1 = _d(_pickupLatCtrl.text), lng1 = _d(_pickupLngCtrl.text);
    final lat2 = _d(_dropLatCtrl.text), lng2 = _d(_dropLngCtrl.text);
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      _snack('Please enter valid pickup and drop coordinates'); // Guard against navigating with invalid inputs
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CabOptionsScreen(
        title: 'Cab options',
        defaultProvider: widget.defaultProvider,
        defaultPickup: {
          'address': _pickupAddrCtrl.text.trim(),
          'lat': lat1,
          'lng': lng1,
        },
        defaultDrop: {
          'address': _dropAddrCtrl.text.trim(),
          'lat': lat2,
          'lng': lng2,
        },
      ),
    )); // Push into CabOptionsScreen with structured defaults to fetch estimates and proceed to booking
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd().add_jm();
    final whenLabel = _mode == _WhenMode.now ? 'Now' : df.format(_scheduledAt);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
            ), // Free-form address helps riders optionally label coordinates for clarity in confirmation and driver instructions
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
            ), // Numeric lat/lng fields ensure precise geocoding-free estimates for providers

            const SizedBox(height: 16),
            // Drop
            Row(
              children: [
                Expanded(child: Text('Drop', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Swap',
                  onPressed: _swapEnds,
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dropAddrCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ), // Optional address aids human-readable summaries and receipts
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
            ), // Collect destination coordinates for accurate prices and ETAs across providers

            const SizedBox(height: 16),
            // When
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
                ), // SegmentedButton is ideal for selecting among a small set like "Now" vs "Later"
                const Spacer(),
                if (_mode == _WhenMode.later)
                  TextButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(whenLabel),
                  ),
              ],
            ), // Date/time picker path only appears when scheduling a later pickup for clarity and simplicity

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.search),
                label: const Text('See options'),
              ),
            ), // CTA validates essential inputs and routes to the options screen where estimates are fetched and refined
          ],
        ),
      ),
    );
  }
}
