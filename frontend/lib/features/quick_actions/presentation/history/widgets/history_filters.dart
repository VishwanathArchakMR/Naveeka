// lib/features/quick_actions/presentation/history/widgets/history_filters.dart

import 'package:flutter/material.dart';

/// Supported history event types.
enum HistoryType { viewed, searched, booked, shared, custom }

extension HistoryTypeLabel on HistoryType {
  String get label {
    switch (this) {
      case HistoryType.viewed:
        return 'Viewed';
      case HistoryType.searched:
        return 'Searched';
      case HistoryType.booked:
        return 'Booked';
      case HistoryType.shared:
        return 'Shared';
      case HistoryType.custom:
        return 'Custom';
    }
  }
}

/// Immutable selection model for the filters.
class HistoryFilterSelection {
  const HistoryFilterSelection({
    this.types = const <HistoryType>{},
    this.range,
    this.query,
  });

  final Set<HistoryType> types;
  final DateTimeRange? range;
  final String? query;

  HistoryFilterSelection copyWith({
    Set<HistoryType>? types,
    DateTimeRange? range,
    bool clearRange = false,
    String? query,
    bool clearQuery = false,
  }) {
    return HistoryFilterSelection(
      types: types ?? this.types,
      range: clearRange ? null : (range ?? this.range),
      query: clearQuery ? null : (query ?? this.query),
    );
  }
}

/// A compact filters row for the History screen:
/// - Type chips (multi-select)
/// - Date range picker chip
/// - Optional text query field
/// - Reset and Apply actions
/// Uses Color.withValues(...) for alpha (no withOpacity) and const where possible.
class HistoryFilters extends StatefulWidget {
  const HistoryFilters({
    super.key,
    required this.value,
    required this.onChanged,
    this.availableTypes = const <HistoryType>[
      HistoryType.viewed,
      HistoryType.searched,
      HistoryType.booked,
      HistoryType.shared,
      HistoryType.custom,
    ],
    this.showQuery = true,
    this.compact = false,
  });

  final HistoryFilterSelection value;
  final ValueChanged<HistoryFilterSelection> onChanged;

  final List<HistoryType> availableTypes;
  final bool showQuery;
  final bool compact;

  @override
  State<HistoryFilters> createState() => _HistoryFiltersState();
}

class _HistoryFiltersState extends State<HistoryFilters> {
  late Set<HistoryType> _types;
  DateTimeRange? _range;
  late final TextEditingController _q;

  @override
  void initState() {
    super.initState();
    _types = {...widget.value.types};
    _range = widget.value.range;
    _q = TextEditingController(text: widget.value.query ?? '');
  }

  @override
  void didUpdateWidget(covariant HistoryFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.types != widget.value.types) {
      _types = {...widget.value.types};
    }
    if (oldWidget.value.range != widget.value.range) {
      _range = widget.value.range;
    }
    if (oldWidget.value.query != widget.value.query) {
      _q.text = widget.value.query ?? '';
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, widget.compact ? 8 : 12, 12, widget.compact ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Types
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.availableTypes.map((t) {
                final selected = _types.contains(t);
                final bg = selected
                    ? cs.primary.withValues(alpha: 0.14)
                    : cs.surfaceContainerHigh.withValues(alpha: 1.0);
                final fg = selected ? cs.primary : cs.onSurface;
                return FilterChip(
                  label: Text(t.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                  selected: selected,
                  onSelected: (on) => setState(() => on ? _types.add(t) : _types.remove(t)),
                  backgroundColor: bg,
                  selectedColor: cs.primary.withValues(alpha: 0.18),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
                );
              }).toList(growable: false),
            ), // FilterChip is the Material control for multi-select filters like history event types. [1][11]

            const SizedBox(height: 10),

            // Row 2: Date + Query
            Row(
              children: [
                // Date range chip
                _DateRangeChip(
                  range: _range,
                  onPick: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: now.subtract(const Duration(days: 365 * 5)),
                      lastDate: now.add(const Duration(days: 365)),
                      initialDateRange: _range,
                    );
                    if (picked != null) setState(() => _range = picked);
                  },
                  onClear: () => setState(() => _range = null),
                ), // showDateRangePicker returns a DateTimeRange for selecting interval filters. [12][15]

                const SizedBox(width: 8),

                // Query field (optional)
                if (widget.showQuery)
                  Expanded(
                    child: TextField(
                      controller: _q,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search notes or place',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onSubmitted: (_) {},
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 3: Reset / Apply
            Row(
              children: [
                TextButton.icon(
                  onPressed: _onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _onApply,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onReset() {
    setState(() {
      _types.clear();
      _range = null;
      _q.clear();
    });
    widget.onChanged(const HistoryFilterSelection());
  }

  void _onApply() {
    widget.onChanged(
      HistoryFilterSelection(
        types: _types,
        range: _range,
        query: _q.text.trim().isEmpty ? null : _q.text.trim(),
      ),
    );
  }
}

/// A small chip-like control that shows the current range and opens a date range picker.
class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({required this.range, required this.onPick, required this.onClear});

  final DateTimeRange? range;
  final Future<void> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _format(range);

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (range != null) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Clear',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(DateTimeRange? r) {
    if (r == null) return 'Any dates';
    final s = _d(r.start);
    final e = _d(r.end);
    return '$s → $e';
  }

  String _d(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }
}
