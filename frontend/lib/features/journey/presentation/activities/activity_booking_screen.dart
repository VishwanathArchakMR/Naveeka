// lib/features/journey/presentation/activities/activity_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/activities_api.dart';
import '../../../../checkout/presentation/widgets/traveler_info.dart';

class ActivityBookingScreen extends StatefulWidget {
  const ActivityBookingScreen({
    super.key,
    required this.activityId,
    required this.activityTitle,
    this.currency = '₹',
    this.basePrice,
    this.defaultGuests = 1,
  });

  final String activityId;
  final String activityTitle;
  final String currency;
  final num? basePrice;
  final int defaultGuests;

  @override
  State<ActivityBookingScreen> createState() => _ActivityBookingScreenState();
}

class _ActivityBookingScreenState extends State<ActivityBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _travelerKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _guestsCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  bool _loadingSlots = false;
  bool _submitting = false;

  List<String> _slots = const <String>[];
  String? _selectedSlot;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _guestsCtrl.text = widget.defaultGuests.toString();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _loadSlots(); // try initial availability for today
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _guestsCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    ); // Material date picker dialog for booking date selection [1]
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
        _selectedSlot = null;
        _slots = const [];
      });
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    final guests = int.tryParse(_guestsCtrl.text.trim());
    if (guests == null || guests <= 0) {
      _snack('Please enter a valid number of guests');
      return;
    }
    setState(() {
      _loadingSlots = true;
      _slots = const [];
      _selectedSlot = null;
    });
    final api = ActivitiesApi();
    final res = await api.availability(
      activityId: widget.activityId,
      date: _dateCtrl.text.trim(),
      participants: guests,
    ); // Fetch availability with date and party size [9]
    res.fold(
      onSuccess: (data) {
        final list = (data['slots'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        setState(() {
          _slots = list;
          _loadingSlots = false;
          if (_slots.isNotEmpty) _selectedSlot = _slots.first;
        });
      },
      onError: (err) {
        setState(() => _loadingSlots = false);
        _snack(err.safeMessage ?? 'Failed to load availability');
      },
    );
  }

  String? _validateGuests(String? v) {
    final s = (v ?? '').trim();
    final n = int.tryParse(s);
    if (n == null || n <= 0) return 'Enter valid guests';
    return null;
  } // Form field validator pattern to ensure valid guests count [9][6]

  Future<void> _submit() async {
    // Validate booking form and traveler form
    final formOk = _formKey.currentState?.validate() ?? false;
    final travelerOk = _travelerKey.currentState?.validate() ?? false;
    if (!formOk || !travelerOk) return; // standard form validation check [9][6]
    if (_selectedSlot == null || _selectedSlot!.isEmpty) {
      _snack('Please select a time slot');
      return;
    }

    setState(() => _submitting = true);

    final payload = <String, dynamic>{
      'traveler': {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
      'schedule': {
        'date': _dateCtrl.text.trim(),
        'slot': _selectedSlot,
        'participants': int.parse(_guestsCtrl.text.trim()),
      },
      // Attach any optional extras or notes here
      'payment': {
        'method': 'pay_later', // replace with real method when integrating payment
      },
    };

    final api = ActivitiesApi();
    final res = await api.bookActivity(activityId: widget.activityId, payload: payload);
    res.fold(
      onSuccess: (data) {
        _snack('Booking confirmed');
        Navigator.of(context).maybePop(data);
      },
      onError: (err) {
        _snack(err.safeMessage ?? 'Booking failed');
      },
    );

    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } // Show SnackBar using the modern ScaffoldMessenger API [7][10]

  @override
  Widget build(BuildContext context) {
    final title = 'Book: ${widget.activityTitle}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Booking form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Date picker
                  TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.event),
                    ),
                    onTap: _pickDate,
                    validator: (v) => (v == null || v.isEmpty) ? 'Choose a date' : null,
                  ), // showDatePicker usage for date selection [1]
                  const SizedBox(height: 16),

                  // Guests
                  TextFormField(
                    controller: _guestsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Guests',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    validator: _validateGuests,
                    onChanged: (_) {
                      // Clear slots on party change to refetch
                      setState(() {
                        _slots = const [];
                        _selectedSlot = null;
                      });
                    },
                  ), // Validator ensures positive guest count using Form pattern [9][6]
                  const SizedBox(height: 16),

                  // Slots
                  if (_loadingSlots)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSlot,
                            items: _slots
                                .map((s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(growable: false),
                            onChanged: (v) => setState(() => _selectedSlot = v),
                            decoration: const InputDecoration(
                              labelText: 'Time slot',
                              prefixIcon: Icon(Icons.schedule),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Select a time slot' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loadSlots,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check'),
                        ),
                      ],
                    ), // Dropdown + refresh to present and reload available slots [9]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Traveler form (reusing validated widget)
            TravelerInfo(
              formKey: _travelerKey,
              nameCtrl: _nameCtrl,
              emailCtrl: _emailCtrl,
              phoneCtrl: _phoneCtrl,
            ), // Validated Form section for traveler details using standard pattern [9][6]

            const SizedBox(height: 24),

            // Price hint
            if (widget.basePrice != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'From ${widget.currency}${widget.basePrice!.toStringAsFixed(0)} per person',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Processing...' : 'Confirm booking'),
              ),
            ), // Submit triggers server-side booking and shows SnackBar via ScaffoldMessenger [7][10]
          ],
        ),
      ),
    );
  }
}
