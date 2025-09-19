// lib/features/profile/presentation/widgets/my_journeys.dart

import 'package:flutter/material.dart';

/// Lightweight view model for a journey stop.
class JourneyStop {
  const JourneyStop({
    required this.title,
    this.subtitle,
    this.timeLabel, // e.g., "10:30 AM"
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? timeLabel;
  final IconData? icon;
}

/// Lightweight view model for a journey.
class JourneyView {
  const JourneyView({
    required this.id,
    required this.title,
    this.coverUrl,
    this.dateRange, // e.g., "12–16 Aug 2025"
    this.days,
    this.places,
    this.distanceKm,
    this.stops = const <JourneyStop>[],
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? dateRange;
  final int? days;
  final int? places;
  final double? distanceKm;
  final List<JourneyStop> stops;
}

/// Section widget that shows:
/// - Header with "My journeys" title and "New journey" action
/// - Pull-to-refresh and optional infinite scroll
/// - Drag-to-reorder list of journeys
/// - Expandable cards with a compact timeline of stops
class MyJourneys extends StatefulWidget {
  const MyJourneys({
    super.key,
    this.journeys = const <JourneyView>[],
    this.loading = false,
    this.hasMore = false,
    this.onRefresh,
    this.onLoadMore,
    this.onOpenJourney,
    this.onEditJourney,
    this.onDeleteJourney,
    this.onReorderJourneys,
    this.onCreateJourney,
    this.onOpenStop,
    this.sectionTitle = 'My journeys',
    this.emptyPlaceholder,
  });

  final List<JourneyView> journeys;
  final bool loading;
  final bool hasMore;

  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(JourneyView j)? onOpenJourney;
  final void Function(JourneyView j)? onEditJourney;
  final Future<void> Function(JourneyView j)? onDeleteJourney;
  final Future<void> Function(int oldIndex, int newIndex)? onReorderJourneys;
  final VoidCallback? onCreateJourney;
  final void Function(JourneyStop stop)? onOpenStop;

  final String sectionTitle;
  final Widget? emptyPlaceholder;

  @override
  State<MyJourneys> createState() => _MyJourneysState();
}

class _MyJourneysState extends State<MyJourneys> {
  final _scrollKey = GlobalKey();
  bool _atEndRequested = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.journeys;

    final list = NotificationListener<ScrollNotification>(
      // Detect scroll end to trigger load-more when available.
      onNotification: (n) {
        if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
          if (!_atEndRequested) {
            _atEndRequested = true;
            widget.onLoadMore!.call().whenComplete(() => _atEndRequested = false);
          }
        }
        return false;
      },
      child: ReorderableListView.builder(
        key: _scrollKey,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        itemCount: items.length + 1,
        onReorder: (oldIndex, newIndex) async {
          if (widget.onReorderJourneys == null) return;
          // Adjust for the extra footer.
          final max = items.length;
          if (oldIndex >= max || newIndex > max) return;
          await widget.onReorderJourneys!(oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex);
        },
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        itemBuilder: (context, i) {
          if (i == items.length) {
            return _Footer(
              key: const ValueKey('journeys-footer'),
              loading: widget.loading,
              hasMore: widget.hasMore,
              isEmpty: items.isEmpty,
            );
          }
          final j = items[i];
          return _JourneyTile(
            key: ValueKey(j.id),
            j: j,
            onOpen: widget.onOpenJourney,
            onEdit: widget.onEditJourney,
            onDelete: widget.onDeleteJourney,
            onOpenStop: widget.onOpenStop,
          );
        },
      ),
    ); // ReorderableListView enables drag-and-drop reordering of list items using long-press/drag gestures, suitable for user-curated sequences. [10][13]

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 560,
        child: Column(
          children: [
            // Header actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (widget.onCreateJourney != null)
                    OutlinedButton.icon(
                      onPressed: widget.onCreateJourney,
                      icon: const Icon(Icons.add_road_outlined),
                      label: const Text('New journey'),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: widget.onRefresh ?? () async {},
                child: items.isEmpty && !widget.loading && !widget.hasMore
                    ? (widget.emptyPlaceholder ??
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No journeys yet'),
                          ),
                        ))
                    : list,
              ),
            ), // RefreshIndicator wraps the scrollable to support pull-to-refresh with platform-appropriate visuals. [21][22]
          ],
        ),
      ),
    );
  }
}

class _JourneyTile extends StatefulWidget {
  const _JourneyTile({
    super.key,
    required this.j,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    this.onOpenStop,
  });

  final JourneyView j;
  final void Function(JourneyView j)? onOpen;
  final void Function(JourneyView j)? onEdit;
  final Future<void> Function(JourneyView j)? onDelete;
  final void Function(JourneyStop stop)? onOpenStop;

  @override
  State<_JourneyTile> createState() => _JourneyTileState();
}

class _JourneyTileState extends State<_JourneyTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final j = widget.j;
    final stats = [
      if (j.days != null) '${j.days}d',
      if (j.places != null) '${j.places} places',
      if (j.distanceKm != null) '${j.distanceKm!.toStringAsFixed(1)} km',
    ].where((e) => e.toString().trim().isNotEmpty).join(' · ');

    return Card(
      key: widget.key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row with cover, title, dates, stats, actions
          InkWell(
            onTap: widget.onOpen == null ? null : () => widget.onOpen!(j),
            child: Row(
              children: [
                _Cover(url: j.coverUrl),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        if ((j.dateRange ?? '').trim().isNotEmpty)
                          Text(j.dateRange!.trim(), style: const TextStyle(color: Colors.black54)),
                        if (stats.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(stats, style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // Expanded body: compact timeline of stops
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _StopsTimeline(stops: j.stops, onOpenStop: widget.onOpenStop),
            secondChild: const SizedBox.shrink(),
          ),

          // Footer actions
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onOpen == null ? null : () => widget.onOpen!(j),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onEdit == null ? null : () => widget.onEdit!(j),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onDelete == null ? null : () => widget.onDelete!(j),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 76,
      child: url == null || url!.trim().isEmpty
          ? Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.landscape_outlined, color: Colors.black38),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
              ),
            ),
    );
  }
}

class _StopsTimeline extends StatelessWidget {
  const _StopsTimeline({required this.stops, this.onOpenStop});
  final List<JourneyStop> stops;
  final void Function(JourneyStop stop)? onOpenStop;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('No stops added yet'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: List.generate(stops.length, (i) {
          final s = stops[i];
          final isFirst = i == 0;
          final isLast = i == stops.length - 1;
          return InkWell(
            onTap: onOpenStop == null ? null : () => onOpenStop!(s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline rail
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      // Top connector
                      Container(
                        height: isFirst ? 8 : 14,
                        width: 2,
                        color: isFirst ? Colors.transparent : Colors.black26,
                      ),
                      // Dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Bottom connector
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isLast ? Colors.transparent : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if ((s.timeLabel ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  s.timeLabel!.trim(),
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                            if (s.icon != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(s.icon, size: 16, color: Colors.black54),
                              ),
                            Expanded(
                              child: Text(
                                s.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if ((s.subtitle ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              s.subtitle!.trim(),
                              style: const TextStyle(color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({super.key, required this.loading, required this.hasMore, required this.isEmpty});
  final bool loading;
  final bool hasMore;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    if (loading && isEmpty) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    if (loading && hasMore) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (!hasMore) {
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const Text('No more journeys'),
      );
    }
    return const SizedBox(height: 24);
  }
}
