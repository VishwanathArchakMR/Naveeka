// lib/features/trails/presentation/widgets/trails_top_bar.dart

import 'package:flutter/material.dart';

/// View mode for the trails UI (list or map).
enum TrailsViewMode { list, map }

/// A compact, reusable top bar for the Trails section:
/// - Material 3 SearchAnchor + SearchBar with suggestions
/// - SegmentedButton to toggle List/Map views
/// - Difficulty FilterChips (easy/moderate/hard)
/// - Uses Color.withValues (no withOpacity) and const where possible
class TrailsTopBar extends StatefulWidget {
  const TrailsTopBar({
    super.key,

    // Search
    this.initialQuery = '',
    this.suggestions = const <String>[],
    this.onQueryChanged, // void Function(String)
    this.onSubmitted, // void Function(String)

    // View mode
    this.viewMode = TrailsViewMode.list,
    this.onViewModeChanged, // void Function(TrailsViewMode)

    // Filters
    this.selectedDifficulties = const <String>{}, // 'easy' | 'moderate' | 'hard'
    this.onToggleDifficulty, // void Function(String difficulty, bool nextValue)
    this.onClearFilters, // VoidCallback

    // Optional trailing actions near search bar
    this.trailing,
    this.background,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  // Search
  final String initialQuery;
  final List<String> suggestions;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<String>? onSubmitted;

  // View mode
  final TrailsViewMode viewMode;
  final ValueChanged<TrailsViewMode>? onViewModeChanged;

  // Filters
  final Set<String> selectedDifficulties;
  final void Function(String difficulty, bool nextValue)? onToggleDifficulty;
  final VoidCallback? onClearFilters;

  // Layout/customization
  final List<Widget>? trailing;
  final Color? background;
  final EdgeInsets padding;

  @override
  State<TrailsTopBar> createState() => _TrailsTopBarState();
}

class _TrailsTopBarState extends State<TrailsTopBar> {
  late final SearchController _searchCtrl;
  late Set<TrailsViewMode> _selectedView;
  late Set<String> _selectedDiffs;

  @override
  void initState() {
    super.initState();
    _searchCtrl = SearchController();
    _searchCtrl.value = _searchCtrl.value.copyWith(text: widget.initialQuery);
    _selectedView = {widget.viewMode};
    _selectedDiffs = {...widget.selectedDifficulties};
  }

  @override
  void didUpdateWidget(covariant TrailsTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _selectedView = {widget.viewMode};
    }
    if (oldWidget.selectedDifficulties != widget.selectedDifficulties) {
      _selectedDiffs = {...widget.selectedDifficulties};
    }
    if (oldWidget.initialQuery != widget.initialQuery &&
        widget.initialQuery != _searchCtrl.text) {
      _searchCtrl.value = _searchCtrl.value.copyWith(text: widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: widget.background ?? cs.surface,
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: Search + optional trailing actions
            Row(
              children: [
                Expanded(child: _buildSearch(context)),
                if ((widget.trailing ?? const <Widget>[]).isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.trailing!.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        widget.trailing![i],
                      ],
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Row: View mode segmented + filter chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // View mode
                SegmentedButton<TrailsViewMode>(
                  segments: const [
                    ButtonSegment(value: TrailsViewMode.list, label: Text('List'), icon: Icon(Icons.view_list)),
                    ButtonSegment(value: TrailsViewMode.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                  ],
                  selected: _selectedView,
                  onSelectionChanged: (sel) {
                    setState(() => _selectedView = sel);
                    final mode = sel.first;
                    widget.onViewModeChanged?.call(mode);
                  },
                ),

                // Divider dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                // Filters: Difficulty
                _difficultyChip('easy', 'Easy'),
                _difficultyChip('moderate', 'Moderate'),
                _difficultyChip('hard', 'Hard'),

                if (_selectedDiffs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      for (final d in _selectedDiffs.toList()) {
                        widget.onToggleDifficulty?.call(d, false);
                      }
                      setState(() => _selectedDiffs.clear());
                      widget.onClearFilters?.call();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Material 3 SearchAnchor + SearchBar, with suggestionsBuilder
  Widget _buildSearch(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suggestions = widget.suggestions;

    return SearchAnchor.bar(
      searchController: _searchCtrl,
      barLeading: const Icon(Icons.search),
      barHintText: 'Search trails, parks, regions',
      barBackgroundColor: WidgetStateProperty.all(cs.surfaceContainerHigh.withValues(alpha: 1.0)),
      barElevation: WidgetStateProperty.all(0),
      barShape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide.none),
      ),
      onChanged: (q) => widget.onQueryChanged?.call(q),
      onSubmitted: (q) => widget.onSubmitted?.call(q.trim()),
      suggestionsBuilder: (context, ctrl) {
        final q = ctrl.text.trim().toLowerCase();
        final results = q.isEmpty
            ? suggestions.take(8).toList(growable: false)
            : suggestions.where((s) => s.toLowerCase().contains(q)).take(8).toList(growable: false);

        if (results.isEmpty) {
          return <Widget>[
            ListTile(
              leading: const Icon(Icons.search_off),
              title: const Text('No suggestions'),
              subtitle: Text('Try different keywords', style: TextStyle(color: cs.onSurfaceVariant)),
              onTap: () => ctrl.closeView(''),
            ),
          ];
        }

        return results.map((s) {
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(s),
            onTap: () {
              _searchCtrl.closeView(s);
              widget.onSubmitted?.call(s);
            },
          );
        }).toList(growable: false);
      },
    );
  }

  Widget _difficultyChip(String key, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedDiffs.contains(key);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _selectedDiffs.add(key);
          } else {
            _selectedDiffs.remove(key);
          }
        });
        widget.onToggleDifficulty?.call(key, v);
      },
      backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
      selectedColor: cs.primary.withValues(alpha: 0.24),
      checkmarkColor: cs.primary,
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      labelStyle: TextStyle(color: selected ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w700),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
