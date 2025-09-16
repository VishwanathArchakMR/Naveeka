// lib/ui/components/cards/booking_card.dart

import 'package:flutter/material.dart';

/// High-level booking state for consistent visuals.
enum BookingStatus { pending, confirmed, completed, canceled, refunded }

/// Lightweight view model for the booking card.
/// Keep this UI-only and map domain models to it in the feature layer.
class BookingViewData {
  const BookingViewData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.start,
    this.end,
    this.status = BookingStatus.pending,
    this.priceText,
    this.code, // PNR/confirmation
    this.thumbnailUrl,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime? end;
  final BookingStatus status;
  final String? priceText;
  final String? code;
  final String? thumbnailUrl;
  final List<String> tags;
}

/// A reusable booking card with thumbnail, title/subtitle, dates, status badge,
/// price, tags, and optional primary/secondary actions.
/// Material 3 design, ripple via InkWell, wide-gamut safe colors (withValues).
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.data,
    this.onTap,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.primaryLabel = 'View',
    this.secondaryLabel,
    this.dense = false,
    this.heroTag,
  });

  final BookingViewData data;
  final VoidCallback? onTap;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Widget statusChip = _StatusBadge(status: data.status);

    final Widget titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dense
                ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        statusChip,
      ],
    );

    final Widget subtitleRow = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            data.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    final Widget dateRow = _DatesLine(start: data.start, end: data.end, dense: dense);

    final Widget bottomRow = _BottomRow(
      priceText: data.priceText,
      code: data.code,
      dense: dense,
      onPrimaryAction: onPrimaryAction,
      onSecondaryAction: onSecondaryAction,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
    );

    final List<Widget> columnChildren = <Widget>[
      titleRow,
      const SizedBox(height: 4),
      subtitleRow,
      const SizedBox(height: 8),
      dateRow,
    ];

    if (data.tags.isNotEmpty) {
      columnChildren.add(const SizedBox(height: 8));
      columnChildren.add(_TagsWrap(tags: data.tags, dense: dense));
    }

    columnChildren.add(const SizedBox(height: 8));
    columnChildren.add(bottomRow);

    final Widget textColumn = Expanded(
      child: Padding(
        padding: EdgeInsets.all(dense ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnChildren,
        ),
      ),
    );

    final Widget? leading = data.thumbnailUrl == null
        ? null
        : _Thumb(url: data.thumbnailUrl!, heroTag: heroTag, dense: dense);

    final Widget cardBody = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) leading,
        if (leading != null) const SizedBox(width: 12),
        textColumn,
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
        child: cardBody,
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.heroTag, required this.dense});

  final String url;
  final Object? heroTag;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: AspectRatio(
          aspectRatio: 1.2,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.image_rounded,
              size: dense ? 28 : 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: image);
    }
    return image;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (Color bg, Color fg, String label) = switch (status) {
      BookingStatus.pending => (cs.secondary.withValues(alpha: 0.16), cs.onSecondaryContainer, 'Pending'),
      BookingStatus.confirmed => (cs.primary.withValues(alpha: 0.16), cs.onPrimaryContainer, 'Confirmed'),
      BookingStatus.completed => (cs.tertiary.withValues(alpha: 0.16), cs.onTertiaryContainer, 'Completed'),
      BookingStatus.canceled => (cs.error.withValues(alpha: 0.16), cs.onErrorContainer, 'Canceled'),
      BookingStatus.refunded => (cs.surfaceTint.withValues(alpha: 0.16), cs.onSurface, 'Refunded'),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DatesLine extends StatelessWidget {
  const _DatesLine({required this.start, required this.end, required this.dense});

  final DateTime start;
  final DateTime? end;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final String startStr = _fmtDateTime(start);
    final String endStr = end != null ? _fmtDateTime(end!) : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.event_rounded, size: dense ? 16 : 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            end == null ? startStr : '$startStr  →  $endStr',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  String _fmtDateTime(DateTime dt) {
    // Simple, locale-agnostic short format; map real formatting in caller if needed.
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d, $hh:$mm';
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.priceText,
    required this.code,
    required this.dense,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final String? priceText;
  final String? code;
  final bool dense;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String primaryLabel;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final List<Widget> left = <Widget>[];

    if (priceText != null && priceText!.trim().isNotEmpty) {
      left.add(Text(
        priceText!,
        style: (dense ? t.textTheme.titleSmall : t.textTheme.titleMedium)?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ));
    }

    if (code != null && code!.trim().isNotEmpty) {
      if (left.isNotEmpty) left.add(const SizedBox(width: 8));
      left.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          code!,
          style: t.textTheme.labelSmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            color: cs.onSurfaceVariant,
          ),
        ),
      ));
    }

    final List<Widget> right = <Widget>[];
    if (secondaryLabel != null && onSecondaryAction != null) {
      right.add(OutlinedButton(
        onPressed: onSecondaryAction,
        style: OutlinedButton.styleFrom(visualDensity: dense ? VisualDensity.compact : VisualDensity.standard),
        child: Text(secondaryLabel!),
      ));
      right.add(const SizedBox(width: 8));
    }
    right.add(FilledButton.tonal(
      onPressed: onPrimaryAction,
      style: FilledButton.styleFrom(visualDensity: dense ? VisualDensity.compact : VisualDensity.standard),
      child: Text(primaryLabel),
    ));

    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: left,
          ),
        ),
        Row(children: right),
      ],
    );
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
            color: cs.surfaceVariant.withValues(alpha: 0.9),
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
