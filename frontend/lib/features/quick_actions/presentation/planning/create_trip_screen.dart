// lib/features/quick_actions/presentation/planning/create_trip_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Shared planning widgets
import 'widgets/location_picker.dart';
import 'widgets/invite_friends.dart';
import 'widgets/navee_ai_planning_button.dart';
import 'widgets/planning_search_button.dart';
import 'widgets/trip_map_view.dart';
import 'widgets/trip_itinerary.dart';

class TripDraft {
  TripDraft({
    this.title = '',
    this.range,
    this.partySize = 2,
    this.origin,
    this.radiusKm,
    this.participants = const <FriendContact>[],
    this.tags = const <String>[],
    this.summary,
    this.stops = const <TripMapStop>[],
    this.days = const <ItineraryDay>[],
  });

  String title;
  DateTimeRange? range;
  int partySize;

  GeoPoint? origin;
  double? radiusKm;

  List<FriendContact> participants;

  List<String> tags;
  String? summary;

  List<TripMapStop> stops;
  List<ItineraryDay> days;
}

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({
    super.key,
    this.initial,
    this.onCreate, // Future<bool> Function(TripDraft draft)
    this.mapBuilder,
    this.onResolveCurrent,
    this.onGeocode,
    this.onSuggest,
  });

  final TripDraft? initial;
  final Future<bool> Function(TripDraft draft)? onCreate;

  // Map + helpers reused by LocationPicker / day map view
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;
  final Future<List<String>> Function(String q)? onSuggest;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _tags = TextEditingController();

  TripDraft _draft = TripDraft();
  int _step = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial ?? TripDraft();
    _title.text = _draft.title;
    _tags.text = _draft.tags.join(', ');
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      initialDateRange: _draft.range,
    );
    if (res != null) setState(() => _draft.range = res);
  }

  bool _validateDetails() {
    final ok = _form.currentState?.validate() ?? false;
    return ok && _draft.range != null;
  }

  Future<void> _submit() async {
    if (!_validateDetails()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete trip details')));
      return;
    }
    if (widget.onCreate == null) {
      Navigator.of(context).maybePop(_draft);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await widget.onCreate!(_draft);
      if (ok && mounted) Navigator.of(context).maybePop(true);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create trip')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create trip'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Create'),
          ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        type: StepperType.vertical,
        onStepCancel: _step == 0 ? null : () => setState(() => _step -= 1),
        onStepContinue: () {
          if (_step == 0 && !_validateDetails()) return;
          if (_step < 2) setState(() => _step += 1);
        },
        steps: [
          Step(
            title: const Text('Details'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: _details(cs),
          ),
          Step(
            title: const Text('Participants'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: _participants(cs),
          ),
          Step(
            title: const Text('Review'),
            isActive: _step >= 2,
            state: _busy ? StepState.editing : StepState.indexed,
            content: _review(cs),
          ),
        ],
      ),
      floatingActionButton: _step == 2
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Create'),
              backgroundColor: cs.primary.withValues(alpha: 1.0),
              foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
            )
          : null,
    );
  }

  Widget _details(ColorScheme cs) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Trip title',
              hintText: 'e.g., Goa long weekend',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            onChanged: (v) => _draft.title = v.trim(),
          ),
          const SizedBox(height: 10),

          // Dates + people
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_draft.range == null ? 'Pick dates' : _fmtRange(_draft.range!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PartyField(
                  value: _draft.partySize,
                  onChanged: (v) => setState(() => _draft.partySize = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Origin + radius
          Row(
            children: [
              Expanded(
                child: LocationPickerButton(
                  label: _draft.origin == null ? 'Origin' : '${_draft.origin!.lat.toStringAsFixed(5)}, ${_draft.origin!.lng.toStringAsFixed(5)}',
                  icon: Icons.place_outlined,
                  initialCenter: _draft.origin,
                  mapBuilder: widget.mapBuilder,
                  onResolveCurrent: widget.onResolveCurrent,
                  onShare: (pick) async {
                    setState(() {
                      _draft.origin = pick.point;
                      _draft.radiusKm = pick.radiusKm ?? _draft.radiusKm;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RadiusField(
                  radiusKm: _draft.radiusKm,
                  onChanged: (v) => setState(() => _draft.radiusKm = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tags
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tags (optional)',
              hintText: 'foodie, trek, beach',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.tag),
            ),
            onChanged: (v) => _draft.tags = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          ),
        ],
      ),
    );
  }

  Widget _participants(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InviteFriendsCard(
          suggested: _draft.participants,
          onOpen: () async {
            await InviteFriendsSheet.show(
              context,
              initialContacts: _draft.participants,
              onSendInvites: (list) async {
                setState(() => _draft.participants = list);
              },
              onCopyLink: () async => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied'))),
              onShareLink: () async => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share sent'))),
            );
          },
        ),
        const SizedBox(height: 10),
        if (_draft.participants.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _draft.participants.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _draft.participants.removeWhere((x) => x.id == c.id)),
                      customBorder: const CircleBorder(),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
      ],
    );
  }

  Widget _review(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI plan + targeted search helpers
        Row(
          children: [
            Expanded(
              child: NaveeAiPlanningButton(
                onGenerate: (req) async {
                  setState(() {
                    _draft.summary = req.prompt.trim().isEmpty ? 'AI generated plan' : req.prompt.trim();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI planning requested')));
                },
                initialMode: 'trip',
                initialPartySize: _draft.partySize,
                initialBudgetPerPerson: 0,
                initialCenter: _draft.origin,
                mapBuilder: widget.mapBuilder,
                onResolveCurrent: widget.onResolveCurrent,
                onGeocode: widget.onGeocode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PlanningSearchButton(
                onApply: (params) async {
                  setState(() {
                    if (params.origin != null) _draft.origin = params.origin;
                    if (params.radiusKm != null) _draft.radiusKm = params.radiusKm;
                    // Tags/categories merged into tags
                    _draft.tags = {
                      ..._draft.tags,
                      ...params.categories,
                      ...params.tags,
                    }.toList();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search filters applied')));
                },
                initialOrigin: _draft.origin,
                initialRadiusKm: _draft.radiusKm,
                mapBuilder: widget.mapBuilder,
                onResolveCurrent: widget.onResolveCurrent,
                onSuggest: widget.onSuggest,
                onGeocode: widget.onGeocode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Optional summary
        if ((_draft.summary ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(_draft.summary!.trim()),
            ),
          ),

        // Preview map of current stops (if any)
        if (_draft.stops.isNotEmpty)
          TripMapView(
            stops: _draft.stops,
            mapBuilder: widget.mapBuilder,
            center: _draft.origin,
            polylinesSupported: false,
            height: 240,
            onOpenStop: (s) {},
            onDirections: (s) async {},
          ),

        // Preview itinerary (if any)
        if (_draft.days.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 300,
              child: TripItinerary(
                days: _draft.days,
                initialOpenAll: false,
                sectionTitle: 'Itinerary preview',
              ),
            ),
          ),
      ],
    );
  }

  String _fmtRange(DateTimeRange r) {
    String d(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '${d(r.start)} → ${d(r.end)}';
  }
}

// Small shared fields

class _PartyField extends StatelessWidget {
  const _PartyField({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Text('People', style: TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(onPressed: value > 1 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}

class _RadiusField extends StatelessWidget {
  const _RadiusField({required this.radiusKm, required this.onChanged});
  final double? radiusKm;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = (radiusKm ?? 0).clamp(0, 50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Radius (km)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: v.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: v.toStringAsFixed(0),
                  onChanged: (x) => onChanged(x == 0 ? null : x),
                ),
              ),
              const SizedBox(width: 8),
              Text(v == 0 ? 'Off' : v.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}
