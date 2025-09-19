// lib/features/journey/presentation/flights/flight_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightBookingScreen extends StatefulWidget {
  const FlightBookingScreen({
    super.key,
    required this.flightId,
    required this.title, // e.g., "DEL → BLR"
    required this.date,  // YYYY-MM-DD (journey date)
    this.currency = '₹',
  });

  final String flightId;
  final String title;
  final String date;
  final String currency;

  @override
  State<FlightBookingScreen> createState() => _FlightBookingScreenState();
}

class _FlightBookingScreenState extends State<FlightBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Pax counts
  int _adults = 1;
  int _children = 0;
  int _infants = 0;

  // Contact
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // Pax forms (flat lists)
  late List<_PaxModel> _adultModels;
  late List<_PaxModel> _childModels;
  late List<_PaxModel> _infantModels;

  // Seat selection: segmentId -> seatIds
  final Map<String, Set<String>> _selectedSeatsBySegment = {};

  // Fare repricing
  bool _loadingFare = false;
  Map<String, dynamic>? _farePayload;

  // Booking state
  bool _submitting = false;

  // Segment metadata / seat map cache
  List<Map<String, dynamic>> _segments = const []; // [{segmentId, from, to, dep, arr}]
  final Map<String, List<String>> _seatCache = {}; // segmentId -> available seat IDs

  @override
  void initState() {
    super.initState();
    _adultModels = List.generate(_adults, (i) => _PaxModel(adult: true));
    _childModels = List.generate(_children, (i) => _PaxModel(child: true));
    _infantModels = List.generate(_infants, (i) => _PaxModel(infant: true));
    _bootstrapSegments();
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    for (final m in [..._adultModels, ..._childModels, ..._infantModels]) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrapSegments() async {
    // Stub segments so UI works while backend wiring is pending.
    try {
      const segId = 'LEG-1';
      setState(() {
        _segments = [
          {
            'segmentId': segId,
            'from': widget.title.split('→').first.trim(),
            'to': widget.title.split('→').last.trim(),
            'dep': '${widget.date}T08:00:00Z',
            'arr': '${widget.date}T10:00:00Z',
          },
        ];
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Failed to load flight segments');
    }
  }

  void _changeCounts({int? adults, int? children, int? infants}) {
    setState(() {
      if (adults != null && adults >= 1) {
        _adults = adults;
        _adultModels = _resize(_adultModels, _adults, () => _PaxModel(adult: true));
        if (_infants > _adults) {
          _infants = _adults;
          _infantModels = _resize(_infantModels, _infants, () => _PaxModel(infant: true));
        }
      }
      if (children != null && children >= 0) {
        _children = children;
        _childModels = _resize(_childModels, _children, () => _PaxModel(child: true));
      }
      if (infants != null && infants >= 0 && infants <= _adults) {
        _infants = infants;
        _infantModels = _resize(_infantModels, _infants, () => _PaxModel(infant: true));
      }
    });
  }

  List<T> _resize<T>(List<T> list, int newLen, T Function() create) {
    if (newLen <= list.length) return List<T>.from(list.take(newLen));
    final out = List<T>.from(list);
    while (out.length < newLen) {
      out.add(create());
    }
    return out;
  }

  Future<void> _openSeatPicker(String segmentId) async {
    // Stub seat map
    if (!_seatCache.containsKey(segmentId)) {
      final stub = <String>[];
      for (final row in ['A', 'B', 'C', 'D']) {
        for (var n = 1; n <= 6; n++) {
          stub.add('$row$n');
        }
      }
      setState(() => _seatCache[segmentId] = stub);
    }

    final initial = _selectedSeatsBySegment[segmentId] ?? <String>{};
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SeatGridSheet(
        allSeats: _seatCache[segmentId] ?? const <String>[],
        initial: initial,
        currency: widget.currency,
        title: 'Select seats ($segmentId)',
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedSeatsBySegment[segmentId] = picked);
      await _reprice();
    }
  }

  Future<void> _reprice() async {
    setState(() {
      _loadingFare = true;
      _farePayload = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
    const baseAdt = 3500;
    const baseChd = 2800;
    const baseInf = 800;
    const seatFee = 200;

    final paxBase = (_adults * baseAdt) + (_children * baseChd) + (_infants * baseInf);
    final seatCount = _selectedSeatsBySegment.values.fold<int>(0, (p, s) => p + s.length);
    final fees = seatCount * seatFee;
    final taxes = (paxBase * 0.12).round();
    final total = paxBase + taxes + fees;

    setState(() {
      _farePayload = {
        'baseFare': paxBase,
        'taxes': taxes,
        'fees': fees,
        'total': total,
      };
      _loadingFare = false;
    });
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_adults < 1) {
      _snack('At least 1 adult required');
      return;
    }

    setState(() => _submitting = true);

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _snack('Booking confirmed');
    Navigator.of(context).maybePop({
      'confirmation': 'FL-${DateTime.now().millisecondsSinceEpoch}',
      'fare': _farePayload,
    });

    if (mounted) setState(() => _submitting = false);
  }

  Map<String, dynamic> _buildPricePayload({required bool includePassengers, required bool includeSeats}) {
    final pax = <Map<String, dynamic>>[];

    if (includePassengers) {
      pax.addAll(_adultModels.map((m) => m.toJson('ADT')));
      pax.addAll(_childModels.map((m) => m.toJson('CHD')));
      pax.addAll(_infantModels.map((m) => m.toJson('INF')));
    }

    final seats = includeSeats
        ? _selectedSeatsBySegment.map((k, v) => MapEntry(k, v.toList(growable: false)))
        : const <String, List<String>>{};

    return {
      'passengers': pax,
      'seats': seats,
      'contact': {
        'name': _contactNameCtrl.text.trim(),
        'email': _contactEmailCtrl.text.trim(),
        'phone': _contactPhoneCtrl.text.trim(),
      },
    };
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            // Pax counts
            _PaxCounterRow(
              adults: _adults,
              children: _children,
              infants: _infants,
              onChanged: _changeCounts,
            ),

            const SizedBox(height: 16),

            // Passenger forms
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_adultModels.isNotEmpty)
                    _PaxSection(
                      title: 'Adults',
                      pax: _adultModels,
                    ),
                  if (_childModels.isNotEmpty)
                    _PaxSection(
                      title: 'Children',
                      pax: _childModels,
                    ),
                  if (_infantModels.isNotEmpty)
                    _PaxSection(
                      title: 'Infants',
                      pax: _infantModels,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Seat selection per segment
            if (_segments.isNotEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seats', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._segments.map((s) {
                        final segId = (s['segmentId'] ?? '').toString();
                        final from = (s['from'] ?? '').toString();
                        final to = (s['to'] ?? '').toString();
                        final list = _selectedSeatsBySegment[segId]?.toList() ?? const <String>[];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$from → $to',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                list.isEmpty ? 'No seats' : list.join(', '),
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _openSeatPicker(segId),
                                icon: const Icon(Icons.event_seat_outlined),
                                label: const Text('Select'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Contact details
            Text('Contact details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Enter email';
                final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                return re.hasMatch(s) ? null : 'Enter valid email';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.call_outlined),
              ),
              validator: (v) => (v == null || v.trim().length < 7) ? 'Enter valid phone' : null,
            ),

            const SizedBox(height: 16),

            // Fare summary
            if (_loadingFare)
              const ListTile(
                leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text('Fetching fare...'),
              )
            else if (_farePayload != null)
              _FareSummary(payload: _farePayload!, currency: widget.currency),

            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingFare ? null : _reprice,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reprice'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _submitting ? null : _book,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_submitting ? 'Processing...' : 'Confirm booking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaxSection extends StatelessWidget {
  const _PaxSection({required this.title, required this.pax});
  final String title;
  final List<_PaxModel> pax;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...List.generate(pax.length, (i) => _PaxForm(index: i + 1, model: pax[i])),
          ],
        ),
      ),
    );
  }
}

class _PaxForm extends StatefulWidget {
  const _PaxForm({required this.index, required this.model});
  final int index;
  final _PaxModel model;

  @override
  State<_PaxForm> createState() => _PaxFormState();
}

class _PaxFormState extends State<_PaxForm> {
  final _df = DateFormat('yyyy-MM-dd');

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.model.dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => widget.model.dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Title
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  initialValue: m.title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  items: const [
                    DropdownMenuItem(value: 'MR', child: Text('Mr')),
                    DropdownMenuItem(value: 'MS', child: Text('Ms')),
                    DropdownMenuItem(value: 'MRS', child: Text('Mrs')),
                    DropdownMenuItem(value: 'MSTR', child: Text('Master')),
                    DropdownMenuItem(value: 'MISS', child: Text('Miss')),
                  ],
                  onChanged: (v) => setState(() => m.title = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              // First name
              Expanded(
                child: TextFormField(
                  controller: m.firstCtrl,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              // Last name
              Expanded(
                child: TextFormField(
                  controller: m.lastCtrl,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Gender (optional quick selector)
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: m.gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Male')),
                    DropdownMenuItem(value: 'F', child: Text('Female')),
                    DropdownMenuItem(value: 'O', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => m.gender = v),
                ),
              ),
              const SizedBox(width: 8),
              // DOB
              Expanded(
                child: InkWell(
                  onTap: _pickDob,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.event),
                    ),
                    child: Text(
                      m.dob == null ? 'Select' : _df.format(m.dob!),
                      style: TextStyle(
                        color: m.dob == null ? Colors.black54 : null,
                        fontWeight: m.dob == null ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaxCounterRow extends StatelessWidget {
  const _PaxCounterRow({
    required this.adults,
    required this.children,
    required this.infants,
    required this.onChanged,
  });

  final int adults;
  final int children;
  final int infants;
  final void Function({int? adults, int? children, int? infants}) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, int value, {required VoidCallback plus, required VoidCallback minus, bool disabledMinus = false}) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: disabledMinus ? null : minus,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: plus,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item(
          'Adults',
          adults,
          plus: () => onChanged(adults: adults + 1),
          minus: () => onChanged(adults: adults > 1 ? adults - 1 : adults),
          disabledMinus: adults <= 1,
        ),
        item(
          'Children',
          children,
          plus: () => onChanged(children: children + 1),
          minus: () => onChanged(children: children > 0 ? children - 1 : children),
          disabledMinus: children <= 0,
        ),
        item(
          'Infants',
          infants,
          plus: () => onChanged(infants: infants < adults ? infants + 1 : infants),
          minus: () => onChanged(infants: infants > 0 ? infants - 1 : infants),
          disabledMinus: infants <= 0,
        ),
      ],
    );
  }
}

class _SeatGridSheet extends StatefulWidget {
  const _SeatGridSheet({
    required this.allSeats,
    required this.initial,
    required this.currency,
    this.title = 'Select seats',
  });

  final List<String> allSeats;
  final Set<String> initial;
  final String currency;
  final String title;

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
            Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(_picked), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.2,
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

class _PaxModel {
  _PaxModel({this.adult = false, this.child = false, this.infant = false});

  final bool adult;
  final bool child;
  final bool infant;

  String? title;
  String? gender;
  DateTime? dob;

  final firstCtrl = TextEditingController();
  final lastCtrl = TextEditingController();

  Map<String, dynamic> toJson(String type) {
    return {
      'type': type, // ADT/CHD/INF
      'title': title,
      'firstName': firstCtrl.text.trim(),
      'lastName': lastCtrl.text.trim(),
      'gender': gender,
      'dob': dob?.toIso8601String(),
    };
  }

  void dispose() {
    firstCtrl.dispose();
    lastCtrl.dispose();
  }
}
