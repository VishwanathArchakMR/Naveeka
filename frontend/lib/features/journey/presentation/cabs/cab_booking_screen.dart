// lib/features/journey/presentation/cabs/cab_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/cabs_api.dart';

class CabBookingScreen extends StatefulWidget {
  const CabBookingScreen({
    super.key,
    required this.title, // e.g., "Cab booking"
    this.defaultPickup, // {lat,lng,address}
    this.defaultDrop, // {lat,lng,address}
    this.defaultProvider, // e.g., 'inhouse'|'ola'|'uber'
  });

  final String title;
  final Map<String, dynamic>? defaultPickup;
  final Map<String, dynamic>? defaultDrop;
  final String? defaultProvider;

  @override
  State<CabBookingScreen> createState() => _CabBookingScreenState();
}

enum _WhenMode { now, later }

class _CabBookingScreenState extends State<CabBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Pickup / Drop fields
  final _pickupAddrCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();

  final _dropAddrCtrl = TextEditingController();
  final _dropLatCtrl = TextEditingController();
  final _dropLngCtrl = TextEditingController();

  // Contact fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // When
  _WhenMode _mode = _WhenMode.now;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 20));

  // Estimates / selection
  bool _loadingEstimates = false;
  List<Map<String, dynamic>> _estimates = const [];
  Map<String, dynamic>? _selectedProduct; // {provider, vehicle, price, eta, productId?}
  Map<String, dynamic>? _quote; // createQuote result

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Hydrate with defaults if provided
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
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return; // Guard context usage after async gaps
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
    );
    if (date == null) return;

    // Guard context usage before showing time picker (this fixes line 109)
    if (!mounted) return;

    // Time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;

    if (!mounted) return; // Guard setState after awaits
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _loadEstimates() async {
    final lat1 = _d(_pickupLatCtrl.text);
    final lng1 = _d(_pickupLngCtrl.text);
    final lat2 = _d(_dropLatCtrl.text);
    final lng2 = _d(_dropLngCtrl.text);

    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      _snack('Please enter valid pickup and drop coordinates');
      return;
    }

    setState(() {
      _loadingEstimates = true;
      _estimates = const [];
      _selectedProduct = null;
      _quote = null;
    });

    final api = CabsApi();
    final whenIso = _mode == _WhenMode.later ? _scheduledAt.toIso8601String() : null;
    final res = await api.priceEstimates(
      pickupLat: lat1,
      pickupLng: lng1,
      dropLat: lat2,
      dropLng: lng2,
      whenIso: whenIso,
      providers: widget.defaultProvider != null ? [widget.defaultProvider!] : null,
    ); // async gap

    if (!mounted) return; // Guard after await
    res.fold(
      onSuccess: (list) {
        // Normalize list items
        final normalized = list.map<Map<String, dynamic>>((m) {
          String? firstStr(List<String> keys) {
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

          return {
            'provider': firstStr(['provider', 'source']) ?? 'provider',
            'vehicle': firstStr(['vehicle', 'product', 'displayName']) ?? 'Ride',
            'productId': firstStr(['productId', 'product_id']),
            'price': dnum(m['price'] ?? m['estimate']),
            'currency': firstStr(['currency']) ?? '₹',
            'eta': firstStr(['etaText']),
          };
        }).toList(growable: false);

        if (!mounted) return; // Guard setState
        setState(() {
          _estimates = normalized;
          _loadingEstimates = false;
          if (_estimates.isNotEmpty) _selectedProduct = _estimates.first;
        });
      },
      onError: (err) {
        if (!mounted) return; // Guard setState/snack
        setState(() => _loadingEstimates = false);
        _snack(err.safeMessage);
      },
    );
  }

  Future<void> _createQuote() async {
    if (_selectedProduct == null) {
      _snack('Please choose a product');
      return;
    }
    final lat1 = _d(_pickupLatCtrl.text);
    final lng1 = _d(_pickupLngCtrl.text);
    final lat2 = _d(_dropLatCtrl.text);
    final lng2 = _d(_dropLngCtrl.text);
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      _snack('Please enter valid pickup and drop coordinates');
      return;
    }

    final api = CabsApi();
    final body = {
      'pickup': {'lat': lat1, 'lng': lng1, 'address': _pickupAddrCtrl.text.trim()},
      'drop': {'lat': lat2, 'lng': lng2, 'address': _dropAddrCtrl.text.trim()},
      if (_selectedProduct!['vehicle'] != null) 'vehicle': _selectedProduct!['vehicle'],
      if (_selectedProduct!['provider'] != null) 'provider': _selectedProduct!['provider'],
      if (_mode == _WhenMode.later) 'when': _scheduledAt.toIso8601String(),
    };
    final res = await api.createQuote(
      pickup: body['pickup'] as Map<String, dynamic>,
      drop: body['drop'] as Map<String, dynamic>,
      vehicle: body['vehicle'] as String?,
      provider: body['provider'] as String?,
      whenIso: body['when'] as String?,
    ); // async gap

    if (!mounted) return; // Guard after await
    res.fold(
      onSuccess: (q) {
        if (!mounted) return; // Guard setState/snack
        setState(() => _quote = q);
        _snack('Quote locked');
      },
      onError: (e) {
        _snack(e.safeMessage); // _snack guards context
      },
    );
  }

  Future<void> _book() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_quote == null) {
      _snack('Create a quote first');
      return;
    }

    if (!mounted) return; // Guard before setState
    setState(() => _submitting = true);

    final api = CabsApi();
    final res = await api.bookRide(
      quoteId: (_quote!['id'] ?? _quote!['quoteId'] ?? '').toString(),
      rider: {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      },
      payment: {'method': 'pay_later'},
      notes: null,
    ); // async gap

    if (!mounted) return; // Guard after await
    res.fold(
      onSuccess: (data) {
        _snack('Ride booked');
        if (!mounted) return; // Guard navigation
        Navigator.of(context).maybePop(data);
      },
      onError: (e) => _snack(e.safeMessage),
    );

    if (!mounted) return; // Guard setState
    setState(() => _submitting = false);
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
                ),
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

            // Estimates
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadingEstimates ? null : _loadEstimates,
                  icon: _loadingEstimates
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.currency_rupee),
                  label: const Text('Get estimates'),
                ),
                const SizedBox(width: 8),
                if (_selectedProduct != null)
                  OutlinedButton.icon(
                    onPressed: _createQuote,
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Create quote'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_estimates.isNotEmpty) _EstimatesList(estimates: _estimates, onSelect: (e) => setState(() => _selectedProduct = e)),

            if (_quote != null) ...[
              const SizedBox(height: 12),
              _QuoteBanner(quote: _quote!),
            ],

            const SizedBox(height: 16),
            Text('Rider details', style: Theme.of(context).textTheme.titleMedium),
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
                label: Text(_submitting ? 'Processing...' : 'Book ride'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatesList extends StatelessWidget {
  const _EstimatesList({required this.estimates, required this.onSelect});
  final List<Map<String, dynamic>> estimates;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, i) {
          final e = estimates[i];
          final currency = (e['currency'] ?? '₹').toString();
          final price = e['price'] as double?;
          final provider = (e['provider'] ?? '').toString();
          final vehicle = (e['vehicle'] ?? '').toString();
          final eta = (e['eta'] ?? '').toString();

          return ListTile(
            leading: CircleAvatar(child: Text(provider.isNotEmpty ? provider.toUpperCase() : '?')),
            title: Text('$vehicle • $provider'),
            subtitle: eta.isEmpty ? null : Text('ETA: $eta'),
            trailing: Text(price != null ? '$currency${price.toStringAsFixed(0)}' : '--', style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => onSelect(e),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: estimates.length,
      ),
    );
  }
}

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.quote});
  final Map<String, dynamic> quote;

  @override
  Widget build(BuildContext context) {
    final total = quote['total'] ?? quote['price'];
    final currency = quote['currency'] ?? '₹';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quote locked',
              style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          Text(
            total != null ? '$currency${total.toString()}' : '',
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
