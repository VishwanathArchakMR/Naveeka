// lib/features/journey/presentation/trains/train_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/trains_api.dart';

class TrainBookingScreen extends StatefulWidget {
  const TrainBookingScreen({
    super.key,
    required this.trainId,
    required this.trainName,
    required this.fromCode,
    required this.toCode,
    required this.departureIso, // YYYY-MM-DD
    this.currency = '₹',
    this.initialClassCode, // e.g., '3A','SL','2S'
    this.initialQuota, // e.g., 'GN','TQ','PT'
  });

  final String trainId;
  final String trainName;
  final String fromCode;
  final String toCode;
  final String departureIso;
  final String currency;

  final String? initialClassCode;
  final String? initialQuota;

  @override
  State<TrainBookingScreen> createState() => _TrainBookingScreenState();
}

class _TrainBookingScreenState extends State<TrainBookingScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  // Travel date
  late DateTime _date;

  // Class & quota
  String? _classCode;
  String? _quota;

  // Passengers
  final _formKey = GlobalKey<FormState>();
  final List<_Pax> _pax = [const _Pax(type: 'Adult')]; // at least one adult
  bool _lowerBerthPref = false;
  bool _sideBerthOk = true;

  // Fare
  bool _pricing = false;
  Map<String, dynamic>? _fare;

  // Submit
  bool _submitting = false;

  // Contact
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.departureIso);
    _classCode = widget.initialClassCode;
    _quota = widget.initialQuota ?? 'GN';
    _reprice();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    ); // showDatePicker returns the chosen date via a Future in a Material dialog, ideal for travel dates. [9]
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
      await _reprice();
    }
  }

  Future<void> _openClassPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimpleListSheet(
        title: 'Select class',
        items: const ['1A', '2A', '3A', '3E', 'SL', 'CC', '2S'],
        selected: _classCode,
      ),
    ); // showModalBottomSheet presents a shaped modal that returns the selection through Navigator.pop. [1][2]
    if (picked != null) {
      setState(() => _classCode = picked);
      await _reprice();
    }
  }

  Future<void> _openQuotaPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimpleListSheet(
        title: 'Select quota',
        items: const ['GN', 'TQ', 'LD', 'PT', 'SS', 'HO'],
        selected: _quota,
      ),
    ); // Quota selection uses the same modal bottom-sheet pattern for consistency and reuse. [1]
    if (picked != null) {
      setState(() => _quota = picked);
      await _reprice();
    }
  }

  Future<void> _reprice() async {
    if (_classCode == null) return;
    setState(() {
      _pricing = true;
      _fare = null;
    });

    final api = TrainsApi();
    final payload = {
      'trainId': widget.trainId,
      'from': widget.fromCode,
      'to': widget.toCode,
      'date': _dfIso.format(_date),
      'class': _classCode,
      'quota': _quota,
      'passengers': _pax.map((p) => p.toJson()).toList(),
      'prefs': {
        'lowerBerth': _lowerBerthPref,
        'sideOk': _sideBerthOk,
      },
    };

    final res = await api.price(payload: payload);
    res.fold(
      onSuccess: (data) => setState(() {
        _fare = data;
        _pricing = false;
      }),
      onError: (e) {
        setState(() => _pricing = false);
        _snack(e.safeMessage ?? 'Failed to fetch price');
      },
    );
  }

  void _addPax(String type) {
    setState(() => _pax.add(_Pax(type: type)));
    _reprice();
  }

  void _removePax(int index) {
    if (_pax.length <= 1) return;
    setState(() => _pax.removeAt(index));
    _reprice();
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return; // Form validation gated via GlobalKey + validators per Flutter cookbook pattern. [10][13]

    if (_classCode == null) {
      _snack('Select class');
      return;
    }

    setState(() => _submitting = true);

    final api = TrainsApi();
    final payload = {
      'trainId': widget.trainId,
      'from': widget.fromCode,
      'to': widget.toCode,
      'date': _dfIso.format(_date),
      'class': _classCode,
      'quota': _quota,
      'passengers': _pax.map((p) => p.toJson()).toList(),
      'prefs': {
        'lowerBerth': _lowerBerthPref,
        'sideOk': _sideBerthOk,
      },
      'contact': {
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      },
      'payment': {'method': 'pay_later'},
    };

    final res = await api.book(payload: payload);
    res.fold(
      onSuccess: (data) {
        _snack('Booking confirmed');
        Navigator.of(context).maybePop(data);
      },
      onError: (e) => _snack(e.safeMessage ?? 'Booking failed'),
    ); // Outcomes are surfaced via ScaffoldMessenger SnackBars for route-safe feedback. [21]

    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // Use ScaffoldMessenger.showSnackBar for reliable in-app notifications. [21]
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dfLong.format(_date);
    final route = '${widget.fromCode} → ${widget.toCode}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trainName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$route • $dateLabel',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Date
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(dateLabel),
              subtitle: const Text('Journey date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ), // Editing the date uses showDatePicker for a consistent, accessible picker dialog. [9]

            // Class & quota
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.chair_alt_outlined),
                    title: Text(_classCode ?? 'Select class'),
                    subtitle: const Text('Travel class'),
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                    onTap: _openClassPicker,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: Text(_quota ?? 'Select quota'),
                    subtitle: const Text('Quota'),
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                    onTap: _openQuotaPicker,
                  ),
                ),
              ],
            ), // Both pickers are shaped modal bottom sheets that return a string via Navigator.pop. [1]

            const SizedBox(height: 8),

            // Passengers
            Text('Passengers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  ..._pax.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    return _PaxTile(
                      index: i,
                      pax: p,
                      onChanged: (np) {
                        setState(() => _pax[i] = np);
                        _reprice();
                      },
                      onRemove: _pax.length > 1 ? () => _removePax(i) : null,
                    );
                  }),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _addPax('Adult'),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Add adult'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addPax('Child'),
                        icon: const Icon(Icons.child_care_outlined),
                        label: const Text('Add child'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addPax('Senior'),
                        icon: const Icon(Icons.elderly_outlined),
                        label: const Text('Add senior'),
                      ),
                    ],
                  ),
                ],
              ),
            ), // The passenger editor uses a Form with field validators per Flutter’s cookbook. [10][13]

            const SizedBox(height: 8),

            // Preferences
            Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              value: _lowerBerthPref,
              onChanged: (v) => setState(() => _lowerBerthPref = v),
              title: const Text('Lower berth preferred'),
            ),
            SwitchListTile(
              value: _sideBerthOk,
              onChanged: (v) => setState(() => _sideBerthOk = v),
              title: const Text('Side berth acceptable'),
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

            // Contact
            Text('Contact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
            ), // Confirm triggers booking and reports outcome with SnackBars shown via ScaffoldMessenger. [21]
          ],
        ),
      ),
    );
  }
}

class _Pax {
  const _Pax({required this.type, this.name = '', this.age, this.gender});
  final String type; // 'Adult'|'Child'|'Senior'
  final String name;
  final int? age;
  final String? gender;

  _Pax copyWith({String? type, String? name, int? age, String? gender}) {
    return _Pax(
      type: type ?? this.type,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'name': name, 'age': age, 'gender': gender};
}

class _PaxTile extends StatefulWidget {
  const _PaxTile({required this.index, required this.pax, required this.onChanged, this.onRemove});
  final int index;
  final _Pax pax;
  final ValueChanged<_Pax> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_PaxTile> createState() => _PaxTileState();
}

class _PaxTileState extends State<_PaxTile> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pax.name);
    _ageCtrl = TextEditingController(text: widget.pax.age?.toString() ?? '');
    _gender = widget.pax.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final age = int.tryParse(_ageCtrl.text.trim());
    widget.onChanged(widget.pax.copyWith(name: _nameCtrl.text.trim(), age: age, gender: _gender));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Passenger ${widget.index + 1} • ${widget.pax.type}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.numbers)),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return (n == null || n <= 0) ? 'Enter valid age' : null;
                    },
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Male')),
                      DropdownMenuItem(value: 'F', child: Text('Female')),
                      DropdownMenuItem(value: 'O', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      setState(() => _gender = v);
                      _emit();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleListSheet extends StatelessWidget {
  const _SimpleListSheet({required this.title, required this.items, this.selected});
  final String title;
  final List<String> items;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = items[i];
              return RadioListTile<String>(
                value: v,
                groupValue: selected,
                onChanged: (_) => Navigator.of(context).maybePop(v),
                title: Text(v),
              );
            },
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
            _line('Fare', money(base)),
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
