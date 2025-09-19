// lib/ui/components/cards/history_card.dart

import 'package:flutter/material.dart';

/// A simple type taxonomy for history items to render appropriate icons.
enum HistoryType { place, search, booking, route, article, other }

/// UI-only view model for the history card. Map domain models to this in the feature layer.
class HistoryViewData {
  const HistoryViewData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.type = HistoryType.other,
    this.thumbnailUrl,
    this.tags = const <String>[],
    this.meta,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final HistoryType type;
  final String? thumbnailUrl;
  final List<String> tags;
  final Map<String, String>? meta; // e.g., {"city":"Goa","country":"IN"}
}

/// A Material 3 card for recent history items with icon/thumbnail, title/subtitle,
/// timestamp, optional tags, and primary/secondary actions, with ripple and wide‑gamut‑safe colors.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.data,
    this.onTap,
    this.primaryLabel = 'Open',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.dense = false,
    this.heroTag,
  });

  final HistoryViewData data;
  final VoidCallback? onTap;

  final String primaryLabel;
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Widget leading = _buildLeading(context);
    final Widget content = _buildContent(context);
    final Widget actions = _buildActions(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        leading,
        const SizedBox(width: 12),
        Expanded(child: content),
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              row,
              if (_hasActions) ...[
                SizedBox(height: dense ? 8 : 12),
                actions,
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      (onPrimary != null && primaryLabel.trim().isNotEmpty) ||
      (onSecondary != null && (secondaryLabel?.trim().isNotEmpty ?? false));

  Widget _buildLeading(BuildContext context) {
    final double size = dense ? 42 : 54;

    if (data.thumbnailUrl != null && data.thumbnailUrl!.trim().isNotEmpty) {
      final thumb = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SizedBox(
            width: size,
            height: size,
            child: Image.network(
              data.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                _iconForType(data.type),
                size: dense ? 22 : 24,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      if (heroTag != null) {
        return Hero(tag: heroTag!, child: thumb);
      }
      return thumb;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(
        _iconForType(data.type),
        size: dense ? 22 : 24,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  IconData _iconForType(HistoryType t) {
    switch (t) {
      case HistoryType.place:
        return Icons.place_rounded;
      case HistoryType.search:
        return Icons.search_rounded;
      case HistoryType.booking:
        return Icons.receipt_long_rounded;
      case HistoryType.route:
        return Icons.directions_rounded;
      case HistoryType.article:
        return Icons.article_rounded;
      case HistoryType.other:
        return Icons.history_rounded;
    }
  }

  Widget _buildContent(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final title = Text(
      data.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (dense ? t.textTheme.titleSmall : t.textTheme.titleMedium)?.copyWith(fontWeight: FontWeight.w700),
    );

    final subtitle = Text(
      data.subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    );

    final timeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.schedule_rounded, size: dense ? 14 : 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          _formatRelative(data.timestamp),
          style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );

    final List<Widget> column = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: title),
          const SizedBox(width: 8),
          timeRow,
        ],
      ),
      const SizedBox(height: 4),
      subtitle,
    ];

    if (data.tags.isNotEmpty) {
      column.add(SizedBox(height: dense ? 6 : 8));
      column.add(_TagsWrap(tags: data.tags, dense: dense));
    }

    if (data.meta != null && data.meta!.isNotEmpty) {
      column.add(SizedBox(height: dense ? 6 : 8));
      column.add(_MetaRow(meta: data.meta!, dense: dense));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: column,
    );
  }

  Widget _buildActions(BuildContext context) {
    final t = Theme.of(context);
    final v = dense ? VisualDensity.compact : VisualDensity.standard;

    final buttons = <Widget>[];
    if (onSecondary != null && (secondaryLabel?.trim().isNotEmpty ?? false)) {
      buttons.add(OutlinedButton(
        onPressed: onSecondary,
        style: OutlinedButton.styleFrom(visualDensity: v),
        child: Text(secondaryLabel!),
      ));
      buttons.add(const SizedBox(width: 8));
    }
    if (onPrimary != null) {
      buttons.add(FilledButton.tonal(
        onPressed: onPrimary,
        style: FilledButton.styleFrom(visualDensity: v),
        child: Text(primaryLabel),
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Fallback simple date
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _TagsWrap extends StatelessWidget {
  const _TagsWrap({required this.tags, required this.dense});

  final List<String> tags;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double padH = dense ? 6 : 8;
    final double padV = dense ? 3 : 4;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((t) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            t,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.meta, required this.dense});

  final Map<String, String> meta;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final items = meta.entries.where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${e.key}:',
              style: t.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              e.value,
              style: t.textTheme.labelSmall?.copyWith(color: cs.onSurface),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}
