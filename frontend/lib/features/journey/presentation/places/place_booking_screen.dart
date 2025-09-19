// lib/features/journey/presentation/places/place_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/places_api.dart';

class PlaceBookingScreen extends StatefulWidget {
  const PlaceBookingScreen({
    super.key,
    required this.placeId,
    required this.title,
    this.currency = '₹',
  });

  final String placeId;
  final String title;
  final String currency;

  @override
  State<PlaceBookingScreen> createState() => _PlaceBookingScreenState();
}

class _PlaceBookingScreenState extends State<PlaceBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Date & time / slots
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _time;
  List<Map<String, dynamic>> _slots = const []; // [{id,label,isoStart,available}]
  String? _selectedSlotId;

  // Tickets
  int _adults = 1;
  int _children = 0;
  int _seniors = 0;

  // Contact
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Pricing
  bool _pricing = false;
  Map<String, dynamic>? _fare;

  // Booking
  bool _submitting = false;

  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _bootstrapSlots();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSlots() async {
    final api = PlacesApi();
    final res = await api.availableSlots(
      placeId: widget.placeId,
      date: _dfIso.format(_date),
    );
    res.fold(
      onSuccess: (data) {
        final list = (data['slots'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        if (!mounted) return;
        setState(() {
          _slots = list;
          _selectedSlotId = list.isNotEmpty ? (list.first['id']?.toString()) : null;
        });
        _reprice();
      },
      onError: (e) => _snack(e.safeMessage ?? 'Failed to load timeslots'),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _time = null; // reset manual time if switching date
        _selectedSlotId = null;
      });
      await _bootstrapSlots();
    }
  }

  Future<void> _pickTimeManually() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _selectedSlotId = null; // prefer manual time over a pre-defined slot
      });
      await _reprice();
    }
  }

  Future<void> _openTicketSheet() async {
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TicketSheet(adults: _adults, children: _children, seniors: _seniors),
    );
    if (result != null) {
      setState(() {
        _adults = result['adults'] ?? _adults;
        _children = result['children'] ?? _children;
        _seniors = result['seniors'] ?? _seniors;
      });
      await _reprice();
    }
  }

  Future<void> _reprice() async {
    setState(() {
      _pricing = true;
      _fare = null;
    });

    final api = PlacesApi();
    final body = {
      'date': _dfIso.format(_date),
      'time': _selectedSlotId != null ? null : (_time != null ? _toIsoTime(_time!) : null),
      'slotId': _selectedSlotId,
      'tickets': {
        'adults': _adults,
        'children': _children,
        'seniors': _seniors,
      },
    };

    final res = await api.price(placeId: widget.placeId, payload: body);
    res.fold(
      onSuccess: (data) {
        if (!mounted) return;
        setState(() {
          _fare = data;
          _pricing = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _pricing = false);
        _snack(e.safeMessage ?? 'Failed to fetch price');
      },
    );
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_adults + _children + _seniors <= 0) {
      _snack('Select at least 1 ticket');
      return;
    }

    setState(() => _submitting = true);

    final api = PlacesApi();
    final payload = {
      'date': _dfIso.format(_date),
      'time': _selectedSlotId != null ? null : (_time != null ? _toIsoTime(_time!) : null),
      'slotId': _selectedSlotId,
      'tickets': {
        'adults': _adults,
        'children': _children,
        'seniors': _seniors,
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

    final res = await api.book(placeId: widget.placeId, payload: payload);
    res.fold(
      onSuccess: (data) {
        _snack('Booking confirmed');
        Navigator.of(context).maybePop(data);
      },
      onError: (e) => _snack(e.safeMessage ?? 'Booking failed'),
    );

    if (mounted) setState(() => _submitting = false);
  }

  String _toIsoTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _dfLong.format(_date);
    final timeStr = _selectedSlotId != null
        ? (() {
            final slot = _slots.firstWhere(
              (s) => (s['id']?.toString()) == _selectedSlotId,
              orElse: () => <String, dynamic>{},
            );
            return (slot['label'] ?? '').toString();
          })()
        : (_time != null ? _time!.format(context) : 'Any time');

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Date
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(dateStr),
              subtitle: const Text('Experience date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),

            // Slot or time
            if (_slots.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Timeslot'),
                subtitle: Text(
                  _selectedSlotId == null
                      ? 'Select timeslot'
                      : (() {
                          final slot = _slots.firstWhere(
                            (s) => (s['id']?.toString()) == _selectedSlotId,
                            orElse: () => <String, dynamic>{},
                          );
                          return (slot['label'] ?? '').toString();
                        })(),
                ),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) => _SlotSheet(slots: _slots, selectedId: _selectedSlotId),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedSlotId = picked;
                      _time = null;
                    });
                    await _reprice();
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Time'),
                subtitle: Text(timeStr),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickTimeManually,
              ),

            const SizedBox(height: 8),

            // Tickets
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text('$_adults Adults${_children > 0 ? ' • $_children Children' : ''}${_seniors > 0 ? ' • $_seniors Seniors' : ''}'),
              subtitle: const Text('Tickets'),
              trailing: const Icon(Icons.tune),
              onTap: _openTicketSheet,
            ),

            const SizedBox(height: 12),

            // Fare
            if (_pricing)
              const ListTile(
                leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text('Fetching price...'),
              )
            else if (_fare != null)
              _FareSummary(payload: _fare!, currency: widget.currency),

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
                  ),
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
                      labelText: 'Notes (optional)',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSheet extends StatefulWidget {
  const _TicketSheet({required this.adults, required this.children, required this.seniors});

  final int adults;
  final int children;
  final int seniors;

  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends State<_TicketSheet> {
  late int _adults;
  late int _children;
  late int _seniors;

  @override
  void initState() {
    super.initState();
    _adults = widget.adults;
    _children = widget.children;
    _seniors = widget.seniors;
  }

  Widget _row(String label, int value, VoidCallback inc, VoidCallback dec, {bool disableDec = false}) {
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

  void _close() {
    Navigator.of(context).maybePop({
      'adults': _adults,
      'children': _children,
      'seniors': _seniors,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tickets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(onPressed: _close, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            _row('Adults', _adults, () => setState(() => _adults += 1),
                () => setState(() => _adults = _adults > 0 ? _adults - 1 : 0)),
            const SizedBox(height: 8),
            _row('Children', _children, () => setState(() => _children += 1),
                () => setState(() => _children = _children > 0 ? _children - 1 : 0)),
            const SizedBox(height: 8),
            _row('Seniors', _seniors, () => setState(() => _seniors += 1),
                () => setState(() => _seniors = _seniors > 0 ? _seniors - 1 : 0)),
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
      ),
    );
  }
}

class _SlotSheet extends StatelessWidget {
  const _SlotSheet({required this.slots, required this.selectedId});

  final List<Map<String, dynamic>> slots;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Select timeslot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = slots[i];
                final id = (s['id'] ?? '').toString();
                final label = (s['label'] ?? '').toString();
                final available = s['available'] != false;
                final selected = id == selectedId;
                return ListTile(
                  onTap: available ? () => Navigator.of(context).maybePop(id) : null,
                  title: Text(label),
                  subtitle: available ? null : const Text('Unavailable'),
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  trailing: available ? null : const Icon(Icons.block),
                );
              },
            ),
          ],
        ),
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
            _line('Tickets', money(base)),
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
