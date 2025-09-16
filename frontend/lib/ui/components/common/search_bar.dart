// lib/ui/components/common/search_bar.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/route_names.dart';

enum SearchScope {
  all('All'),
  places('Places'),
  stays('Stays'),
  dining('Dining'),
  activities('Activities');

  const SearchScope(this.label);
  final String label;
}

class UniversalSearchBar extends ConsumerStatefulWidget {
  const UniversalSearchBar({
    super.key,
    this.placeholder = 'Search for places, emotions, experiences…',
    this.showScopeChips = false,
    this.onSearch,
    this.onScopeChanged,
    this.initialScope = SearchScope.all,
    this.compact = false,
    this.isFullScreen = false,
    this.debounce = const Duration(milliseconds: 250),
    this.onVoice, // optional voice action
  });

  final String placeholder;
  final bool showScopeChips;
  final void Function(String query, SearchScope scope)? onSearch;
  final void Function(SearchScope scope)? onScopeChanged;
  final SearchScope initialScope;

  /// Denser paddings for tight UIs.
  final bool compact;

  /// If true, opens full-screen search view; else dropdown overlay.
  final bool isFullScreen;

  /// Debounce interval for onSearch.
  final Duration debounce;

  /// Optional voice button tap (integrate with voice service if needed).
  final VoidCallback? onVoice;

  @override
  ConsumerState<UniversalSearchBar> createState() => _UniversalSearchBarState();
}

class _UniversalSearchBarState extends ConsumerState<UniversalSearchBar> {
  // Material 3 search controller powering SearchAnchor + SearchBar.
  // This manages the query text and overlay state. [1][3]
  late final SearchController _searchCtrl = SearchController();

  // Scope chips selection.
  SearchScope _currentScope = SearchScope.all;

  // Debounce for query -> onSearch.
  Timer? _debounceTimer;

  // Zero-query suggestions
  static const List<String> _zeroQuerySuggestions = <String>[
    'Peaceful temples nearby',
    'Adventure activities',
    'Heritage walks',
    'Weekend getaways',
    'Spiritual places',
    'Nature spots',
    'Budget hotels',
    'Local restaurants',
  ];

  // Predictive suggestions (mock; replace with backend results).
  static const List<String> _predictiveSuggestions = <String>[
    'Hampi ruins',
    'Coorg coffee estates',
    'Goa beaches',
    'Rishikesh yoga retreats',
    'Jaipur palaces',
    'Kerala backwaters',
    'Manali adventures',
    'Varanasi ghats',
  ];

  @override
  void initState() {
    super.initState();
    _currentScope = widget.initialScope;
    _searchCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.removeListener(_onTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Debounce query and emit onSearch so upstream can fetch suggestions/results. [3]
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onSearch?.call(_searchCtrl.text, _currentScope);
    });
  }

  void _onScopeChanged(SearchScope scope) {
    setState(() => _currentScope = scope);
    widget.onScopeChanged?.call(scope);
    if (_searchCtrl.text.trim().isNotEmpty) {
      widget.onSearch?.call(_searchCtrl.text, scope);
    }
  }

  void _onSuggestionTapped(String suggestion) {
    _searchCtrl.text = suggestion;
    _searchCtrl.closeView(suggestion);
    widget.onSearch?.call(suggestion, _currentScope);
  }

  void _onSubmitted(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _searchCtrl.closeView(q);
    widget.onSearch?.call(q, _currentScope);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Modern neutral container and wide‑gamut safe alpha (no withOpacity). [2][3]
    final Color bg = cs.surfaceContainerHighest.withValues(alpha: 1.0);

    final barPadding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    final radius = BorderRadius.circular(widget.compact ? 20 : 24);

    final barShape = WidgetStatePropertyAll<RoundedRectangleBorder>(
      RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: cs.outlineVariant)),
    );
    final barBg = WidgetStatePropertyAll<Color>(bg);

    final search = SearchAnchor.bar(
      // Material 3 search host that manages the overlay & bar. [1]
      isFullScreen: widget.isFullScreen,
      searchController: _searchCtrl,
      barElevation: const WidgetStatePropertyAll<double>(0),
      barBackgroundColor: barBg,
      barShape: barShape,
      barPadding: WidgetStatePropertyAll<EdgeInsetsGeometry>(barPadding),
      barLeading: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: widget.compact ? 4 : 6),
          child: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: widget.compact ? 20 : 22),
        ),
      ],
      barHintText: widget.placeholder,
      barTextStyle: WidgetStatePropertyAll<TextStyle>(
        (widget.compact ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodyLarge)!.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      barTrailing: <Widget>[
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: widget.compact ? 18 : 20),
            onPressed: () {
              _searchCtrl.clear();
              // Keep view open to continue typing. [1]
              _searchCtrl.openView();
            },
          ),
        if (widget.onVoice != null)
          IconButton(
            tooltip: 'Voice',
            icon: Icon(Icons.mic_rounded, color: cs.onSurfaceVariant, size: widget.compact ? 18 : 20),
            onPressed: widget.onVoice,
          ),
      ],
      // In dropdown mode, cap overlay height for usability. [1][4]
      viewConstraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      // Suggestions overlay content; SearchAnchor handles selection & closing. [1]
      suggestionsBuilder: (context, controller) => _buildSuggestions(context, controller),
      onSubmitted: _onSubmitted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        search,
        if (widget.showScopeChips) ...<Widget>[
          const SizedBox(height: 12),
          _buildScopeChips(context),
        ],
      ],
    );
  }

  Iterable<Widget> _buildSuggestions(BuildContext context, SearchController controller) {
    final cs = Theme.of(context).colorScheme;
    final query = controller.text.trim();
    final List<String> suggestions = query.isEmpty
        ? _zeroQuerySuggestions
        : _predictiveSuggestions.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();

    if (suggestions.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'No suggestions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ];
    }

    final header = query.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Popular searches',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          )
        : const SizedBox.shrink();

    final tiles = suggestions.take(8).map((s) {
      final isZero = query.isEmpty;
      return ListTile(
        dense: true,
        leading: Icon(isZero ? Icons.trending_up_rounded : Icons.search_rounded, color: cs.onSurfaceVariant, size: 18),
        title: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.north_west_rounded, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        onTap: () => _onSuggestionTapped(s),
      );
    });

    return <Widget>[
      if (header is! SizedBox) header,
      ...tiles,
    ];
  }

  Widget _buildScopeChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: SearchScope.values.map((scope) {
          final bool isSelected = scope == _currentScope;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilterChip(
              label: Text(scope.label),
              selected: isSelected,
              onSelected: (_) => _onScopeChanged(scope),
              backgroundColor: cs.surfaceContainerHighest, // modern neutral surface [3]
              selectedColor: cs.primary.withValues(alpha: 0.20),
              side: BorderSide(
                color: isSelected ? cs.primary : cs.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12, vertical: widget.compact ? 6 : 8),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Specialized search bars for different screens

class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UniversalSearchBar(
      placeholder: 'Search for places, emotions, experiences…',
      showScopeChips: false,
      onSearch: (query, scope) {
        if (query.trim().isEmpty) return;
        context.pushNamed(
          RouteNames.atlas,
          queryParameters: <String, String>{'q': query},
        );
      },
    );
  }
}

class AtlasSearchBar extends ConsumerWidget {
  const AtlasSearchBar({super.key, this.onSearch});

  final void Function(String query, SearchScope scope)? onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UniversalSearchBar(
      placeholder: 'Search all places…',
      showScopeChips: true,
      onSearch: onSearch,
    );
  }
}

class JourneySearchBar extends ConsumerWidget {
  const JourneySearchBar({super.key, this.onSearch});

  final void Function(String query, SearchScope scope)? onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UniversalSearchBar(
      placeholder: 'Search stays, tours, rides…',
      showScopeChips: true,
      onSearch: onSearch,
    );
  }
}


