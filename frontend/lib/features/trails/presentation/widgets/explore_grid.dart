// lib/features/trails/presentation/widgets/explore_grid.dart

import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

@immutable
class ExploreItem {
  const ExploreItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.category,
    this.featured = false,
    this.isVideo = false,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle; // e.g., location
  final String? category;
  final bool featured;
  final bool isVideo;
}

class ExploreGrid extends StatefulWidget {
  const ExploreGrid({
    super.key,
    required this.items,
    required this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.onSearch,
    this.onOpen,
    this.onLoadMore,
    this.hasMore = false,
    this.initialQuery = '',
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 24),
  });

  final List<ExploreItem> items;
  final List<String> categories;
  final String? selectedCategory;

  final ValueChanged<String>? onCategorySelected;
  final ValueChanged<String>? onSearch;
  final ValueChanged<ExploreItem>? onOpen;

  final Future<void> Function()? onLoadMore;
  final bool hasMore;

  final String initialQuery;
  final EdgeInsets padding;

  @override
  State<ExploreGrid> createState() => _ExploreGridState();
}

class _ExploreGridState extends State<ExploreGrid> {
  late final TextEditingController _search;
  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant ExploreGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasMore && _loadingMore) {
      _loadingMore = false;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() async {
    if (widget.onLoadMore == null || !widget.hasMore || _loadingMore) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      setState(() => _loadingMore = true);
      try {
        await widget.onLoadMore!.call();
      } finally {
        if (mounted) setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1000
        ? 4
        : width >= 700
            ? 3
            : 2;

    final featured = widget.items.where((e) => e.featured).take(3).toList();
    final regular = widget.items.where((e) => !e.featured).toList();

    return Column(
      children: [
        // Search + filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: widget.onSearch,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search trails, places, hashtags',
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GlassIconButton(
                icon: Icons.tune,
                onTap: () => widget.onSearch?.call(_search.text.trim()),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = widget.categories[i];
              final selected = widget.selectedCategory == cat || (widget.selectedCategory == null && i == 0);
              return FilterChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => widget.onCategorySelected?.call(cat),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Grid + featured
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              if (featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 0.9),
                      itemCount: featured.length,
                      itemBuilder: (context, i) {
                        final it = featured[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == featured.length - 1 ? 0 : 8,
                          ),
                          child: _FeaturedCard(
                            item: it,
                            onOpen: widget.onOpen,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (featured.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  widget.padding.left,
                  8,
                  widget.padding.right,
                  widget.padding.bottom,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final it = regular[i];
                      return _ExploreTile(
                        item: it,
                        onOpen: widget.onOpen,
                      );
                    },
                    childCount: regular.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: widget.hasMore || _loadingMore
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const SizedBox(key: ValueKey('spacer'), height: 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExploreTile extends StatefulWidget {
  const _ExploreTile({required this.item, this.onOpen});
  final ExploreItem item;
  final ValueChanged<ExploreItem>? onOpen;

  @override
  State<_ExploreTile> createState() => _ExploreTileState();
}

class _ExploreTileState extends State<_ExploreTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => widget.onOpen?.call(widget.item),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (ctx, _) => Container(color: cs.surfaceContainerHigh.withValues(alpha: 1.0)),
                errorWidget: (ctx, u, e) => Container(
                  color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                ),
              ),
              // Legibility gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.6, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.50),
                        Colors.black.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Frosted polish
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                  child: const SizedBox.expand(),
                ),
              ),
              // Labels
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((widget.item.category ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.item.category!,
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                    if ((widget.item.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onInverseSurface, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.item.isVideo)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: _Badge(icon: Icons.play_arrow_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, this.onOpen});
  final ExploreItem item;
  final ValueChanged<ExploreItem>? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onOpen?.call(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              placeholder: (ctx, _) => Container(color: cs.surfaceContainerHigh.withValues(alpha: 1.0)),
              errorWidget: (ctx, u, e) => Container(
                color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.5, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                  if ((item.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
                    ),
                  ],
                ],
              ),
            ),
            if (item.isVideo)
              const Positioned(
                right: 10,
                top: 10,
                child: _Badge(icon: Icons.play_arrow_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: cs.surface.withValues(alpha: 0.6),
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.tune),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
