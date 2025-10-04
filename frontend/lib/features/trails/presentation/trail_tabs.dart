// lib/features/trails/presentation/trail_tabs.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TrailsHomeTab extends StatelessWidget {
  const TrailsHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Stories strip placeholder (replace with real StoriesRow later)
        const SliverToBoxAdapter(
          child: _StoriesStrip(),
        ),
        // Feed list (image-first cards; replace with real feed_card later)
        SliverList.separated(
          itemCount: 8,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _FeedPostCard(index: i),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 72)),
      ],
    );
  }
}

class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 94,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 12,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final isNew = i % 3 == 0;
            return Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isNew
                        ? LinearGradient(colors: [
                            scheme.primary,
                            scheme.tertiary,
                          ])
                        : null,
                    border: isNew
                        ? null
                        : Border.all(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: scheme.surfaceContainerHighest,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.surface.withValues(alpha: 0.0),
                                    scheme.surface.withValues(alpha: 0.45),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Traveler $i',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TrailsExploreTab extends StatefulWidget {
  const TrailsExploreTab({super.key});
  @override
  State<TrailsExploreTab> createState() => _TrailsExploreTabState();
}

class _TrailsExploreTabState extends State<TrailsExploreTab> {
  final _controller = TextEditingController();
  final _categories = const [
    'Nature',
    'Adventure',
    'Spiritual',
    'Heritage',
    'Stay Places',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search + filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search trails, places, hashtags',
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _GlassIconButton(icon: Icons.tune),
            ],
          ),
        ),
        // Category chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return FilterChip(
                label: Text(_categories[i]),
                selected: i == 0,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Featured grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 220,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 20,
            itemBuilder: (context, i) {
              final featured = i < 2;
              return _ExploreCard(featured: featured, index: i);
            },
          ),
        ),
      ],
    );
  }
}

class TrailsCreateTab extends StatelessWidget {
  const TrailsCreateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CreateActionButton(
            icon: Icons.photo_camera,
            label: 'Open Camera',
          ),
          const SizedBox(height: 12),
          const _CreateActionButton(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
          ),
          const SizedBox(height: 16),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Post Options',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OptionChip('Single Photo'),
              _OptionChip('Video'),
              _OptionChip('Carousel'),
              _OptionChip('Location Tag'),
              _OptionChip('Hashtags'),
              _OptionChip('Stickers'),
              _OptionChip('Filters'),
              _OptionChip('Adjust (Crop/Rotate/Brightness)'),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Post'),
            ),
          ),
        ],
      ),
    );
  }
}

class TrailsActivityTab extends StatelessWidget {
  const TrailsActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: 16,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final isLike = i % 3 == 0;
        final isComment = i % 3 == 1;
        final action = isLike
            ? 'liked your trail'
            : isComment
                ? 'commented on your trail'
                : 'started following you';
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Text('${i + 1}'),
            ),
            title: Text('Traveler ${i + 1} $action'),
            subtitle: Text(
              '2h ago • Explore Himalayas',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: scheme.surfaceTint.withValues(alpha: 0.20),
              ),
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}

class TrailsProfileTab extends StatefulWidget {
  const TrailsProfileTab({super.key});
  @override
  State<TrailsProfileTab> createState() => _TrailsProfileTabState();
}

class _TrailsProfileTabState extends State<TrailsProfileTab> {
  bool grid = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: scheme.secondaryContainer,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(title: 'Trails', value: '128'),
                    _Stat(title: 'Followers', value: '4.2k'),
                    _Stat(title: 'Following', value: '312'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Traveler Name',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Explorer • Photographer • Storyteller',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('Edit Profile'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Saved'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Grid'), icon: Icon(Icons.grid_on)),
              ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
            ],
            selected: {grid},
            onSelectionChanged: (sel) => setState(() => grid = sel.first),
          ),
          const SizedBox(height: 12),
          // Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: grid ? _ProfileGrid(scheme: scheme) : _ProfileList(scheme: scheme),
          ),
        ],
      ),
    );
  }
}

// ---- Helpers & Cards ----

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({required this.index});
  final int index;

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  bool liked = false;
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Text('${widget.index + 1}'),
            ),
            title: const Text('Traveler'),
            subtitle: Text(
              'Ladakh, India • 1d',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {},
            ),
          ),
          // Media
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.surfaceContainerHigh,
                    scheme.surfaceContainerHighest,
                  ],
                ),
              ),
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                  color: liked ? scheme.primary : null,
                  onPressed: () => setState(() => liked = !liked),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {},
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                  onPressed: () => setState(() => saved = !saved),
                ),
              ],
            ),
          ),
          // Caption
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Riding through the world’s highest passes — breathtaking views and cold winds!',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.featured, required this.index});
  final bool featured;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.surfaceContainerHigh,
                    scheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      scheme.surface.withValues(alpha: 0.75),
                      scheme.surface.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Text(
                  featured ? 'Featured • Spot ${index + 1}' : 'Trail ${index + 1}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateActionButton extends StatelessWidget {
  const _CreateActionButton({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        alignment: Alignment.centerLeft,
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      onPressed: () {},
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.6),
          child: InkWell(
            onTap: () {},
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 24,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
