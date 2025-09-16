// lib/features/atlas/presentation/widgets/location_filters.dart

import 'package:flutter/material.dart';

enum PriceFilter {
  any,
  free,
  under500,
  between500_1000,
  above1000,
}

enum RatingFilter {
  any,
  gte3_5,
  gte4_0,
  gte4_5,
}

class LocationFilters extends StatelessWidget {
  final double radiusKm;
  final bool openNow;
  final PriceFilter price;
  final RatingFilter rating;

  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onOpenNowChanged;
  final ValueChanged<PriceFilter> onPriceChanged;
  final ValueChanged<RatingFilter> onRatingChanged;
  final VoidCallback? onClearAll;

  const LocationFilters({
    super.key,
    required this.radiusKm,
    required this.openNow,
    required this.price,
    required this.rating,
    required this.onRadiusChanged,
    required this.onOpenNowChanged,
    required this.onPriceChanged,
    required this.onRatingChanged,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Location Filters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onClearAll != null)
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Row 1: Open now + Radius
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Open now
              FilterChip(
                label: const Text('Open now'),
                avatar: const Icon(Icons.schedule_rounded, size: 16),
                selected: openNow,
                onSelected: (v) => onOpenNowChanged(v),
                backgroundColor: theme.colorScheme.surface,
                selectedColor: theme.colorScheme.primaryContainer,
                side: BorderSide(
                  color: openNow
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: openNow ? 1.5 : 1,
                ),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: openNow
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: openNow ? FontWeight.w600 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              const SizedBox(width: 8),

              // Radius (sheet + Slider)
              FilterChip(
                label: Text('Within ${radiusKm.toStringAsFixed(0)} km'),
                avatar: const Icon(Icons.near_me_rounded, size: 16),
                selected: true,
                onSelected: (_) => _showRadiusSheet(context),
                backgroundColor: theme.colorScheme.surface,
                selectedColor: theme.colorScheme.primaryContainer,
                side: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Row 2: Price segmented
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<PriceFilter>(
            segments: const <ButtonSegment<PriceFilter>>[
              ButtonSegment(
                value: PriceFilter.any,
                label: Text('Any'),
                icon: Icon(Icons.filter_alt_outlined, size: 16),
              ),
              ButtonSegment(
                value: PriceFilter.free,
                label: Text('Free'),
                icon: Icon(Icons.currency_rupee_rounded, size: 16),
              ),
              ButtonSegment(
                value: PriceFilter.under500,
                label: Text('< ₹500'),
              ),
              ButtonSegment(
                value: PriceFilter.between500_1000,
                label: Text('₹500–1000'),
              ),
              ButtonSegment(
                value: PriceFilter.above1000,
                label: Text('> ₹1000'),
              ),
            ],
            selected: {price},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onPriceChanged(set.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Row 3: Rating segmented
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<RatingFilter>(
            segments: const <ButtonSegment<RatingFilter>>[
              ButtonSegment(
                value: RatingFilter.any,
                label: Text('Any'),
                icon: Icon(Icons.star_border_rounded, size: 16),
              ),
              ButtonSegment(
                value: RatingFilter.gte3_5,
                label: Text('3.5+'),
              ),
              ButtonSegment(
                value: RatingFilter.gte4_0,
                label: Text('4.0+'),
              ),
              ButtonSegment(
                value: RatingFilter.gte4_5,
                label: Text('4.5+'),
              ),
            ],
            selected: {rating},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onRatingChanged(set.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRadiusSheet(BuildContext context) {
    final theme = Theme.of(context);
    double temp = radiusKm.clamp(1, 50);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Search radius',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${temp.toStringAsFixed(0)} km',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Slider (1–50km)
                  Slider(
                    value: temp,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${temp.toStringAsFixed(0)} km',
                    onChanged: (v) => setState(() => temp = v),
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),

                  // Presets
                  Row(
                    children: [
                      _PresetChip(
                        label: '1 km',
                        selected: temp.round() == 1,
                        onTap: () => setState(() => temp = 1),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '5 km',
                        selected: temp.round() == 5,
                        onTap: () => setState(() => temp = 5),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '10 km',
                        selected: temp.round() == 10,
                        onTap: () => setState(() => temp = 10),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '25 km',
                        selected: temp.round() == 25,
                        onTap: () => setState(() => temp = 25),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '50 km',
                        selected: temp.round() == 50,
                        onTap: () => setState(() => temp = 50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            onRadiusChanged(temp);
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primaryContainer,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.3),
        width: selected ? 1.5 : 1,
      ),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
