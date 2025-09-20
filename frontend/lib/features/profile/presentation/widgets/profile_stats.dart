// lib/features/profile/presentation/widgets/profile_stats.dart

import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({
    super.key,
    this.places = 0,
    this.reviews = 0,
    this.photos = 0,
    this.followers = 0,
    this.following = 0,
    this.journeys = 0,
    this.onTapPlaces,
    this.onTapReviews,
    this.onTapPhotos,
    this.onTapFollowers,
    this.onTapFollowing,
    this.onTapJourneys,
    this.showBadges = false,
    this.sectionTitle = 'Stats',
    this.tooltips = true,
    this.progressLabel,
    this.progressValue, // 0..1 for a simple progress under the grid (e.g., profile completeness)
  });

  final int places;
  final int reviews;
  final int photos;
  final int followers;
  final int following;
  final int journeys;

  final VoidCallback? onTapPlaces;
  final VoidCallback? onTapReviews;
  final VoidCallback? onTapPhotos;
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapJourneys;

  final bool showBadges;
  final String sectionTitle;
  final bool tooltips;

  final String? progressLabel;
  final double? progressValue;

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTile>[
      _StatTile(
        icon: Icons.place_outlined,
        label: 'Places',
        value: places,
        onTap: onTapPlaces,
      ),
      _StatTile(
        icon: Icons.reviews_outlined,
        label: 'Reviews',
        value: reviews,
        onTap: onTapReviews,
      ),
      _StatTile(
        icon: Icons.photo_library_outlined,
        label: 'Photos',
        value: photos,
        onTap: onTapPhotos,
      ),
      _StatTile(
        icon: Icons.groups_outlined,
        label: 'Followers',
        value: followers,
        onTap: onTapFollowers,
      ),
      _StatTile(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Following',
        value: following,
        onTap: onTapFollowing,
      ),
      _StatTile(
        icon: Icons.map_outlined,
        label: 'Journeys',
        value: journeys,
        onTap: onTapJourneys,
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (showBadges) _BadgesRow(places: places, reviews: reviews, photos: photos),
              ],
            ),

            const SizedBox(height: 8),

            // Responsive grid (2 on phones, 3+ on wider screens)
            LayoutBuilder(
              builder: (context, c) {
                final width = c.maxWidth;
                final cross = width >= 900 ? 3 : (width >= 540 ? 3 : 2);
                return GridView.count(
                  crossAxisCount: cross,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.1, // wide pill-like tiles
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: tiles.map((t) {
                    final child = _TilePill(
                      icon: t.icon,
                      label: t.label,
                      value: t.value,
                      onTap: t.onTap,
                    );
                    return tooltips ? Tooltip(message: t.label, child: child) : child;
                  }).toList(growable: false),
                );
              },
            ), // GridView.count is a simple way to layout a fixed # of columns responsively with spacing and aspect ratio control. [1][2]

            if (progressValue != null) ...[
              const SizedBox(height: 12),
              _ProgressRow(label: progressLabel ?? 'Profile completeness', value: progressValue!.clamp(0.0, 1.0)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile {
  _StatTile({required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;
}

class _TilePill extends StatelessWidget {
  const _TilePill({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({required this.places, required this.reviews, required this.photos});
  final int places;
  final int reviews;
  final int photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        if (places >= 10) const Chip(avatar: Icon(Icons.verified_outlined, size: 16), label: Text('Explorer'), visualDensity: VisualDensity.compact),
        if (reviews >= 20) const Chip(avatar: Icon(Icons.rate_review_outlined, size: 16), label: Text('Critic'), visualDensity: VisualDensity.compact),
        if (photos >= 50) const Chip(avatar: Icon(Icons.photo_camera_outlined, size: 16), label: Text('Photographer'), visualDensity: VisualDensity.compact),
      ],
    ); // Chip is ideal for compact badges/achievements; visualDensity controls compactness per Material Chip guidance. [10][13]
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: value, minHeight: 8),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
