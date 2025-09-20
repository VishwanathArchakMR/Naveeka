// lib/features/quick_actions/presentation/booking/widgets/booking_search_bar.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'booking_location_filter.dart';

class BookingSearchBar extends StatefulWidget {
  const BookingSearchBar({
    super.key,
    // Query + suggestions
    required this.query,
    required this.onQueryChanged,
    this.onSubmitted,
    this.onSuggest, // async suggestions
    this.hintText = 'Search restaurants, activities…',

    // Filters
    this.location,
    this.onPickLocation,
    this.dateRange,
    this.onPickDates, // returns DateTimeRange?
    this.guests = 2,
    this.onPickGuests, // returns int?

    // Actions
    this.onOpenFilters,
    this.enabled = true,
  });

  // Search
  final String query;
  final ValueChanged<String> onQueryChanged;
  final void Function(String value)? onSubmitted;
  final Future<List<String>> Function(String query)? onSuggest;
  final String hintText;

  // Filters
  final BookingLocationSelection? location;
  final Future<BookingLocationSelection?> Function()? onPickLocation;
  final DateTimeRange? dateRange;
  final Future<DateTimeRange?> Function()? onPickDates;
  final int guests;
  final Future<int?> Function()? onPickGuests;

  // More
  final VoidCallback? onOpenFilters;
  final bool enabled;

  @override
  State<BookingSearchBar> createState() => _BookingSearchBarState();
}

class _BookingSearchBarState extends State<BookingSearchBar> {
  late final SearchController _controller;
  Timer? _debounce;
  List<String> _suggestions = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller = SearchController(); // no named 'text' parameter
    _controller.text = widget.query; // set initial text after construction [web:6491]
    _controller.addListener(_onSearchTextChanged);
  }

  @override
  void didUpdateWidget(covariant BookingSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controller text consistent with external state
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onSearchTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final q = _controller.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      widget.onQueryChanged(q);
      if (widget.onSuggest != null) {
        final next = await widget.onSuggest!(q);
        if (!mounted) return;
        setState(() => _suggestions = next);
        // When suggestions change while the view is open, SearchAnchor rebuilds the overlay.
      }
    });
  }

  String _formatDates(DateTimeRange? r) {
    if (r == null) return 'Any dates';
    final s = _fmtDate(r.start);
    final e = _fmtDate(r.end);
    return '$s → $e';
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar with overlay suggestions
        SearchAnchor.bar(
          isFullScreen: false,
          searchController: _controller,
          barHintText: widget.hintText,
          // Use WidgetStatePropertyAll (MaterialStatePropertyAll is deprecated alias) [web:6502][web:6509][web:6500]
          barElevation: const WidgetStatePropertyAll<double>(1),
          barBackgroundColor: WidgetStatePropertyAll<Color>(
            Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          barLeading: const Icon(Icons.search), // single widget, not a list [web:6493]
          barTrailing: [
            if (widget.onOpenFilters != null)
              IconButton(
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
                onPressed: widget.enabled ? widget.onOpenFilters : null,
              ),
          ],
          // Use onSubmitted on the bar (SearchAnchor.bar) instead of the unsupported viewOnSubmitted [web:6493]
          onSubmitted: (value) {
            final v = value.trim();
            if (v.isEmpty) return;
            widget.onSubmitted?.call(v);
            _controller.closeView(v);
          },
          suggestionsBuilder: (context, controller) {
            final items = _suggestions.isEmpty && controller.text.isEmpty
                ? const <String>[]
                : _suggestions;
            if (items.isEmpty) {
              return <Widget>[
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    controller.text.isEmpty ? 'Type to search…' : 'No suggestions',
                  ),
                ),
              ];
            }
            return items.map((s) {
              return ListTile(
                leading: const Icon(Icons.travel_explore_outlined),
                title: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  controller.closeView(s);
                  widget.onSubmitted?.call(s);
                },
              );
            });
          },
        ), // SearchAnchor.bar uses barX and onSubmitted parameters; viewOnSubmitted applies to the plain SearchAnchor constructor only. [web:6493][web:6495]

        const SizedBox(height: 8),

        // Quick filter chips row (location, dates, guests)
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Location chip
              InputChip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text(
                  widget.location?.toString() ?? 'Location',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: !widget.enabled || widget.onPickLocation == null
                    ? null
                    : () async {
                        final sel = await widget.onPickLocation!.call();
                        if (sel == null) return;
                        // Upstream container should handle updating selected location state.
                      },
              ),

              // Date chip
              InputChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                label: Text(
                  _formatDates(widget.dateRange),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: !widget.enabled || widget.onPickDates == null
                    ? null
                    : () async {
                        // Use showDateRangePicker inside onPickDates implementation to keep this widget stateless.
                        await widget.onPickDates!.call();
                      },
              ),

              // Guests chip
              InputChip(
                avatar: const Icon(Icons.group_outlined, size: 16),
                label: Text('${widget.guests} guest${widget.guests == 1 ? '' : 's'}'),
                onPressed: !widget.enabled || widget.onPickGuests == null
                    ? null
                    : () async {
                        await widget.onPickGuests!.call();
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
