// lib/features/journey/presentation/bookings/widgets/refunds_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Normalized refund item shape expected:
/// {
///   id, bookingRef, amount, currency, status, // 'initiated'|'processing'|'completed'|'failed'
///   requestedAt (DateTime|ISO), completedAt (DateTime|ISO)?,
///   method, // e.g., 'CARD **** 1234', 'UPI user@bank', 'Wallet'
///   note?
/// }
class RefundsTab extends StatefulWidget {
  const RefundsTab({
    super.key,
    required this.items,
    this.onRefresh,
    this.onView,
    this.emptyTitle = 'No refunds yet',
    this.emptySubtitle = 'Refunds for cancelled or changed bookings will appear here',
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function()? onRefresh;
  final void Function(Map<String, dynamic> refund)? onView;

  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<RefundsTab> createState() => _RefundsTabState();
}

enum _RefundFilter { all, inProgress, completed, failed }

class _RefundsTabState extends State<RefundsTab> {
  _RefundFilter _filter = _RefundFilter.all;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(widget.items, _filter);
    final sections = _groupByMonth(filtered);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: sections.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                // Replaced unsupported icon with a valid Material icon.
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  widget.emptyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: sections.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    filter: _filter,
                    onFilterChanged: (f) => setState(() => _filter = f),
                  );
                }
                final sec = sections[index - 1];
                return _Section(
                  title: sec.title,
                  items: sec.items,
                  onView: widget.onView,
                );
              },
            ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> items, _RefundFilter filter) {
    if (filter == _RefundFilter.all) return items;
    return items.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      switch (filter) {
        case _RefundFilter.inProgress:
          return s == 'initiated' || s == 'processing';
        case _RefundFilter.completed:
          return s == 'completed';
        case _RefundFilter.failed:
          return s == 'failed';
        case _RefundFilter.all:
          return true;
      }
    }).toList(growable: false);
  }

  List<_MonthSection> _groupByMonth(List<Map<String, dynamic>> items) {
    final df = DateFormat.yMMMM();
    // Sort by requestedAt desc
    final list = [...items];
    list.sort((a, b) {
      final ad = _parseDate(a['requestedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _parseDate(b['requestedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final sections = <_MonthSection>[];
    String? currentKey;
    for (final r in list) {
      final d = _parseDate(r['requestedAt']);
      final key = d != null ? df.format(d) : 'Undated';
      if (currentKey != key) {
        sections.add(_MonthSection(title: key, items: []));
        currentKey = key;
      }
      sections.last.items.add(r);
    }
    return sections;
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.filter, required this.onFilterChanged});

  final _RefundFilter filter;
  final ValueChanged<_RefundFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            'Refunds',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SegmentedButton<_RefundFilter>(
            segments: const [
              ButtonSegment(value: _RefundFilter.all, label: Text('All'), icon: Icon(Icons.inbox_outlined)),
              ButtonSegment(value: _RefundFilter.inProgress, label: Text('In progress'), icon: Icon(Icons.schedule)),
              ButtonSegment(value: _RefundFilter.completed, label: Text('Completed'), icon: Icon(Icons.check_circle_outline)),
              ButtonSegment(value: _RefundFilter.failed, label: Text('Failed'), icon: Icon(Icons.error_outline)),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onFilterChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    this.onView,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> refund)? onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthHeader(title: title),
        const SizedBox(height: 8),
        ...items.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RefundRow(
                data: r,
                onView: onView,
              ),
            )),
      ],
    );
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({required this.data, this.onView});

  final Map<String, dynamic> data;
  final void Function(Map<String, dynamic> refund)? onView;

  @override
  Widget build(BuildContext context) {
    final bookingRef = (data['bookingRef'] ?? data['reference'] ?? '').toString();
    final amount = _toNum(data['amount']);
    final currency = (data['currency'] ?? '₹').toString();
    final method = (data['method'] ?? '').toString();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final requestedAt = _parseDate(data['requestedAt']);
    final completedAt = _parseDate(data['completedAt']);
    final note = (data['note'] ?? '').toString();

    final dfDate = DateFormat.yMMMEd();
    final dfTime = DateFormat.jm();

    final spec = _statusSpec(context, status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // Top row: amount + status chip
            Row(
              children: [
                Text(
                  amount != null ? _formatCurrency(amount, currency) : '-',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                Chip(
                  label: Text(spec.label),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: spec.fg, fontWeight: FontWeight.w600),
                  backgroundColor: spec.bg,
                  side: BorderSide(color: spec.border),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Middle rows: ref, method, dates
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bookingRef.isEmpty ? '-' : 'Ref: $bookingRef',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
            if (method.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.credit_card, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      method,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _dateLine(dfDate, dfTime, requestedAt, completedAt),
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note, style: const TextStyle(color: Colors.black87))),
                ],
              ),
            ],
            // Progress (for in-progress)
            if (status == 'initiated' || status == 'processing') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: status == 'initiated' ? 0.25 : 0.6, // heuristic hint
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status == 'initiated' ? 'Initiated' : 'Processing',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Actions
            Row(
              children: [
                if (onView != null)
                  OutlinedButton.icon(
                    onPressed: () => onView!(data),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                  ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLine(DateFormat dfDate, DateFormat dfTime, DateTime? req, DateTime? done) {
    if (req == null && done == null) return '-';
    if (req != null && done != null) {
      final sameDay = req.year == done.year && req.month == done.month && req.day == done.day;
      if (sameDay) {
        return 'Requested: ${dfDate.format(req)} • ${dfTime.format(req)}  •  Completed: ${dfTime.format(done)}';
      }
      return 'Requested: ${dfDate.format(req)}  •  Completed: ${dfDate.format(done)}';
    }
    if (req != null) return 'Requested: ${dfDate.format(req)} • ${dfTime.format(req)}';
    return 'Completed: ${dfDate.format(done!)} • ${dfTime.format(done)}';
  }

  String _formatCurrency(num amount, String currency) {
    final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 0);
    return fmt.format(amount);
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  _StatusSpec _statusSpec(BuildContext context, String s) {
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case 'initiated':
        return _StatusSpec(
          label: 'Initiated',
          fg: scheme.onSecondaryContainer,
          bg: scheme.secondaryContainer.withValues(alpha: 0.6),
          border: scheme.secondaryContainer,
        );
      case 'processing':
        return _StatusSpec(
          label: 'Processing',
          fg: scheme.onSecondaryContainer,
          bg: scheme.secondaryContainer.withValues(alpha: 0.6),
          border: scheme.secondaryContainer,
        );
      case 'completed':
        return _StatusSpec(
          label: 'Completed',
          fg: Colors.white,
          bg: Colors.green.withValues(alpha: 0.8),
          border: Colors.green,
        );
      case 'failed':
        return _StatusSpec(
          label: 'Failed',
          fg: Colors.white,
          bg: Colors.redAccent.withValues(alpha: 0.8),
          border: Colors.redAccent,
        );
      default:
        return _StatusSpec(
          label: s.isEmpty ? 'Unknown' : s,
          fg: scheme.onSurface,
          bg: scheme.surfaceContainerHighest,
          border: scheme.outlineVariant,
        );
    }
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MonthSection {
  _MonthSection({required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;
}

class _StatusSpec {
  const _StatusSpec({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
  });
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
}
