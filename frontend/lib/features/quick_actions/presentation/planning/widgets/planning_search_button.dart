// lib/features/quick_actions/presentation/planning/widgets/planning_search_button.dart

import 'package:flutter/material.dart';

import './location_picker.dart'; // GeoPoint, LocationPickerButton, LocationSuggestion, NearbyMapBuilder

/// Structured planning search parameters returned by the sheet.
class PlanningSearchParams {
  const PlanningSearchParams({
    required this.query,
    required this.categories,
    this.origin,
    this.radiusKm,
    this.openNow = false,
    this.minRating,
    this.dateRange,
    this.partySize,
    this.tags = const <String>[],
  });

  final String query;
  final Set<String> categories;

  final GeoPoint? origin;
  final double? radiusKm;

  final bool openNow;
  final double? minRating;

  final DateTimeRange? dateRange;
  final int? partySize;

  final List<String> tags;
}

/// A compact primary action that opens the Planning Search bottom sheet.
class PlanningSearchButton extends StatelessWidget {
  const PlanningSearchButton({
    super.key,
    required this.onApply, // Future<void> Function(PlanningSearchParams params)
    this.label = 'Planning search',
    this.icon = Icons.search,
    this.initialQuery = '',
    this.initialCategories = const {'food', 'coffee', 'outdoors'},
    this.initialOrigin,
    this.initialRadiusKm,
    this.initialOpenNow = false,
    this.initialMinRating,
    this.initialDateRange,
    this.initialPartySize,
    this.initialTags = const <String>[],
    this.mapBuilder,
    this.onResolveCurrent,
    this.onSuggest, // Future<List<String>> Function(String q)
    this.onGeocode, // Future<List<LocationSuggestion>> Function(String q)
  });

  final Future<void> Function(PlanningSearchParams params) onApply;

  final String label;
  final IconData icon;

  // Initials
  final String initialQuery;
  final Set<String> initialCategories;
  final GeoPoint? initialOrigin;
  final double? initialRadiusKm;
  final bool initialOpenNow;
  final double? initialMinRating;
  final DateTimeRange? initialDateRange;
  final int? initialPartySize;
  final List<String> initialTags;

  // Map + helpers
  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;

  // Suggestion providers
  final Future<List<String>> Function(String q)? onSuggest;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: () async {
        final res = await _PlanningSearchSheet.show(
          context,
          initialQuery: initialQuery,
          initialCategories: initialCategories,
          initialOrigin: initialOrigin,
          initialRadiusKm: initialRadiusKm,
          initialOpenNow: initialOpenNow,
          initialMinRating: initialMinRating,
          initialDateRange: initialDateRange,
          initialPartySize: initialPartySize,
          initialTags: initialTags,
          mapBuilder: mapBuilder,
          onResolveCurrent: onResolveCurrent,
          onSuggest: onSuggest,
          onGeocode: onGeocode,
        );
        if (res != null) {
          await onApply(res);
        }
      },
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _PlanningSearchSheet extends StatefulWidget {
  const _PlanningSearchSheet({
    required this.initialQuery,
    required this.initialCategories,
    required this.initialOrigin,
    required this.initialRadiusKm,
    required this.initialOpenNow,
    required this.initialMinRating,
    required this.initialDateRange,
    required this.initialPartySize,
    required this.initialTags,
    required this.mapBuilder,
    required this.onResolveCurrent,
    required this.onSuggest,
    required this.onGeocode,
  });

  final String initialQuery;
  final Set<String> initialCategories;
  final GeoPoint? initialOrigin;
  final double? initialRadiusKm;
  final bool initialOpenNow;
  final double? initialMinRating;
  final DateTimeRange? initialDateRange;
  final int? initialPartySize;
  final List<String> initialTags;

  final NearbyMapBuilder? mapBuilder;
  final Future<GeoPoint?> Function()? onResolveCurrent;

  final Future<List<String>> Function(String q)? onSuggest;
  final Future<List<LocationSuggestion>> Function(String q)? onGeocode;

  static Future<PlanningSearchParams?> show(
    BuildContext context, {
    required String initialQuery,
    required Set<String> initialCategories,
    required GeoPoint? initialOrigin,
    required double? initialRadiusKm,
    required bool initialOpenNow,
    required double? initialMinRating,
    required DateTimeRange? initialDateRange,
    required int? initialPartySize,
    required List<String> initialTags,
    required NearbyMapBuilder? mapBuilder,
    required Future<GeoPoint?> Function()? onResolveCurrent,
    required Future<List<String>> Function(String q)? onSuggest,
    required Future<List<LocationSuggestion>> Function(String q)? onGeocode,
  }) {
    return showModalBottomSheet<PlanningSearchParams>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _PlanningSearchSheet(
          initialQuery: initialQuery,
          initialCategories: initialCategories,
          initialOrigin: initialOrigin,
          initialRadiusKm: initialRadiusKm,
          initialOpenNow: initialOpenNow,
          initialMinRating: initialMinRating,
          initialDateRange: initialDateRange,
          initialPartySize: initialPartySize,
          initialTags: initialTags,
          mapBuilder: mapBuilder,
          onResolveCurrent: onResolveCurrent,
          onSuggest: onSuggest,
          onGeocode: onGeocode,
        ),
      ),
    );
  }

  @override
  State<_PlanningSearchSheet> createState() => _PlanningSearchSheetState();
}

class _PlanningSearchSheetState extends State<_PlanningSearchSheet> {
  final _tags = TextEditingController();
  final _searchController = SearchController();

  late String _query;
  late Set<String> _cats;
  GeoPoint? _origin;
  double? _radiusKm;
  bool _openNow = false;
  double? _minRating;
  DateTimeRange? _dates;
  int? _party;

  bool _busySuggest = false;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _cats = {...widget.initialCategories};
    _origin = widget.initialOrigin;
    _radiusKm = widget.initialRadiusKm;
    _openNow = widget.initialOpenNow;
    _minRating = widget.initialMinRating;
    _dates = widget.initialDateRange;
    _party = widget.initialPartySize;
    _tags.text = widget.initialTags.join(', ');
  }

  @override
  void dispose() {
    _tags.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions(String q) async {
    if (widget.onSuggest == null || q.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() => _busySuggest = true);
    try {
      final res = await widget.onSuggest!.call(q.trim());
      if (mounted) setState(() => _suggestions = res);
    } finally {
      if (mounted) setState(() => _busySuggest = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final categories = const <(String, IconData)>[
      ('food', Icons.restaurant_menu),
      ('coffee', Icons.coffee_outlined),
      ('outdoors', Icons.park_outlined),
      ('culture', Icons.museum_outlined),
      ('nightlife', Icons.nightlife_outlined),
      ('shopping', Icons.shopping_bag_outlined),
    ];

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Planning search', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
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
                    // SearchBar + suggestions (SearchAnchor)
                    SearchAnchor.bar(
                      searchController: _searchController,
                      barHintText: 'Search places, areas, or keywords',
                      isFullScreen: false,
                      onTap: () {
                        _searchController.openView();
                        _loadSuggestions(_searchController.text);
                      },
                      onChanged: (q) => _loadSuggestions(q),
                      suggestionsBuilder: (context, controller) {
                        final items = _suggestions;
                        if (_busySuggest && items.isEmpty) {
                          return [
                            const ListTile(
                              dense: true,
                              title: Text('Searching…'),
                            )
                          ];
                        }
                        if (items.isEmpty && controller.text.isNotEmpty) {
                          return [
                            ListTile(
                              dense: true,
                              title: Text('Search “${controller.text}”'),
                              onTap: () {
                                setState(() => _query = controller.text.trim());
                                controller.closeView(controller.text);
                              },
                            )
                          ];
                        }
                        return items
                            .map((s) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.search),
                                  title: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () {
                                    setState(() {
                                      _query = s;
                                    });
                                    controller.closeView(s);
                                  },
                                ))
                            .toList(growable: false);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Categories (multi-select)
                    Text('Categories', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final isOn = _cats.contains(c.$1);
                        final bg = isOn ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh.withValues(alpha: 1.0);
                        final fg = isOn ? cs.primary : cs.onSurface;
                        return FilterChip(
                          avatar: Icon(c.$2, size: 16, color: fg),
                          label: Text(c.$1.toUpperCase() + c.$1.substring(1), style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                          selected: isOn,
                          onSelected: (on) => setState(() => on ? _cats.add(c.$1) : _cats.remove(c.$1)),
                          backgroundColor: bg,
                          selectedColor: cs.primary.withValues(alpha: 0.18),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          side: BorderSide(color: isOn ? cs.primary : cs.outlineVariant),
                        );
                      }).toList(growable: false),
                    ),

                    const SizedBox(height: 12),

                    // Origin + radius
                    Row(
                      children: [
                        Expanded(
                          child: LocationPickerButton(
                            label: _origin == null ? 'Origin' : '${_origin!.lat.toStringAsFixed(5)}, ${_origin!.lng.toStringAsFixed(5)}',
                            icon: Icons.place_outlined,
                            initialCenter: _origin,
                            mapBuilder: widget.mapBuilder,
                            onResolveCurrent: widget.onResolveCurrent,
                            onShare: (pick) async {
                              setState(() {
                                _origin = pick.point;
                                _radiusKm = pick.radiusKm ?? _radiusKm;
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

                    // Open now + rating
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Open now'),
                            value: _openNow,
                            onChanged: (v) => setState(() => _openNow = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RatingField(
                            minRating: _minRating,
                            onChanged: (v) => setState(() => _minRating = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Dates + party size
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDates,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_dates == null ? 'Dates (optional)' : _fmtRange(_dates!)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PartyField(
                            value: _party ?? 2,
                            onChanged: (v) => setState(() => _party = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Tags
                    TextField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        hintText: 'Tags (comma separated)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        isDense: true,
                      ),
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
                      final tags = _tags.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(growable: false);
                      final params = PlanningSearchParams(
                        query: _query.isEmpty ? _searchController.text.trim() : _query,
                        categories: _cats,
                        origin: _origin,
                        radiusKm: _radiusKm,
                        openNow: _openNow,
                        minRating: _minRating,
                        dateRange: _dates,
                        partySize: _party,
                        tags: tags,
                      );
                      Navigator.of(context).maybePop(params);
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
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
    if (_query.isNotEmpty) parts.add(_query);
    parts.add('${_cats.length} cats');
    if (_radiusKm != null) parts.add('${_radiusKm!.toStringAsFixed(_radiusKm! >= 10 ? 0 : 1)} km');
    if (_openNow) parts.add('open');
    if (_minRating != null) parts.add('≥ ${_minRating!.toStringAsFixed(1)}★');
    if (_dates != null) parts.add('dates');
    if ((_tags.text.trim()).isNotEmpty) parts.add('tags');
    return parts.isEmpty ? 'Set filters' : parts.join(' · ');
  }
}

// ---------------- Small fields ----------------

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

class _RatingField extends StatelessWidget {
  const _RatingField({required this.minRating, required this.onChanged});
  final double? minRating;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = (minRating ?? 0).clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Min rating', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
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
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Slider(
                  value: v.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 10,
                  label: v.toStringAsFixed(1),
                  onChanged: (x) => onChanged(x == 0 ? null : x),
                ),
              ),
              const SizedBox(width: 8),
              Text(v == 0 ? 'Any' : v.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

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
