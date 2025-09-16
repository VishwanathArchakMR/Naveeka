// lib/ui/components/common/category_chips.dart

import 'package:flutter/material.dart';

/// Lightweight view data for a category chip.
/// Keep UI-only here; map domain enums/ids externally.
class CategoryChipData {
  const CategoryChipData({
    required this.id,
    required this.label,
    this.icon,
    this.count,
    this.selected = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final bool enabled;

  CategoryChipData copyWith({
    String? id,
    String? label,
    IconData? icon,
    int? count,
    bool? selected,
    bool? enabled,
  }) {
    return CategoryChipData(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      count: count ?? this.count,
      selected: selected ?? this.selected,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// A configurable chips row supporting single (ChoiceChip) or multi (FilterChip) select.
/// - Uses Material 3 chips and theming
/// - Wide-gamut safe: Color.withValues for alpha (no withOpacity)
/// - Replaces surfaceVariant with surfaceContainerHighest for neutral surfaces
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.items,
    required this.onChanged,
    this.multiSelect = false,
    this.dense = false,
    this.scrollable = true,
    this.wrap = false,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  }) : assert(scrollable || wrap, 'Either scrollable or wrap should be true');

  /// Chips to render (selected field is respected).
  final List<CategoryChipData> items;

  /// Selection change callback:
  /// - For single select: returns the newly selected item id (or null if deselected)
  /// - For multi select: returns the list of selected ids
  final void Function(dynamic selection) onChanged;

  /// Multi-select uses FilterChip; single-select uses ChoiceChip.
  final bool multiSelect;

  /// Denser layout if true.
  final bool dense;

  /// If true, lays out chips in a horizontal scroll row.
  final bool scrollable;

  /// If true, wraps chips into lines (ignored if scrollable = true).
  final bool wrap;

  /// Spacing between chips.
  final double spacing;

  /// Wrap run spacing (vertical).
  final double runSpacing;

  /// Outer padding for the entire chips row/wrap.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final kids = items.map((e) => _buildChip(context, e)).toList(growable: false);

    final content = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Row(
              children: _spaced(kids, spacing),
            ),
          )
        : Padding(
            padding: padding,
            child: wrap
                ? Wrap(
                    spacing: spacing,
                    runSpacing: runSpacing,
                    children: kids,
                  )
                : Row(
                    children: _spaced(kids, spacing),
                  ),
          );

    return content;
  }

  List<Widget> _spaced(List<Widget> children, double spacing) {
    if (children.isEmpty) return const <Widget>[];
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(SizedBox(width: spacing));
    }
    return out;
  }

  Widget _buildChip(BuildContext context, CategoryChipData data) {
    final cs = Theme.of(context).colorScheme;

    // Compute foreground/background based on selection and enabled.
    final bool selected = data.selected && data.enabled;
    final Color bg = selected
        ? cs.primary.withValues(alpha: 0.16)
        : cs.surfaceContainerHighest; // modern neutral container
    final Color fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    final Widget label = _ChipLabel(
      text: data.label,
      count: data.count,
      dense: dense,
      color: fg,
      icon: data.icon,
    );

    if (multiSelect) {
      // FilterChip for multi-select (Material 3).
      return FilterChip(
        selected: selected,
        onSelected: data.enabled
            ? (v) {
                final nextIds = <String>[];
                for (final it in items) {
                  final isThis = it.id == data.id;
                  final sel = isThis ? v : (it.selected && it.enabled);
                  if (sel) nextIds.add(it.id);
                }
                onChanged(nextIds);
              }
            : null,
        label: label,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        backgroundColor: bg,
        selectedColor: cs.primary.withValues(alpha: 0.20),
        disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.70),
        shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
        side: BorderSide(color: cs.outlineVariant),
        showCheckmark: false,
      );
    } else {
      // ChoiceChip for single-select (Material 3).
      return ChoiceChip(
        selected: selected,
        onSelected: data.enabled
            ? (v) {
                onChanged(v ? data.id : null);
              }
            : null,
        label: label,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        backgroundColor: bg,
        selectedColor: cs.primary.withValues(alpha: 0.20),
        disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.70),
        shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
        side: BorderSide(color: cs.outlineVariant),
      );
    }
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.text,
    required this.count,
    required this.dense,
    required this.color,
    required this.icon,
  });

  final String text;
  final int? count;
  final bool dense;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: dense ? 12 : 13,
        );

    final children = <Widget>[];
    if (icon != null) {
      children.add(Icon(icon, size: dense ? 16 : 18, color: color));
      children.add(SizedBox(width: dense ? 6 : 8));
    }
    children.add(Text(text, style: style));
    if (count != null && count! > 0) {
      children.add(SizedBox(width: dense ? 6 : 8));
      children.add(_CountBadge(value: count!, color: color, dense: dense));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value, required this.color, required this.dense});

  final int value;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color.withValues(alpha: 0.12); // wide‑gamut safe
    final text = value > 999 ? '999+' : '$value';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
