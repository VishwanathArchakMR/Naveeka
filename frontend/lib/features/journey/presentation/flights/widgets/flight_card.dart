// lib/features/journey/presentation/flights/widgets/flight_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightCard extends StatelessWidget {
  const FlightCard({
    super.key,
    required this.id,
    required this.airline,
    required this.fromCode,
    required this.toCode,
    required this.departureTime, // DateTime or ISO string
    required this.arrivalTime, // DateTime or ISO string
    this.flightNumber,
    this.airlineLogoUrl,
    this.cabin, // e.g., "Economy", "Premium", "Business"
    this.refundable, // true = refundable, false = non-refundable, null = n/a
    this.stops = 0,
    this.layoverCities = const <String>[],
    this.durationLabel, // precomputed like "2h 35m" (optional)
    this.fareFrom,
    this.currency = '₹',
    this.badges = const <String>[], // e.g., ["Free reschedule","Meal"]
    this.onTap,
    this.onBook,
  });

  final String id;
  final String airline;
  final String fromCode;
  final String toCode;

  final dynamic departureTime;
  final dynamic arrivalTime;

  final String? flightNumber;
  final String? airlineLogoUrl;

  final String? cabin;
  final bool? refundable;

  final int stops;
  final List<String> layoverCities;

  final String? durationLabel;

  final num? fareFrom;
  final String currency;

  final List<String> badges;

  final VoidCallback? onTap;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final dep = _parseDate(departureTime);
    final arr = _parseDate(arrivalTime);

    final dfTime = DateFormat.Hm();
    final dfDate = DateFormat.MMMd();

    final times = (dep != null && arr != null)
        ? '${dfTime.format(dep)} — ${dfTime.format(arr)}'
        : '-';
    final dayAndDur = (dep != null && arr != null)
        ? '${dfDate.format(dep)} • ${_durationText(dep, arr) ?? (durationLabel ?? '')}'
        : (durationLabel ?? '-');

    final stopsLine = _stopsText(stops, layoverCities);

    return Card(
      clipBehavior: Clip.antiAlias, // ensures Ink ripple clips to rounded shape
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: airline + number + logo + fare
              Row(
                children: [
                  _LogoOrAvatar(logoUrl: airlineLogoUrl, text: airline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _airlineLine(airline, flightNumber),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (fareFrom != null)
                    Text(
                      '$currency${fareFrom!.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Route: codes + times + date/duration
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Codes vertical
                  SizedBox(
                    width: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fromCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(toCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Times
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(times, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(dayAndDur, style: const TextStyle(color: Colors.black54)),
                        if (stopsLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(stopsLine, style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Cabin, refundable + badges
              Row(
                children: [
                  if (cabin != null && cabin!.isNotEmpty)
                    _Chip(
                      label: cabin!,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  if (refundable != null) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      label: refundable! ? 'Refundable' : 'Non‑refundable',
                      color: refundable! ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.12),
                      textColor: refundable! ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ],
                  const Spacer(),
                  if (onBook != null)
                    FilledButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.flight_takeoff),
                      label: const Text('Book'),
                    ),
                ],
              ),

              if (badges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: badges.take(4).map((b) {
                    return _Chip(
                      label: b,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      textColor: Colors.black87,
                    );
                  }).toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _airlineLine(String airline, String? number) {
    if (number == null || number.isEmpty) return airline;
    return '$airline • $number';
  }

  String _stopsText(int stops, List<String> layovers) {
    if (stops <= 0) return 'Non‑stop';
    if (layovers.isEmpty) {
      return stops == 1 ? '1 stop' : '$stops stops';
    }
    final list = layovers.join(' • ');
    return stops == 1 ? '1 stop • $list' : '$stops stops • $list';
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  String? _durationText(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes;
    if (mins <= 0) return null;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class _LogoOrAvatar extends StatelessWidget {
  const _LogoOrAvatar({this.logoUrl, required this.text});
  final String? logoUrl;
  final String text;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          logoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return CircleAvatar(radius: radius, child: Text(_abbr(text)));
          },
        ),
      );
    }
    return CircleAvatar(radius: radius, child: Text(_abbr(text)));
  }

  String _abbr(String s) {
    final parts = s.trim().split(' ');
    if (parts.length == 1 && parts.first.length >= 2) {
      return parts.first.substring(0, 2).toUpperCase();
    }
    final first = parts.isNotEmpty ? parts.first.characters.firstOrNull : null;
    final last = parts.length > 1 ? parts.last.characters.firstOrNull : null;
    final buf = StringBuffer();
    if (first != null) buf.write(first.toUpperCase());
    if (last != null) buf.write(last.toUpperCase());
    final out = buf.toString();
    return out.isEmpty ? '?' : out;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
    );
  }
}
