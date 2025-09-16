// lib/features/navee_ai/presentation/widgets/ai_response_cards.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Optional: enable Markdown rendering; add flutter_markdown to pubspec.yaml:
// dependencies:
//   flutter_markdown: ^0.7.3+1 (or latest)
import 'package:flutter_markdown/flutter_markdown.dart';

/// High-level widget to render one or more AI responses as cards.
/// - Detects JSON (object/array) and shows structured itinerary/suggestions.
/// - Renders plain text/markdown with copy and expand controls.
/// - Provides consistent Material look using Card + InkWell and ExpansionTile.
class AiResponseCards extends StatelessWidget {
  const AiResponseCards({
    super.key,
    required this.items,
    this.currency = '₹',
  });

  /// Each item is either:
  /// - String content (markdown/plain)
  /// - Map<String,dynamic> JSON (itinerary-like)
  /// - List<dynamic> JSON array (suggestions)
  final List<dynamic> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final it in items) ...[
          _AiCard(
            payload: it,
            currency: currency,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.payload, required this.currency});

  final dynamic payload;
  final String currency;

  bool _looksJsonString(String s) {
    final t = s.trim();
    return (t.startsWith('{') && t.endsWith('}')) || (t.startsWith('[') && t.endsWith(']'));
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (payload is Map<String, dynamic>) {
      child = _JsonStructuredCard(map: payload as Map<String, dynamic>, currency: currency);
    } else if (payload is List) {
      child = _SuggestionsListCard(list: (payload as List).cast<dynamic>(), currency: currency);
    } else if (payload is String) {
      // Try to parse JSON if it looks like JSON
      final s = payload as String;
      if (_looksJsonString(s)) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is Map<String, dynamic>) {
            child = _JsonStructuredCard(map: decoded, currency: currency);
          } else if (decoded is List) {
            child = _SuggestionsListCard(list: decoded, currency: currency);
          } else {
            child = _MarkdownTextCard(text: s);
          }
        } catch (_) {
          child = _MarkdownTextCard(text: s);
        }
      } else {
        child = _MarkdownTextCard(text: s);
      }
    } else {
      child = _MarkdownTextCard(text: payload.toString());
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

class _MarkdownTextCard extends StatelessWidget {
  const _MarkdownTextCard({required this.text});
  final String text;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'))); // Use Clipboard.setData with ClipboardData and show a SnackBar for feedback [9][12]
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with actions
        Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.smart_toy_outlined),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('AI response', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_all_outlined),
            ), // Copy is offered via Clipboard API and a trailing action icon per Material patterns [9]
          ],
        ),
        const Divider(height: 1),

        // Content (Markdown)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: MarkdownBody(
            data: text,
            selectable: true,
          ),
        ), // MarkdownBody renders GitHub-flavored markdown into rich text; set selectable for text selection [10][13]
      ],
    );
  }
}

class _JsonStructuredCard extends StatelessWidget {
  const _JsonStructuredCard({required this.map, required this.currency});
  final Map<String, dynamic> map;
  final String currency;

  Future<void> _copy(BuildContext context) async {
    final s = const JsonEncoder.withIndent('  ').convert(map);
    await Clipboard.setData(ClipboardData(text: s));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied'))); // Copy JSON using ClipboardData and show feedback [9][12]
  }

  @override
  Widget build(BuildContext context) {
    // Heuristic: itinerary-like JSON with "days"
    final days = map['days'];
    final summary = map['summary'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.map_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _title(summary) ?? 'Itinerary',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy JSON',
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ],
        ),
        const Divider(height: 1),

        // Summary row(s)
        if (summary is Map<String, dynamic>)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (summary['city'] != null) _iconText(Icons.place_outlined, summary['city'].toString()),
                if (summary['adults'] != null) _iconText(Icons.group_outlined, '${summary['adults']} adults'),
                if (summary['children'] != null && summary['children'] != 0) _iconText(Icons.child_care_outlined, '${summary['children']} children'),
                if (summary['style'] != null && (summary['style'] as String).trim().isNotEmpty) _iconText(Icons.category_outlined, summary['style'].toString()),
                if (summary['currency'] != null && (summary['currency'] as String).trim().isNotEmpty) _iconText(Icons.currency_exchange, summary['currency'].toString()),
              ],
            ),
          ),

        // Days as expandable sections
        if (days is List && days.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              children: [
                for (int i = 0; i < days.length; i++)
                  _DayTile(
                    day: days[i] as Map<String, dynamic>,
                    index: i,
                    currency: currency,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String? _title(Map<String, dynamic>? summary) {
    if (summary == null) return null;
    final city = (summary['city'] ?? '').toString();
    if (city.isEmpty) return null;
    return '$city itinerary';
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.index, required this.currency});
  final Map<String, dynamic> day;
  final int index;
  final String currency;

  Future<void> _copy(BuildContext context) async {
    final s = const JsonEncoder.withIndent('  ').convert(day);
    await Clipboard.setData(ClipboardData(text: s));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Day ${index + 1} copied'))); // Copy a day's JSON block via Clipboard for granularity [9]
  }

  @override
  Widget build(BuildContext context) {
    final date = (day['date'] ?? '').toString();
    final items = (day['items'] is List) ? (day['items'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(
        date.isNotEmpty ? 'Day ${index + 1} • $date' : 'Day ${index + 1}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: IconButton(
        tooltip: 'Copy day',
        onPressed: () => _copy(context),
        icon: const Icon(Icons.copy_outlined),
      ),
      children: [
        if (items.isEmpty)
          const ListTile(
            dense: true,
            leading: Icon(Icons.info_outline),
            title: Text('No items for this day'),
          )
        else
          ...items.map((it) {
            final t = (it['time'] ?? '').toString();
            final title = (it['title'] ?? '').toString();
            final notes = (it['notes'] ?? '').toString();
            return ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(title.isEmpty ? 'Activity' : title),
              subtitle: Text(
                [if (t.isNotEmpty) t, if (notes.isNotEmpty) notes].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
      ],
    ); // ExpansionTile creates collapsible sections for day-wise items in an itinerary for compact readability [1][2]
  }
}

class _SuggestionsListCard extends StatelessWidget {
  const _SuggestionsListCard({required this.list, required this.currency});
  final List<dynamic> list;
  final String currency;

  Future<void> _copyAll(BuildContext context) async {
    final s = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: s));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestions copied'))); // Copy array JSON and acknowledge with SnackBar [9]
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Itinerary ideas', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            IconButton(
              tooltip: 'Copy JSON',
              onPressed: () => _copyAll(context),
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ],
        ),
        const Divider(height: 1),

        // List
        if (suggestions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No suggestions', style: TextStyle(color: Colors.black54)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: suggestions.map((m) {
                final title = (m['title'] ?? '').toString();
                final days = m['days'] is num ? (m['days'] as num).toInt() : null;
                final highlights = (m['highlights'] is List) ? List<String>.from(m['highlights']) : const <String>[];
                final budget = m['budgetFrom'] is num ? (m['budgetFrom'] as num).toDouble() : null;

                return ListTile(
                  leading: const Icon(Icons.travel_explore_outlined),
                  title: Text(title.isEmpty ? 'Trip idea' : title),
                  subtitle: Text(
                    [
                      if (days != null) '$days day${days == 1 ? '' : 's'}',
                      if (highlights.isNotEmpty) highlights.take(3).join(' • '),
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: budget == null
                      ? null
                      : Text(
                          '$currency${budget.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                );
              }).toList(growable: false),
            ),
          ),
      ],
    ); // Using ListTiles inside a Card yields a dense, readable summary; Expansion isn’t needed for short suggestion lists [21]
  }
}
