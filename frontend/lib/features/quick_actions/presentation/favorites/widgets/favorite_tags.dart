// lib/features/quick_actions/presentation/favorites/widgets/favorite_tags.dart

import 'package:flutter/material.dart';

/// A compact, accessible tag manager:
/// - Shows tags as FilterChips with selected state
/// - Optional count badges
/// - Add / rename / delete via a bottom-sheet editor
/// - Multi-select with onChanged callback
/// - Uses Color.withValues(...) instead of deprecated withOpacity(...)
class FavoriteTags extends StatefulWidget {
  const FavoriteTags({
    super.key,
    required this.tags, // display names
    this.selected = const <String>{},
    this.counts = const <String, int>{},
    this.onChanged, // void Function(Set<String> next)
    this.onAddTag, // Future<String?> Function()
    this.onRenameTag, // Future<String?> Function(String current)
    this.onDeleteTag, // Future<bool> Function(String tag)
    this.sectionTitle = 'Tags',
    this.compact = false,
  });

  final List<String> tags;
  final Set<String> selected;
  final Map<String, int> counts;

  final void Function(Set<String> next)? onChanged;
  final Future<String?> Function()? onAddTag;
  final Future<String?> Function(String current)? onRenameTag;
  final Future<bool> Function(String tag)? onDeleteTag;

  final String sectionTitle;
  final bool compact;

  @override
  State<FavoriteTags> createState() => _FavoriteTagsState();
}

class _FavoriteTagsState extends State<FavoriteTags> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {...widget.selected};
  }

  @override
  void didUpdateWidget(covariant FavoriteTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _sel = {...widget.selected};
    }
  }

  void _toggle(String tag, bool on) {
    setState(() {
      on ? _sel.add(tag) : _sel.remove(tag);
    });
    widget.onChanged?.call(_sel);
  }

  @override
  Widget build(BuildContext context) {
    final chips = widget.tags.where((t) => t.trim().isNotEmpty).toList(growable: false);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, widget.compact ? 8 : 12, 12, widget.compact ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.sectionTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Add tag',
                  icon: const Icon(Icons.add),
                  onPressed: widget.onAddTag == null ? null : () async {
                    final name = await widget.onAddTag!.call();
                    if (name != null && name.trim().isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added "$name"')),
                      );
                    }
                  },
                ),
              ],
            ),

            // Tag chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((t) {
                final selected = _sel.contains(t);
                final count = widget.counts[t] ?? 0;

                final bg = selected
                    ? cs.primary.withValues(alpha: 0.14)
                    : cs.surfaceContainerHigh.withValues(alpha: 1.0);
                final fg = selected ? cs.primary : cs.onSurface;

                return FilterChip(
                  label: _TagLabel(text: t, count: count, color: fg),
                  selected: selected,
                  onSelected: (on) => _toggle(t, on),
                  backgroundColor: bg,
                  selectedColor: cs.primary.withValues(alpha: 0.18),
                  showCheckmark: false,
                  side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  onSelectedIcon: selected ? const Icon(Icons.check, size: 16) : null,
                  onDeleted: widget.onDeleteTag == null
                      ? null
                      : () async {
                          final ok = await widget.onDeleteTag!.call(t);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted "$t"')),
                            );
                          }
                        },
                  deleteIcon: widget.onDeleteTag == null ? null : const Icon(Icons.close, size: 16),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.text, required this.count, required this.color});
  final String text;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final showCount = count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 6),
          _CountPill(value: count, color: color),
        ],
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.color});
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value > 999 ? '999+' : '$value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
