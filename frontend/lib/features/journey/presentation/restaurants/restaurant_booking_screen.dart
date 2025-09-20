// lib/features/journey/presentation/restaurants/restaurant_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RestaurantBookingScreen extends StatefulWidget {
  const RestaurantBookingScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.currency = '₹',
  });

  final String restaurantId;
  final String restaurantName;
  final String currency;

  @override
  State<RestaurantBookingScreen> createState() => _RestaurantBookingScreenState();
}

class _RestaurantBookingScreenState extends State<RestaurantBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Date & time
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _time;
  List<Map<String, dynamic>> _slots = const []; // [{id,label,isoStart,available}]
  String? _selectedSlotId;
  bool _loadingSlots = false;

  // Party
  int _guests = 2;
  String? _seating; // e.g., 'Indoor','Outdoor','Window'
  String? _occasion; // e.g., 'Birthday','Anniversary','Business'

  // Contact
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Submit
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
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSlots() async {
    setState(() {
      _loadingSlots = true;
      _slots = const [];
      _selectedSlotId = null;
    });

    // Capture localized formatter before async gap
    String formatTime(TimeOfDay t) => t.format(context);

    // Simulate API call; remove dependency on RestaurantsApi/PlacesApi
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Build demo slots without using context after await
    final demo = <Map<String, dynamic>>[];
    for (var i = 0; i < 6; i++) {
      final t = TimeOfDay(hour: 18 + (i ~/ 2), minute: (i % 2) * 30);
      final label = formatTime(t);
      demo.add({
        'id': 'SLOT-${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}',
        'label': label,
        'isoStart': '${_dfIso.format(_date)} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00',
        'available': i % 5 != 0,
      });
    }

    if (!mounted) return;
    setState(() {
      _slots = demo;
      _selectedSlotId = demo.isNotEmpty ? (demo.first['id']?.toString()) : null;
      _loadingSlots = false;
    });
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
      if (!mounted) return;
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _time = null;
        _selectedSlotId = null;
      });
      await _bootstrapSlots();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 30),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _time = picked;
        _selectedSlotId = null;
      });
    }
  }

  Future<void> _openPartySheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PartySheet(
        guests: _guests,
        seating: _seating,
        occasion: _occasion,
      ),
    );
    if (result != null) {
      if (!mounted) return;
      setState(() {
        _guests = result['guests'] as int;
        _seating = result['seating'] as String?;
        _occasion = result['occasion'] as String?;
      });
      await _bootstrapSlots();
    }
  }

  Future<void> _openSlotSheet() async {
    if (_slots.isEmpty) {
      _snack('No slots available. Pick a time manually.');
      return;
    }
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
      if (!mounted) return;
      setState(() {
        _selectedSlotId = picked;
        _time = null;
      });
    }
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_guests < 1) {
      _snack('Guests must be at least 1');
      return;
    }

    setState(() => _submitting = true);

    // Simulated booking (remove RestaurantsApi and bookReservation usage)
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    _snack('Reservation confirmed');
    Navigator.of(context).maybePop({
      'confirmation': 'RSV-${DateTime.now().millisecondsSinceEpoch}',
      'restaurantId': widget.restaurantId,
      'date': _dfIso.format(_date),
      'time': _selectedSlotId != null ? null : _toIsoTime(_time ?? const TimeOfDay(hour: 19, minute: 30)),
      'slotId': _selectedSlotId,
      'guests': _guests,
      'seating': _seating,
      'occasion': _occasion,
    });

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
        ? (_slots.firstWhere((s) => (s['id']?.toString()) == _selectedSlotId, orElse: () => const {})['label']?.toString() ?? '')
        : (_time != null ? _time!.format(context) : 'Pick time');

    final partyLabel = '$_guests guests'
        '${_seating != null ? ' • $_seating' : ''}'
        '${_occasion != null ? ' • $_occasion' : ''}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurantName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Date
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(dateStr),
              subtitle: const Text('Reservation date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),

            // Time or slots
            if (_loadingSlots)
              const ListTile(
                leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text('Loading time slots...'),
              )
            else if (_slots.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Timeslot'),
                subtitle: Text(
                  _selectedSlotId == null
                      ? 'Select timeslot'
                      : (_slots.firstWhere((s) => (s['id']?.toString()) == _selectedSlotId, orElse: () => const {})['label']?.toString() ?? ''),
                ),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                onTap: _openSlotSheet,
              )
            else
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Time'),
                subtitle: Text(timeStr),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickTime,
              ),

            const SizedBox(height: 8),

            // Party
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(partyLabel),
              subtitle: const Text('Guests • Seating • Occasion'),
              trailing: const Icon(Icons.tune),
              onTap: _openPartySheet,
            ),

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
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s);
                      return ok ? null : 'Enter valid email';
                    },
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
                label: Text(_submitting ? 'Processing...' : 'Confirm reservation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartySheet extends StatefulWidget {
  const _PartySheet({
    required this.guests,
    required this.seating,
    required this.occasion,
  });

  final int guests;
  final String? seating;
  final String? occasion;

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  late int _guests;
  late String? _seating;
  late String? _occasion;

  @override
  void initState() {
    super.initState();
    _guests = widget.guests;
    _seating = widget.seating;
    _occasion = widget.occasion;
  }

  void _close() {
    Navigator.of(context).maybePop({
      'guests': _guests,
      'seating': _seating,
      'occasion': _occasion,
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
    const seatings = ['Indoor', 'Outdoor', 'Window'];
    const occasions = ['Birthday', 'Anniversary', 'Business', 'Casual'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Party & preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: _close, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          _counter(
            'Guests',
            _guests,
            () => setState(() => _guests += 1),
            () => setState(() => _guests = _guests > 1 ? _guests - 1 : 1),
            disableDec: _guests <= 1,
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Text('Seating', style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: seatings.map((s) {
              final sel = _seating == s;
              return ChoiceChip(
                label: Text(s),
                selected: sel,
                onSelected: (_) => setState(() => _seating = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Text('Occasion', style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: occasions.map((o) {
              final sel = _occasion == o;
              return ChoiceChip(
                label: Text(o),
                selected: sel,
                onSelected: (_) => setState(() => _occasion = o),
              );
            }).toList(),
          ),
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

class _SlotSheet extends StatelessWidget {
  const _SlotSheet({required this.slots, required this.selectedId});

  final List<Map<String, dynamic>> slots;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              final isSel = selectedId == id;
              return ListTile(
                onTap: available ? () => Navigator.of(context).maybePop(id) : null,
                title: Text(label),
                subtitle: available ? null : const Text('Unavailable'),
                trailing: Icon(
                  isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSel ? Theme.of(context).colorScheme.primary : Colors.black45,
                ),
                enabled: available,
              );
            },
          ),
        ],
      ),
    );
  }
}
