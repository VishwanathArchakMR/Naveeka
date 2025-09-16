// lib/features/journey/presentation/buses/widgets/bus_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BusCard extends StatelessWidget {
  const BusCard({
    super.key,
    required this.id,
    required this.operatorName,
    required this.departureTime, // DateTime or ISO string
    required this.arrivalTime, // DateTime or ISO string
    this.fromCity,
    this.toCity,
    this.busType, // e.g., "AC Sleeper", "Non-AC Seater"
    this.features = const <String>[], // ["WiFi","Water","Charging"]
    this.rating,
    this.ratingCount,
    this.seatsLeft,
    this.fareFrom,
    this.currency = '₹',
    this.durationLabel, // optional precomputed like "7h 15m"
    this.onTap,
    this.onViewSeats,
  });

  final String id;
  final String operatorName;

  final dynamic departureTime;
  final dynamic arrivalTime;

  final String? fromCity;
  final String? toCity;

  final String? busType;
  final List<String> features;

  final double? rating;
  final int? ratingCount;

  final int? seatsLeft;

  final num? fareFrom;
  final String currency;

  final String? durationLabel;

  final VoidCallback? onTap;
  final VoidCallback? onViewSeats;

  @override
  Widget build(BuildContext context) {
    final dep = _parseDate(departureTime);
    final arr = _parseDate(arrivalTime);

    final dfTime = DateFormat.jm();
    final dfDate = DateFormat.MMMd();

    final timeRange = (dep != null && arr != null)
        ? '${dfTime.format(dep)} — ${dfTime.format(arr)}'
        : '-';
    final dayLine = (dep != null && arr != null)
        ? '${dfDate.format(dep)} • ${_durationText(dep, arr) ?? (durationLabel ?? '')}'
        : (durationLabel ?? '-');

    return Card(
      clipBehavior: Clip.antiAlias, // clip ripple and image/ink within rounded shape [1]
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Operator + type + rating
              Row(
                children: [
                  Expanded(
                    child: Text(
                      operatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (rating != null) ...[
                    const Icon(Icons.star_rate_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      rating!.toStringAsFixed(1) + (ratingCount != null ? ' (${ratingCount})' : ''),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              if (busType != null && busType!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  busType!,
                  style: const TextStyle(color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),

              // Middle: Time + cities
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeRange, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(dayLine, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  // Cities
                  if (fromCity != null || toCity != null) ...[
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (fromCity != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.my_location, size: 16, color: Colors.black45),
                              const SizedBox(width: 4),
                              Text(fromCity!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        if (toCity != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.black45),
                              const SizedBox(width: 4),
                              Text(toCity!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),
              // Features chips (limited to 3)
              if (features.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: features.take(3).map((f) {
                    return Chip(
                      label: Text(f),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(growable: false),
                ),

              const SizedBox(height: 12),
              // Bottom: seats + price + CTA
              Row(
                children: [
                  if (seatsLeft != null)
                    Text(
                      seatsLeft! > 0 ? '${seatsLeft} seats left' : 'Sold out',
                      style: TextStyle(
                        color: seatsLeft! > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  if (fareFrom != null)
                    Text(
                      '$currency${fareFrom!.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onViewSeats ?? onTap,
                    icon: const Icon(Icons.event_seat_outlined),
                    label: const Text('Select seats'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      // Let intl parse ISO or fallback to DateTime.tryParse
      return DateTime.tryParse(v);
    }
    return null;
  } // DateFormat/DateTime usage for locale-friendly times and parsing guidance [7][16]

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
