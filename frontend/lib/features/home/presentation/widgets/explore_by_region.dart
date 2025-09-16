// lib/features/home/presentation/widgets/explore_by_region.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/route_names.dart';

class ExploreByRegionSection extends StatelessWidget {
  final List<Map<String, dynamic>> regions;
  const ExploreByRegionSection({
    super.key,
    required this.regions,
  });

  @override
  Widget build(BuildContext context) {
    if (regions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Explore by Region',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: regions.length,
            itemBuilder: (context, index) {
              final region = regions[index];
              final name = region['name'] as String? ?? 'Unknown';
              final image = region['image'] as String? ?? '';
              final id = region['id'] as String? ?? '';
              return _RegionCard(
                name: name,
                imageAsset: image,
                onTap: () {
                  context.pushNamed(
                    RouteNames.atlas,
                    queryParameters: {'region': id},
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RegionCard extends StatelessWidget {
  final String name;
  final String imageAsset;
  final VoidCallback onTap;
  const _RegionCard({
    required this.name,
    required this.imageAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background image
              SizedBox(
                width: 120,
                height: 140,
                child: imageAsset.isNotEmpty
                    ? Image.asset(
                        imageAsset,
                        fit: BoxFit.cover,
                      )
                    : Container(color: Theme.of(context).colorScheme.surface),
              ),
              // Dark overlay
              Container(
                width: 120,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
              // Region name
              Positioned(
                left: 8,
                bottom: 8,
                right: 8,
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
