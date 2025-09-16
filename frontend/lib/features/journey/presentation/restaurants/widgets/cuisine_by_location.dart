// lib/features/journey/presentation/restaurants/widgets/cuisine_by_location.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Displays popular cuisines near a location as ChoiceChips with an optional
/// "All cuisines" bottom sheet that supports search and single/multi-select.
///
/// Typical cuisine item shape:
/// { key: 'indian', name: 'Indian', count: 142 }
class CuisineByLocation extends StatefulWidget {
  const CuisineByLocation({
    super.key,
    this.lat,
    this.lng,
    this.city, // Use either (lat,lng) or city. If both present, (lat,lng) wins.
    this.fetchCuisines, // Future<List<Map<String,dynamic>>> Function({double? lat,double? lng,String? city})
    this.items,
    this.initialSelected = const <String>{},
    this.multiSelect = false,
    this.title = 'Popular cuisines',
    this.maxInline = 8,
  }) : assert(
          items != null || fetchCuisines != null,
          'Provide either items or fetchCuisines',
        );

  final double? lat;
  final double? lng;
  final String? city;

  /// When provided, the widget will call this to load cuisines for given (lat,lng) or city.
  final Future<List<Map<String, dynamic>>> Function({
    double? lat,
    double? lng,
    String? city,
  })? fetchCuisines;

  /// Alternatively, pass already-available cuisines.
  final List<Map<String, dynamic>>? items;

  /// Preselected cuisine keys.
  final Set<String> initialSelected;

  /// If true, allow multiple selections; otherwise ChoiceChip behaves single-select.
  final bool multiSelect;

  final String title;
  final int maxInline;

  @override
  State<CuisineByLocation> createState() => _CuisineByLocationState();
}

class _CuisineByLocationState extends State<CuisineByLocation> {
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = false;

  // Selected cuisine keys
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.items != null) {
      setState(() => _items = widget.items!);
      return;
    }
    if (widget.fetchCuisines == null) return;

    setState(() {
      _loading = true;
      _items = const <Map<String, dynamic>>[];
    });

    try {
      final list = await widget.fetchCuisines!(
        lat: widget.lat,
        lng: widget.lng,
        city: widget.city,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to load cuisines');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } // SnackBars are presented through ScaffoldMessenger for reliable, route-safe feedback [7]

  void _toggle(String key) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(key)) {
          _selected.remove(key);
        } else {
          _selected.add(key);
        }
      } else {
        _selected = {key};
      }
    });
  }

  Future<void> _showAll() async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AllCuisinesSheet(
        title: widget.title,
        all: _items,
        initial: _selected,
        multiSelect: widget.multiSelect,
      ),
    );
    if (picked != null) {
      setState(() => _selected = picked);
    }
  } // Bottom sheets are shown via showModalBottomSheet and return a result through Navigator.pop for clean handoff [9][12]

  @override
  Widget build(BuildContext context) {
    final chips = _items.take(widget.maxInline).toList(growable: false);
    final moreCount = _items.length - chips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_items.isNotEmpty)
              TextButton.icon(
                onPressed: _showAll,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(moreCount > 0 ? 'All (${_items.length})' : 'All'),
              ),
          ],
        ),

        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),

        if (!_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No cuisines available', style: TextStyle(color: Colors.black54)),
          ),

        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  ...chips.map((m) {
                    final key = (m['key'] ?? '').toString();
                    final name = (m['name'] ?? key).toString();
                    final sel = _selected.contains(key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: sel,
                        onSelected: (_) => _toggle(key),
                      ),
                    );
                  }),
                  if (moreCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: OutlinedButton.icon(
                        onPressed: _showAll,
                        icon: const Icon(Icons.more_horiz),
                        label: Text('More +$moreCount'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AllCuisinesSheet extends StatefulWidget {
  const _AllCuisinesSheet({
    required this.title,
    required this.all,
    required this.initial,
    required this.multiSelect,
  });

  final String title;
  final List<Map<String, dynamic>> all;
  final Set<String> initial;
  final bool multiSelect;

  @override
  State<_AllCuisinesSheet> createState() => _AllCuisinesSheetState();
}

class _AllCuisinesSheetState extends State<_AllCuisinesSheet> {
  late Set<String> _picked;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _picked = {...widget.initial};
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.all
        : widget.all.where((m) {
            final name = (m['name'] ?? '').toString().toLowerCase();
            final key = (m['key'] ?? '').toString().toLowerCase();
            return name.contains(q) || key.contains(q);
          }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(_picked),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          // Search
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search cuisines',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 8),

          // Grid of chips
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filtered.map((m) {
                  final key = (m['key'] ?? '').toString();
                  final name = (m['name'] ?? key).toString();
                  final count = m['count'] as int?;
                  final sel = _picked.contains(key);
                  return ChoiceChip(
                    label: Text(count == null ? name : '$name • $count'),
                    selected: sel,
                    onSelected: (_) {
                      setState(() {
                        if (widget.multiSelect) {
                          if (sel) {
                            _picked.remove(key);
                          } else {
                            _picked.add(key);
                          }
                        } else {
                          _picked = {key};
                        }
                      });
                    },
                  );
                }).toList(growable: false),
              ),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(_picked),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(widget.multiSelect ? 'Apply (${_picked.length})' : 'Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
