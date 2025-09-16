// lib/features/journey/presentation/trains/widgets/train_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrainCard extends StatelessWidget {
  const TrainCard({
    super.key,
    required this.id,
    required this.trainName,
    required this.fromCode,
    required this.toCode,
    required this.departureTime, // DateTime or ISO string
    required this.arrivalTime,   // DateTime or ISO string
    this.trainNumber,
    this.viaStations = const <String>[],
    this.durationLabel, // optional precomputed like "6h 45m"
    this.classes = const <String, bool>{}, // e.g., {'SL': true, '3A': false, '2S': true}
    this.fareFrom,
    this.currency = '₹',
    this.badges = const <String>[], // e.g., ['Pantry','On-time','Wi‑Fi']
    this.onTap,
    this.onBook,
  });

  final String id;
  final String trainName;
  final String? trainNumber;

  final String fromCode;
  final String toCode;

  final dynamic departureTime;
  final dynamic arrivalTime;

  final List<String> viaStations;
  final String? durationLabel;

  final Map<String, bool> classes;

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

    final via = viaStations.isNotEmpty ? 'via ${viaStations.take(3).join(' • ')}' : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: onTap ?? onBook,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: name + number + fare
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _titleLine(trainName, trainNumber),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

              // Route: station codes + times + date/duration + via
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(times, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(dayAndDur, style: const TextStyle(color: Colors.black54)),
                        if (via != null && via.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(via, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Class availability + CTA
              Row(
                children: [
                  Expanded(child: _ClassChips(classes: classes)),
                  const SizedBox(width: 8),
                  if (onBook != null)
                    FilledButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.train),
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

  String _titleLine(String name, String? number) {
    if (number == null || number.isEmpty) return name;
    return '$name • $number';
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

class _ClassChips extends StatelessWidget {
  const _ClassChips({required this.classes});
  final Map<String, bool> classes;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: classes.entries.map((e) {
        final label = e.key;
        final available = e.value == true;
        final color = available ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12);
        final fg = available ? Colors.green.shade700 : Colors.black54;
        return _Chip(label: label, color: color, textColor: fg);
      }).toList(growable: false),
    );
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
