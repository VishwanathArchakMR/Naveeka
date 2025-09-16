// lib/features/places/presentation/widgets/category_description.dart

import 'package:flutter/material.dart';

class CategoryDescription extends StatefulWidget {
  const CategoryDescription({
    super.key,
    required this.title,
    required this.description,
    this.maxPreviewLines = 3,
    this.highlights = const <String>[], // bullet items
    this.chips = const <String>[], // category tags
    this.showTitle = true,
  });

  final String title;
  final String description;
  final int maxPreviewLines;
  final List<String> highlights;
  final List<String> chips;
  final bool showTitle;

  @override
  State<CategoryDescription> createState() => _CategoryDescriptionState();
}

class _CategoryDescriptionState extends State<CategoryDescription> with TickerProviderStateMixin {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = widget.description.trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),

            // Description with animated expand/collapse
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SelectionArea(
                child: Text(
                  desc,
                  maxLines: _expanded ? null : widget.maxPreviewLines,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ), // AnimatedSize automatically animates height changes when toggling between truncated and full text for a smooth transition. [12][6]

            // Show more / less
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _toggle,
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Show less' : 'Show more'),
              ),
            ),

            // Highlights (bulleted)
            if (widget.highlights.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...widget.highlights.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: SelectionArea(child: Text(h))),
                      ],
                    ),
                  )),
            ],

            // Chips row
            if (widget.chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.chips
                    .map((c) => Chip(
                          label: Text(c),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alternate: ExpansionTile-based version for list contexts.
/// Useful when descriptions belong to multiple categories in a vertical list.
class CategoryDescriptionTile extends StatelessWidget {
  const CategoryDescriptionTile({
    super.key,
    required this.title,
    required this.description,
    this.highlights = const <String>[],
    this.chips = const <String>[],
    this.leading,
    this.initiallyExpanded = false,
  });

  final String title;
  final String description;
  final List<String> highlights;
  final List<String> chips;
  final Widget? leading;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: leading ?? const Icon(Icons.category_outlined),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        SelectionArea(child: Text(description.trim(), style: const TextStyle(height: 1.35))),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...highlights.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: SelectionArea(child: Text(h))),
                  ],
                ),
              )),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((c) => Chip(label: Text(c))).toList(growable: false),
          ),
        ],
      ],
    ); // ExpansionTile provides a simple expand/collapse row pattern with built‑in affordance and animated height for nested content. [1][2]
  }
}
