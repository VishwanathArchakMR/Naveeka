// lib/features/journey/presentation/buses/bus_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'bus_results_screen.dart';

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({
    super.key,
    this.initialFromCode,
    this.initialToCode,
    DateTime? initialDate,
    this.title = 'Search buses',
    this.currency = '₹',
  }) : initialDate = initialDate ?? DateTime.now();

  final String? initialFromCode;
  final String? initialToCode;
  final DateTime initialDate;
  final String title;
  final String currency;

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = widget.initialFromCode ?? '';
    _toCtrl.text = widget.initialToCode ?? '';
    _date = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    ); // showDatePicker is the standard Material date picker API in Flutter [1]
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _swap() {
    final tmp = _fromCtrl.text;
    setState(() {
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = tmp;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // Use ScaffoldMessenger for SnackBars [7]
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false; // Standard Form + GlobalKey validation flow [12]
    if (!ok) return;

    final from = _fromCtrl.text.trim().toUpperCase();
    final to = _toCtrl.text.trim().toUpperCase();
    if (from == to) {
      _snack('From and To cannot be the same');
      return;
    }

    final iso = DateFormat('yyyy-MM-dd').format(_date);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BusResultsScreen(
        fromCode: from,
        toCode: to,
        date: iso,
        title: 'Buses',
        currency: widget.currency,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // From
                  TextFormField(
                    controller: _fromCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'From (city/station code)',
                      prefixIcon: const Icon(Icons.trip_origin),
                      suffixIcon: IconButton(
                        tooltip: 'Swap',
                        icon: const Icon(Icons.swap_vert),
                        onPressed: _swap,
                      ),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter origin';
                      if (s.length < 2) return 'Too short';
                      return null;
                    }, // Field-level validator in TextFormField is the cookbook pattern [12]
                  ),
                  const SizedBox(height: 12),

                  // To
                  TextFormField(
                    controller: _toCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'To (city/station code)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter destination';
                      if (s.length < 2) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date
                  ListTile(
                    onTap: _pickDate,
                    leading: const Icon(Icons.event),
                    title: Text(df.format(_date)),
                    subtitle: const Text('Travel date'),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                  ), // Date selection via ListTile triggers showDatePicker [1]
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search),
                label: const Text('Search buses'),
              ),
            ), // CTA submits the validated form and navigates to results [12][7]
          ],
        ),
      ),
    );
  }
}
