// lib/features/journey/presentation/buses/bus_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/buses_api.dart';
import 'widgets/bus_stop_selector.dart';

class BusBookingScreen extends StatefulWidget {
  const BusBookingScreen({
    super.key,
    required this.busId,
    required this.title, // operator + route label for AppBar
    required this.date, // YYYY-MM-DD
    required this.fromCode,
    required this.toCode,
    this.currency = '₹',
  });

  final String busId;
  final String title;
  final String date; // ISO date
  final String fromCode;
  final String toCode;
  final String currency;

  @override
  State<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends State<BusBookingScreen> {
  // Stops
  String? _boardingId;
  String? _droppingId;
  Map<String, dynamic>? _boarding;
  Map<String, dynamic>? _dropping;

  // Seats
  final Set<String> _selectedSeats = {};

  // Fare data
  Map<String, dynamic>? _farePayload;
  bool _loadingFare = false;
  bool _submitting = false;

  // Contact form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Cache seat map to avoid refetching repeatedly (simple shape)
  List<String> _availableSeats = const <String>[];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _openStopSelector() async {
    // In real flow, these lists should come from trip details; here assume available via API or parent screen.
    // For demo, pull from seatMap metadata if provided, else use empty arrays.
    // Consider wiring resolved boarding/dropping points from the search result payload.

    final res = await BusStopSelector.show(
      context,
      boardingStops: (_farePayload?['boardingPoints'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      droppingStops: (_farePayload?['droppingPoints'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      initialBoardingId: _boardingId,
      initialDroppingId: _droppingId,
      title: 'Select boarding & dropping',
    ); // Presents as a modal bottom sheet and returns selection on pop [1]

    if (!mounted) return;
    if (res != null) {
      setState(() {
        _boardingId = res['boardingId'] as String?;
        _droppingId = res['droppingId'] as String?;
        _boarding = res['boarding'] as Map<String, dynamic>?;
        _dropping = res['dropping'] as Map<String, dynamic>?;
      });
      await _reprice();
    }
  }

  Future<void> _openSeatPicker() async {
    // Load seat map if not cached
    if (_availableSeats.isEmpty) {
      final api = BusesApi();
      final seatRes = await api.seatMap(id: widget.busId, date: widget.date);
      if (!mounted) return;
      seatRes.fold(
        onSuccess: (data) {
          // Expecting { seats: [{id:'U1', available:true}, ...] }
          final seats = (data['seats'] as List?)
                  ?.where((e) => e is Map && (e['available'] == true || e['available'] == null))
                  .map((e) => (e['id'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toList() ??
              <String>[];
          setState(() => _availableSeats = seats);
        },
        onError: (err) {
          _snack(err.safeMessage);
        },
      );
    }

    // Show a simple grid sheet to pick seats quickly
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SeatGridSheet(
        allSeats: _availableSeats,
        initial: _selectedSeats,
        currency: widget.currency,
      ),
    ); // Bottom sheet is the standard pattern for contextual pickers in Flutter [1][2]

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedSeats.clear();
        _selectedSeats.addAll(picked);
      });
      await _reprice();
    }
  }

  Future<void> _reprice() async {
    if (_selectedSeats.isEmpty) {
      setState(() => _farePayload = null);
      return;
    }
    setState(() => _loadingFare = true);
    final api = BusesApi();
    final res = await api.fares(
      id: widget.busId,
      date: widget.date,
      seats: _selectedSeats.toList(growable: false),
      boardingPointId: _boardingId,
      droppingPointId: _droppingId,
      passengers: _selectedSeats.length,
    ); // Query fares with selected seats, date, and optional boarding/dropping [1]

    if (!mounted) return;
    res.fold(
      onSuccess: (data) {
        setState(() {
          _farePayload = data;
          _loadingFare = false;
        });
      },
      onError: (err) {
        setState(() {
          _loadingFare = false;
          _farePayload = null;
        });
        _snack(err.safeMessage);
      },
    );
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return; // Validates Form with a GlobalKey per cookbook guidance [6]
    if (_selectedSeats.isEmpty) {
      _snack('Select at least one seat');
      return;
    }
    if (_boardingId == null || _droppingId == null) {
      _snack('Select boarding and dropping points');
      return;
    }

    setState(() => _submitting = true);

    final payload = <String, dynamic>{
      'traveler': {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
      'contact': {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
      'seats': _selectedSeats.toList(),
      'date': widget.date,
      'boarding': _boardingId,
      'dropping': _droppingId,
      'payment': {
        'method': 'pay_later',
      },
    };

    final api = BusesApi();
    final res = await api.book(id: widget.busId, payload: payload);
    if (!mounted) return;
    res.fold(
      onSuccess: (data) {
        _snack('Booking confirmed');
        if (mounted) Navigator.of(context).maybePop(data);
      },
      onError: (err) {
        _snack(err.safeMessage);
      },
    );

    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // Modern SnackBar API [7][10]
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Travel date: ${widget.date} • ${df.format(DateTime.parse(widget.date))}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Stops
            ListTile(
              leading: const Icon(Icons.transfer_within_a_station),
              title: const Text('Boarding & Dropping'),
              subtitle: Text(
                '${_boarding?['name'] ?? 'Select boarding'} → ${_dropping?['name'] ?? 'Select dropping'}',
              ),
              trailing: OutlinedButton.icon(
                onPressed: _openStopSelector,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Choose'),
              ),
            ), // Use list row + bottom sheet per modal selector guidance [1][8]

            const SizedBox(height: 8),

            // Seats
            ListTile(
              leading: const Icon(Icons.event_seat_outlined),
              title: const Text('Seats'),
              subtitle: Text(
                _selectedSeats.isEmpty ? 'No seats selected' : _selectedSeats.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: FilledButton.icon(
                onPressed: _openSeatPicker,
                icon: const Icon(Icons.chair_alt_outlined),
                label: const Text('Select'),
              ),
            ),

            const SizedBox(height: 12),

            // Fare summary
            if (_loadingFare)
              const ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Fetching fare...'),
              )
            else if (_farePayload != null)
              _FareSummary(payload: _farePayload!, currency: widget.currency),

            const SizedBox(height: 16),

            // Contact form
            Text('Contact details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  ), // Form + validator pattern follows Flutter cookbook [6][12]
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter email';
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s);
                      return ok ? null : 'Enter valid email';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().length < 7) ? 'Enter valid phone' : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Processing...' : 'Confirm booking'),
              ),
            ), // Submit gated by Form validation and selections, with snackbar feedback [6][7]
          ],
        ),
      ),
    );
  }
}

class _SeatGridSheet extends StatefulWidget {
  const _SeatGridSheet({
    required this.allSeats,
    required this.initial,
    required this.currency,
  });

  final List<String> allSeats;
  final Set<String> initial;
  final String currency;

  @override
  State<_SeatGridSheet> createState() => _SeatGridSheetState();
}

class _SeatGridSheetState extends State<_SeatGridSheet> {
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final seats = widget.allSeats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Select seats', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(_picked),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, i) {
                final id = seats[i];
                final sel = _picked.contains(id);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (sel) {
                        _picked.remove(id);
                      } else {
                        _picked.add(id);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      id,
                      style: TextStyle(
                        color: sel ? Theme.of(context).colorScheme.onPrimary : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(_picked),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FareSummary extends StatelessWidget {
  const _FareSummary({required this.payload, required this.currency});

  final Map<String, dynamic> payload;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Accept { total, baseFare, taxes, fees, breakdown: [...] }
    final total = _num(payload['total']);
    final base = _num(payload['baseFare']);
    final taxes = _num(payload['taxes']);
    final fees = _num(payload['fees']);

    String money(num? v) => v == null ? '-' : '$currency${v.toStringAsFixed(0)}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Fare summary', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(money(total), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            _line('Base', money(base)),
            _line('Taxes', money(taxes)),
            _line('Fees', money(fees)),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
    }
}
