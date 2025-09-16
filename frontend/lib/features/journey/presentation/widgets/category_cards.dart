// lib/features/journey/presentation/widgets/category_cards.dart

import 'package:flutter/material.dart';

/// A compact, tappable category tile used on discovery/home screens.
/// Use with CategoryCards to render a grid or horizontal list of categories.
class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.assetIconPath,
    this.color,
    this.onTap,
    this.badge,
    this.heroTag,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// Optional Material icon (preferred for consistency across platform themes).
  final IconData? icon;

  /// Alternatively, provide an asset path for custom icons (e.g., PNG/SVG via a wrapper).
  final String? assetIconPath;

  /// Optional tile color. Falls back to theme card color if null.
  final Color? color;

  /// Optional action on tap.
  final VoidCallback? onTap;

  /// Optional small badge text (e.g., "New", "Sale").
  final String? badge;

  /// Optional Hero tag to support smooth transitions into destination screens.
  final String? heroTag;
}

/// Layout variants for CategoryCards.
enum CategoryCardsLayout { grid, horizontal }

/// Renders a collection of [CategoryItem]s as a grid or a horizontally scrollable row.
/// - Grid uses GridView.builder with a fixed crossAxisCount and adaptive tile sizing.
/// - Horizontal uses a SingleChildScrollView + Row for lightweight, compact lists.
class CategoryCards extends StatelessWidget {
  const CategoryCards({
    super.key,
    required this.items,
    this.layout = CategoryCardsLayout.grid,
    this.crossAxisCount = 2,
    this.tileAspectRatio = 1.6,
    this.horizontalHeight = 120,
    this.gap = 12,
    this.semanticLabel,
  });

  final List<CategoryItem> items;

  final CategoryCardsLayout layout;

  /// Grid-only: columns per row.
  final int crossAxisCount;

  /// Grid-only: width/height ratio of each tile.
  final double tileAspectRatio;

  /// Horizontal-only: fixed tile height.
  final double horizontalHeight;

  /// Spacing between tiles.
  final double gap;

  /// Optional semantic label for screen readers on the container.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: semanticLabel,
      child: layout == CategoryCardsLayout.grid
          ? _Grid(
              items: items,
              crossAxisCount: crossAxisCount,
              tileAspectRatio: tileAspectRatio,
              gap: gap,
            )
          : _Horizontal(
              items: items,
              height: horizontalHeight,
              gap: gap,
            ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.items,
    required this.crossAxisCount,
    required this.tileAspectRatio,
    required this.gap,
  });

  final List<CategoryItem> items;
  final int crossAxisCount;
  final double tileAspectRatio;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: tileAspectRatio,
      ),
      itemBuilder: (context, i) {
        final it = items[i];
        return _CategoryTile(item: it);
      },
    );
  }
}

class _Horizontal extends StatelessWidget {
  const _Horizontal({
    required this.items,
    required this.height,
    required this.gap,
  });

  final List<CategoryItem> items;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: (context, i) {
          final it = items[i];
          return SizedBox(
            width: height * 1.6,
            child: _CategoryTile(item: it),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item});
  final CategoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = item.color ?? theme.colorScheme.surfaceContainerHighest;

    final content = _TileContent(item: item, bg: bg);

    // Hero (optional) wraps the tile to support smooth transitions if heroTag is provided.
    final tile = item.heroTag == null
        ? content
        : Hero(tag: item.heroTag!, child: Material(type: MaterialType.transparency, child: content));

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures ripple and child content clip to rounded card shape. [1]
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // InkWell is the Material tappable surface with splash/hover effects. [12]
        onTap: item.onTap,
        child: tile,
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({required this.item, required this.bg});

  final CategoryItem item;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final iconColor = _bestOn(bg);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        gradient: LinearGradient(
          colors: [bg, bg.withOpacity(0.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          // Icon / Asset
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: _buildIcon(iconColor),
          ),
          const SizedBox(width: 12),
          // Title + subtitle + badge
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.badge != null && item.badge!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge!.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (item.badge != null && item.badge!.isNotEmpty) const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
        ],
      ),
    );
  }

  Widget _buildIcon(Color iconColor) {
    if (item.icon != null) {
      return Icon(item.icon, size: 26, color: iconColor);
    }
    if (item.assetIconPath != null && item.assetIconPath!.isNotEmpty) {
      // Replace with your Image.asset or custom SVG widget if integrated.
      return Image.asset(item.assetIconPath!, width: 26, height: 26, color: iconColor);
    }
    return const Icon(Icons.apps, size: 26);
  }

  Color _bestOn(Color bg) {
    // Simple luminance-based contrast for icon/fg.
    return bg.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
  }
}
