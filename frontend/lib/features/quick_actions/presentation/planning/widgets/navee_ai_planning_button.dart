// lib/features/quick_actions/presentation/planning/widgets/navee_ai_planning_button.dart

import 'package:flutter/material.dart';

import './location_picker.dart'; // GeoPoint + LocationPickerButton

/// Structured AI-planning request returned by the sheet.
class NaveeAiPlanRequest {
  const NaveeAiPlanRequest({
    required this.mode, // trip | dining | weekend
    required this.prompt,
    required this.partySize,
    this.budgetPerPerson, // in local currency
    this.dates,
    this.origin,
    this.radiusKm,
    this.preferences = const <String>[],
    this.needAccessibility = false,
    this.preferPublicTransit = false,
  });

  final String mode;
  final String prompt;
  final int partySize;

  final double? budgetPerPerson;
  final DateTimeRange? dates;

  final GeoPoint? origin;
  final double? radiusKm;

  final List<String> preferences;

  final bool needAccessibility;
  final bool preferPublicTransit;
}

/// A compact primary action that opens the AI planning sheet and
/// returns a NaveeAiPlanRequest to the caller.
class NaveeAiPlanningButton extends StatefulWidget {
  const NaveeAiPlanningButton({
    super.key,
    required this.onGenerate, // Future<void> Function(NaveeAiPlanRequest req)
    this.label = 'Plan with Navee AI',
    this.icon = Icons.auto_awesome,
    this.initialMode = 'trip',
    this.initialPartySize = 2,
    this.initialBudgetPerPerson,
    this.initialCenter,
    this.mapBuilder,
    this.onResolveCurrent,
    this.onGeocode, // Future<List<LocationSuggestion>> Function(String query)
  });

  final Future<void> Function(NaveeAiPlanRequest req) onGenerate;

  final String label;
  final IconData icon;

  final String initialMode;
  final int initialPartySize;
  final double? initialBudgetPerPerson;

  final GeoPoint? initialCenter;
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;

  @override
  State<NaveeAiPlanningButton> createState() => _NaveeAiPlanningButtonState();
}

class _NaveeAiPlanningButtonState extends State<NaveeAiPlanningButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: _busy
          ? null
          : () async {
              final req = await _NaveeAiPlanningSheet.show(
                context,
                initialMode: widget.initialMode,
                initialPartySize: widget.initialPartySize,
                initialBudgetPerPerson: widget.initialBudgetPerPerson,
                initialCenter: widget.initialCenter,
                mapBuilder: widget.mapBuilder,
                onResolveCurrent: widget.onResolveCurrent,
                onGeocode: widget.onGeocode,
              );
              if (req == null) return;
              setState(() => _busy = true);
              try {
                await widget.onGenerate(req);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(widget.icon),
      label: Text(widget.label),
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _NaveeAiPlanningSheet extends StatefulWidget {
  const _NaveeAiPlanningSheet({
    required this.initialMode,
    required this.initialPartySize,
    required this.initialBudgetPerPerson,
    required this.initialCenter,
    required this.mapBuilder,
    required this.onResolveCurrent,
    required this.onGeocode,
  });

  final String initialMode;
  final int initialPartySize;
  final double? initialBudgetPerPerson;

  final GeoPoint? initialCenter;
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;

  static Future<NaveeAiPlanRequest?> show(
    BuildContext context, {
    required String initialMode,
    required int initialPartySize,
    required double? initialBudgetPerPerson,
    required GeoPoint? initialCenter,
    required NearbyMapBuilder? mapBuilder,
    required Future<GeoPoint?> Function()? onResolveCurrent,
    required Future<List<LocationSuggestion>> Function(String q)? onGeocode,
  }) {
    return showModalBottomSheet<NaveeAiPlanRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _NaveeAiPlanningSheet(
          initialMode: initialMode,
          initialPartySize: initialPartySize,
          initialBudgetPerPerson: initialBudgetPerPerson,
          initialCenter: initialCenter,
          mapBuilder: mapBuilder,
          onResolveCurrent: onResolveCurrent,
          onGeocode: onGeocode,
        ),
      ),
    );
  }

  @override
  State<_NaveeAiPlanningSheet> createState() => _NaveeAiPlanningSheetState();
}

class _NaveeAiPlanningSheetState extends State<_NaveeAiPlanningSheet> {
  final _prompt = TextEditingController();
  final _pref = TextEditingController();

  String _mode = 'trip';
  int _party = 2;
  double _budget = 0;

  DateTimeRange? _dates;

  GeoPoint? _origin;
  double? _radiusKm;

  bool _access = false;
  bool _transit = false;

  bool _busyGeo = false;
  bool _busySearch = false;
  List<LocationSuggestion> _results = const [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _party = widget.initialPartySize;
    _budget = widget.initialBudgetPerPerson ?? 0;
    _origin = widget.initialCenter;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _pref.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final next = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dates,
    );
    if (next != null) setState(() => _dates = next);
  }

  Future<void> _searchPlaces(String q) async {
    if (widget.onGeocode == null || q.trim().isEmpty) return;
    setState(() {
      _busySearch = true;
      _results = const [];
    });
    try {
      final items = await widget.onGeocode!.call(q.trim());
      if (mounted) setState(() => _results = items);
    } finally {
      if (mounted) setState(() => _busySearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Navee AI planner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode selector
                    Text('Mode', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'trip', label: Text('Trip'), icon: Icon(Icons.flight_takeoff)),
                        ButtonSegment(value: 'dining', label: Text('Dining'), icon: Icon(Icons.restaurant_menu)),
                        ButtonSegment(value: 'weekend', label: Text('Weekend'), icon: Icon(Icons.calendar_month)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),

                    const SizedBox(height: 12),

                    // Prompt
                    Text('What should the plan include?', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _prompt,
                      maxLines: 3,
                      minLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g., 2-day foodie itinerary with scenic viewpoints and a cozy brunch spot',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Party + budget
                    Row(
                      children: [
                        Expanded(
                          child: _NumberStepper(
                            label: 'People',
                            value: _party,
                            onMinus: _party > 1 ? () => setState(() => _party--) : null,
                            onPlus: () => setState(() => _party++),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BudgetField(
                            value: _budget,
                            onChanged: (v) => setState(() => _budget = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Dates and preferences
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDates,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_dates == null ? 'Pick dates' : _fmtRange(_dates!)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _pref,
                            decoration: const InputDecoration(
                              hintText: 'Tags (comma separated)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Origin + radius (optional)
                    Row(
                      children: [
                        Expanded(
                          child: LocationPickerButton(
                            label: _origin == null ? 'Origin' : '${_origin!.lat.toStringAsFixed(5)}, ${_origin!.lng.toStringAsFixed(5)}',
                            icon: Icons.place_outlined,
                            initialCenter: _origin,
                            mapBuilder: widget.mapBuilder,
                            onResolveCurrent: widget.onResolveCurrent,
                            onShare: (res) async {
                              setState(() {
                                _origin = res.point;
                                _radiusKm = res.radiusKm ?? _radiusKm;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RadiusField(
                            radiusKm: _radiusKm,
                            onChanged: (v) => setState(() => _radiusKm = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Quick geocode search (optional)
                    Text('Search place (optional)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      onSubmitted: (q) => _searchPlaces(q),
                      decoration: InputDecoration(
                        hintText: 'Find a landmark or area to anchor the plan',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _busySearch
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: cs.surface.withValues(alpha: 1.0),
                      ),
                    ),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._results.take(4).map((r) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.place_outlined, color: cs.primary),
                            ),
                            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: (r.subtitle ?? '').trim().isEmpty ? null : Text(r.subtitle!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => setState(() {
                              _origin = r.point;
                              _radiusKm ??= 2.0;
                            }),
                          )),
                    ],

                    const SizedBox(height: 12),

                    // Preferences toggles
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Accessibility'),
                          selected: _access,
                          onSelected: (s) => setState(() => _access = s),
                          backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                          selectedColor: cs.primary.withValues(alpha: 0.18),
                          side: BorderSide(color: _access ? cs.primary : cs.outlineVariant),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Public transit'),
                          selected: _transit,
                          onSelected: (s) => setState(() => _transit = s),
                          backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                          selectedColor: cs.primary.withValues(alpha: 0.18),
                          side: BorderSide(color: _transit ? cs.primary : cs.outlineVariant),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Confirm bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final prefs = _pref.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(growable: false);

                      final req = NaveeAiPlanRequest(
                        mode: _mode,
                        prompt: _prompt.text.trim(),
                        partySize: _party,
                        budgetPerPerson: _budget > 0 ? _budget : null,
                        dates: _dates,
                        origin: _origin,
                        radiusKm: _radiusKm,
                        preferences: prefs,
                        needAccessibility: _access,
                        preferPublicTransit: _transit,
                      );
                      Navigator.of(context).maybePop(req);
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Generate'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtRange(DateTimeRange r) {
    String d(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '${d(r.start)} → ${d(r.end)}';
  }

  String _summary() {
    final parts = <String>[];
    parts.add(_mode);
    parts.add('${_party}p');
    if (_budget > 0) parts.add('~$_budget pp');
    if (_dates != null) parts.add(_fmtRange(_dates!));
    return parts.join(' · ');
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}

class _BudgetField extends StatelessWidget {
  const _BudgetField({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.clamp(0, 1000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Budget pp', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
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
                  max: 1000,
                  divisions: 1000,
                  label: v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(0),
                  onChanged: (x) => onChanged(x),
                ),
              ),
              const SizedBox(width: 8),
              Text(v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
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
              Text(v == 0 ? 'Off' : '${v.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}
