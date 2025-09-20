// lib/features/profile/presentation/widgets/travel_stats.dart

import 'package:flutter/material.dart';

enum UnitSystem { metric, imperial }

class TravelStats extends StatefulWidget {
  const TravelStats({
    super.key,
    // Core stats
    this.totalDistanceKm = 0.0, // total distance traveled (km)
    this.totalDays = 0, // total days on trips
    this.totalTrips = 0, // number of trips/journeys
    this.countries = 0, // unique countries visited
    this.cities = 0, // unique cities visited

    // Optional breakdowns
    this.continentCounts = const <String, int>{}, // e.g., {'Europe': 12, 'Asia': 7}
    this.transportMix = const <String, double>{}, // 0..1 ratios e.g., {'Air': .6, 'Rail': .2, 'Road': .2}

    // UI
    this.sectionTitle = 'Travel stats',
    this.initialUnit = UnitSystem.metric,
  });

  final double totalDistanceKm;
  final int totalDays;
  final int totalTrips;
  final int countries;
  final int cities;

  final Map<String, int> continentCounts;
  final Map<String, double> transportMix;

  final String sectionTitle;
  final UnitSystem initialUnit;

  @override
  State<TravelStats> createState() => _TravelStatsState();
}

class _TravelStatsState extends State<TravelStats> {
  late UnitSystem _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
  }

  @override
  Widget build(BuildContext context) {
    final miles = widget.totalDistanceKm * 0.621371;
    final distanceText = _unit == UnitSystem.metric
        ? '${_fmtNum(widget.totalDistanceKm)} km'
        : '${_fmtNum(miles)} mi';

    final tiles = <_Tile>[
      _Tile(icon: Icons.route_outlined, label: 'Distance', value: distanceText),
      _Tile(icon: Icons.public_outlined, label: 'Countries', value: '${widget.countries}'),
      _Tile(icon: Icons.location_city_outlined, label: 'Cities', value: '${widget.cities}'),
      _Tile(icon: Icons.calendar_month_outlined, label: 'Days', value: '${widget.totalDays}'),
      _Tile(icon: Icons.map_outlined, label: 'Trips', value: '${widget.totalTrips}'),
    ];

    final chips = widget.continentCounts.entries
        .where((e) => e.key.trim().isNotEmpty && e.value > 0)
        .map((e) => Chip(
              label: Text('${e.key}: ${e.value}'),
              visualDensity: VisualDensity.compact,
            ))
        .toList(growable: false);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + unit toggle
            Row(
              children: [
                Expanded(
                  child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                SegmentedButton<UnitSystem>(
                  segments: const [
                    ButtonSegment(value: UnitSystem.metric, label: Text('km')),
                    ButtonSegment(value: UnitSystem.imperial, label: Text('mi')),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() => _unit = s.first),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Responsive grid tiles
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cross = w >= 900 ? 3 : (w >= 540 ? 3 : 2);
                return GridView.count(
                  crossAxisCount: cross,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.1,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: tiles.map((t) => _StatPill(tile: t)).toList(growable: false),
                );
              },
            ),

            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('By continent', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],

            if (widget.transportMix.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Transport mix', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Column(
                children: widget.transportMix.entries.map((e) {
                  final label = e.key.trim();
                  final v = e.value.clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 80, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 40, child: Text('${(v * 100).round()}%')),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtNum(double km) {
    if (km >= 1000) return km.toStringAsFixed(0);
    if (km >= 100) return km.toStringAsFixed(1);
    if (km >= 10) return km.toStringAsFixed(1);
    return km.toStringAsFixed(2);
  }
}

class _Tile {
  const _Tile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.tile});
  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(tile.icon),
            const SizedBox(width: 8),
            Expanded(child: Text(tile.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(tile.value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
