// lib/features/journey/presentation/hotels/hotel_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/hotels_api.dart';

class HotelBookingScreen extends StatefulWidget {
  const HotelBookingScreen({
    super.key,
    required this.hotelId,
    required this.hotelName,
    required this.checkInIso,  // YYYY-MM-DD
    required this.checkOutIso, // YYYY-MM-DD
    this.currency = '₹',
  });

  final String hotelId;
  final String hotelName;
  final String checkInIso;
  final String checkOutIso;
  final String currency;

  @override
  State<HotelBookingScreen> createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends State<HotelBookingScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  // Dates
  late DateTime _checkIn;
  late DateTime _checkOut;

  // Guests / rooms
  int _rooms = 1;
  int _adults = 2;
  int _children = 0;
  final List<int> _childrenAges = [];

  // Selected rate/plan (simple normalization)
  Map<String, dynamic>? _selectedRate; // {id, name, refundable?, breakfast?, price?}

  // Fare
  bool _loadingFare = false;
  Map<String, dynamic>? _farePayload;

  // Booking
  bool _submitting = false;

  // Contact form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Rooms cache
  List<Map<String, dynamic>> _rates = const [];

  @override
  void initState() {
    super.initState();
    _checkIn = DateTime.parse(widget.checkInIso);
    _checkOut = DateTime.parse(widget.checkOutIso);
    _bootstrapRates();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapRates() async {
    final api = HotelsApi();
    final res = await api.rooms(
      hotelId: widget.hotelId,
      checkIn: _dfIso.format(_checkIn),
      checkOut: _dfIso.format(_checkOut),
      rooms: _rooms,
      adults: _adults,
      children: _children,
      childrenAges: _childrenAges,
    );
    res.fold(
      onSuccess: (data) {
        final list = (data['rates'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        setState(() {
          _rates = list;
          _selectedRate = list.isNotEmpty ? list.first : null;
        });
        _reprice();
      },
      onError: (e) => _snack(e.safeMessage ?? 'Failed to load room plans'),
    );
  }

  Future<void> _reprice() async {
    setState(() {
      _loadingFare = true;
      _farePayload = null;
    });
    final api = HotelsApi();
    final res = await api.price(
      hotelId: widget.hotelId,
      checkIn: _dfIso.format(_checkIn),
      checkOut: _dfIso.format(_checkOut),
      rooms: _rooms,
      adults: _adults,
      children: _children,
      childrenAges: _childrenAges,
      rateId: (_selectedRate?['id'] ?? '').toString(),
    );
    res.fold(
      onSuccess: (data) => setState(() {
        _farePayload = data;
        _loadingFare = false;
      }),
      onError: (e) {
        setState(() => _loadingFare = false);
        _snack(e.safeMessage ?? 'Failed to fetch price');
      },
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _checkIn.isBefore(now) ? now : _checkIn, end: _checkOut.isBefore(_checkIn) ? _checkIn.add(const Duration(days: 1)) : _checkOut),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    ); // showDateRangePicker is the standard Material dialog for date‑range selection in Flutter [21]
    if (range != null) {
      setState(() {
        _checkIn = DateTime(range.start.year, range.start.month, range.start.day);
        _checkOut = DateTime(range.end.year, range.end.month, range.end.day);
      });
      await _bootstrapRates();
    }
  }

  Future<void> _openGuestsRooms() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GuestsRoomsSheet(
        rooms: _rooms,
        adults: _adults,
        children: _children,
        childrenAges: _childrenAges,
      ),
    ); // showModalBottomSheet returns a Future that resolves with the result on pop for seamless data handoff [1][11]
    if (result != null) {
      setState(() {
        _rooms = result['rooms'] as int;
        _adults = result['adults'] as int;
        _children = result['children'] as int;
        _childrenAges
          ..clear()
          ..addAll((result['childrenAges'] as List).cast<int>());
      });
      await _bootstrapRates();
    }
  }

  Future<void> _openRatePicker() async {
    if (_rates.isEmpty) {
      _snack('No room plans available');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RateSheet(
        rates: _rates,
        currency: widget.currency,
        selectedId: (_selectedRate?['id'] ?? '').toString(),
      ),
    ); // Modal bottom sheets are ideal for contextual pickers like rate plans that may scroll or include CTAs [1][8]
    if (picked != null) {
      setState(() => _selectedRate = picked);
      await _reprice();
    }
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return; // Gate booking by Form validation for reliable data submission per Flutter cookbook guidance [6][9]

    setState(() => _submitting = true);
    final api = HotelsApi();

    final payload = {
      'stay': {
        'checkIn': _dfIso.format(_checkIn),
        'checkOut': _dfIso.format(_checkOut),
        'rooms': _rooms,
        'adults': _adults,
        'children': _children,
        'childrenAges': _childrenAges,
        'rateId': (_selectedRate?['id'] ?? '').toString(),
      },
      'contact': {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      },
      'payment': {
        'method': 'pay_later',
      },
    };

    final res = await api.book(hotelId: widget.hotelId, payload: payload);
    res.fold(
      onSuccess: (data) {
        _snack('Booking confirmed');
        Navigator.of(context).maybePop(data);
      },
      onError: (e) => _snack(e.safeMessage ?? 'Booking failed'),
    ); // Use ScaffoldMessenger.showSnackBar to surface async outcomes reliably across routes and nested scaffolds [7][10]

    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // ScaffoldMessenger is the modern API for SnackBars in Flutter [7][13]
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_dfLong.format(_checkIn)} — ${_dfLong.format(_checkOut)}';
    final paxLabel = '${_rooms}R • ${_adults}A${_children > 0 ? ' ${_children}C' : ''}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotelName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              dateLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Dates
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Check‑in • Check‑out'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDates,
            ), // Date‑range picker provides a full‑screen Material dialog for choosing the hotel stay window [21]

            const SizedBox(height: 8),

            // Guests & rooms
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(paxLabel),
              subtitle: const Text('Rooms • Guests'),
              trailing: const Icon(Icons.tune),
              onTap: _openGuestsRooms,
            ), // A modal bottom sheet is used to edit rooms and guest counts in a focused, contextual UI [1][2]

            const SizedBox(height: 8),

            // Rate plan
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(
                _selectedRate == null ? 'Select room plan' : (_selectedRate!['name']?.toString() ?? 'Room plan'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _selectedRate == null
                  ? null
                  : Text(
                      '${(_selectedRate!['refundable'] == true) ? 'Refundable' : 'Non‑refundable'}${(_selectedRate!['breakfast'] == true) ? ' • Breakfast included' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _openRatePicker,
            ), // Rate plan selection is presented via a bottom sheet that returns the chosen plan on pop [1][11]

            const SizedBox(height: 12),

            // Fare summary
            if (_loadingFare)
              const ListTile(
                leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text('Fetching price...'),
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
                  ), // Use Form + TextFormField validators per Flutter cookbook validation pattern [6][9]
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Special requests (optional)',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _book,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Processing...' : 'Confirm booking'),
              ),
            ), // Submit triggers booking and reports success/failure with ScaffoldMessenger SnackBars for clear feedback [7][13]
          ],
        ),
      ),
    );
  }
}

class _RateSheet extends StatelessWidget {
  const _RateSheet({
    required this.rates,
    required this.currency,
    required this.selectedId,
  });

  final List<Map<String, dynamic>> rates;
  final String currency;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Select room plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rates[i];
              final id = (r['id'] ?? '').toString();
              final name = (r['name'] ?? 'Room').toString();
              final refundable = r['refundable'] == true;
              final breakfast = r['breakfast'] == true;
              final price = r['price'] is num ? (r['price'] as num).toDouble() : null;

              return RadioListTile<String>(
                value: id,
                groupValue: selectedId,
                onChanged: (_) => Navigator.of(context).maybePop(r),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${refundable ? 'Refundable' : 'Non‑refundable'}${breakfast ? ' • Breakfast included' : ''}'),
                secondary: Text(
                  price != null ? '$currency${price.toStringAsFixed(0)}' : '--',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuestsRoomsSheet extends StatefulWidget {
  const _GuestsRoomsSheet({
    required this.rooms,
    required this.adults,
    required this.children,
    required this.childrenAges,
  });

  final int rooms;
  final int adults;
  final int children;
  final List<int> childrenAges;

  @override
  State<_GuestsRoomsSheet> createState() => _GuestsRoomsSheetState();
}

class _GuestsRoomsSheetState extends State<_GuestsRoomsSheet> {
  late int _rooms;
  late int _adults;
  late int _children;
  late List<int> _ages;

  @override
  void initState() {
    super.initState();
    _rooms = widget.rooms;
    _adults = widget.adults;
    _children = widget.children;
    _ages = [...widget.childrenAges];
    _syncAges();
  }

  void _syncAges() {
    if (_children < _ages.length) {
      _ages = _ages.take(_children).toList();
    } else {
      while (_ages.length < _children) {
        _ages.add(8);
      }
    }
  }

  void _close() {
    Navigator.of(context).maybePop({
      'rooms': _rooms,
      'adults': _adults,
      'children': _children,
      'childrenAges': _ages,
    });
  }

  Widget _counter(String label, int value, VoidCallback inc, VoidCallback dec, {bool disableDec = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(onPressed: disableDec ? null : dec, icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: inc, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Rooms & guests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: _close, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          _counter(
            'Rooms',
            _rooms,
            () => setState(() => _rooms += 1),
            () => setState(() => _rooms = _rooms > 1 ? _rooms - 1 : _rooms),
            disableDec: _rooms <= 1,
          ),
          const SizedBox(height: 8),
          _counter(
            'Adults',
            _adults,
            () => setState(() => _adults += 1),
            () => setState(() => _adults = _adults > 1 ? _adults - 1 : _adults),
            disableDec: _adults <= 1,
          ),
          const SizedBox(height: 8),
          _counter(
            'Children',
            _children,
            () => setState(() {
              _children += 1;
              _syncAges();
            }),
            () => setState(() {
              _children = _children > 0 ? _children - 1 : 0;
              _syncAges();
            }),
            disableDec: _children <= 0,
          ),
          if (_children > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Children ages', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_children, (i) {
                return DropdownButton<int>(
                  value: _ages[i],
                  items: List.generate(17, (a) => DropdownMenuItem(value: a, child: Text('$a'))),
                  onChanged: (v) => setState(() => _ages[i] = v ?? _ages[i]),
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.check_circle_outline),
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
    final total = _num(payload['total']);
    final base = _num(payload['base']);
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
                const Text('Price summary', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(money(total), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            _line('Room', money(base)),
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
