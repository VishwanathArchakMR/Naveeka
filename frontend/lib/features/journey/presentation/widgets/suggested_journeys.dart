// lib/features/journey/presentation/widgets/suggested_journeys.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SuggestedJourney {
  const SuggestedJourney({
    required this.id,
    required this.title, // e.g., "Goa long weekend"
    required this.city,  // e.g., "Goa"
    required this.imageUrl,
    required this.startDate, // DateTime
    required this.endDate,   // DateTime
    this.flights = true,
    this.hotels = true,
    this.activitiesCount = 0,
    this.estimatedBudget, // num per person or total
    this.currency = '₹',
    this.tags = const <String>[], // e.g., ['Beach','Romantic']
    this.onTap, // void Function(SuggestedJourney)
  });

  final String id;
  final String title;
  final String city;
  final String imageUrl;
  final DateTime startDate;
  final DateTime endDate;

  final bool flights;
  final bool hotels;
  final int activitiesCount;

  final num? estimatedBudget;
  final String currency;

  final List<String> tags;

  final void Function(SuggestedJourney)? onTap;
}

class SuggestedJourneys extends StatelessWidget {
  const SuggestedJourneys({
    super.key,
    required this.items,
    this.title = 'Suggested journeys',
    this.height = 180,
    this.cardWidth = 300,
    this.onTapJourney,
  });

  final List<SuggestedJourney> items;
  final String title;
  final double height;
  final double cardWidth;

  /// Optional global tap handler; if null, item.onTap is used.
  final void Function(SuggestedJourney journey)? onTapJourney;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink(); // Empty-safe early return [1]

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),

        // Horizontal rail
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final j = items[i];
              return SizedBox(
                width: cardWidth,
                child: _JourneyCard(
                  data: j,
                  onTap: () => (onTapJourney ?? j.onTap)?.call(j),
                ),
              );
            },
          ),
        ), // ListView is the standard scrolling widget for linear lists, supporting horizontal rails with scrollDirection set to Axis.horizontal [1][5]
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.data, this.onTap});

  final SuggestedJourney data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd();
    final dateStr = '${df.format(data.startDate)} — ${df.format(data.endDate)}'; // Human-friendly date window via intl DateFormat [13]

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with city label
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      data.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback(context),
                      loadingBuilder: (ctx, child, progress) => progress == null ? child : _imgLoading(context),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _pill(
                      context,
                      icon: Icons.place_outlined,
                      text: data.city,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + budget
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (data.estimatedBudget != null)
                        Text(
                          '${data.currency}${data.estimatedBudget!.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.black54),
                  ),

                  const SizedBox(height: 8),

                  // Highlights row
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (data.flights) _mini(context, Icons.flight_takeoff_outlined, 'Flights'),
                      if (data.hotels) _mini(context, Icons.hotel_outlined, 'Hotels'),
                      if (data.activitiesCount > 0) _mini(context, Icons.attractions_outlined, '${data.activitiesCount} activities'),
                    ],
                  ),

                  if (data.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: data.tags.take(4).map((t) {
                        return _badge(
                          context,
                          t,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          fg: Colors.black87,
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ); // Card + InkWell creates a tappable, elevated tile with proper Material ripple and clipping to rounded shape [21][22]
  }

  Widget _pill(BuildContext context, {required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _badge(BuildContext context, String label, {required Color color, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _imgFallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.black45),
          SizedBox(width: 6),
          Text('No image', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _imgLoading(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
