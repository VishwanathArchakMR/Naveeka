// lib/ui/components/common/filter_chips.dart

import 'package:flutter/material.dart';

import '../../../models/place.dart';

class AtlasFilterChips extends StatelessWidget {
  final String selectedCategory;
  final String selectedEmotion;
  final String sortBy;
  final Function(String) onCategoryChanged;
  final Function(String) onEmotionChanged;
  final Function(String) onSortChanged;

  const AtlasFilterChips({
    super.key,
    required this.selectedCategory,
    required this.selectedEmotion,
    required this.sortBy,
    required this.onCategoryChanged,
    required this.onEmotionChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chips
        _buildChipSection(
          context,
          title: 'Category',
          children: [
            _buildFilterChip(
              context,
              label: 'All',
              isSelected: selectedCategory == 'all',
              onSelected: () => onCategoryChanged('all'),
            ),
            ...PlaceCategory.values.map((category) {
              return _buildFilterChip(
                context,
                label: category.label,
                isSelected: selectedCategory == category.name,
                onSelected: () => onCategoryChanged(category.name),
              );
            }),
          ],
        ),

        const SizedBox(height: 8),

        // Emotion chips
        _buildChipSection(
          context,
          title: 'Feeling',
          children: [
            _buildFilterChip(
              context,
              label: 'All',
              isSelected: selectedEmotion == 'all',
              onSelected: () => onEmotionChanged('all'),
            ),
            ...EmotionCategory.values.map((emotion) {
              return _buildFilterChip(
                context,
                label: '${emotion.emoji} ${emotion.label}',
                isSelected: selectedEmotion == emotion.name,
                onSelected: () => onEmotionChanged(emotion.name),
              );
            }),
          ],
        ),

        const SizedBox(height: 8),

        // Sort chips
        _buildChipSection(
          context,
          title: 'Sort by',
          children: const [
            _SortChip(label: 'Distance', value: 'distance', icon: Icons.near_me_rounded),
            _SortChip(label: 'Rating', value: 'rating', icon: Icons.star_rounded),
            _SortChip(label: 'Name', value: 'name', icon: Icons.sort_by_alpha_rounded),
            _SortChip(label: 'Featured', value: 'featured', icon: Icons.verified_rounded),
          ],
          isSortSection: true,
        ),
      ],
    );
  }

  Widget _buildChipSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    bool isSortSection = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final child = children[index];
              if (isSortSection && child is _SortChip) {
                return _SortChip(
                  label: child.label,
                  value: child.value,
                  icon: child.icon,
                  isSelected: sortBy == child.value,
                  onSelected: () => onSortChanged(child.value),
                );
              }
              return child;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onSelected;

  const _SortChip({
    required this.label,
    required this.value,
    required this.icon,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected != null ? (_) => onSelected!() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

// Reusable generic filter chips component
class GenericFilterChips extends StatelessWidget {
  final String title;
  final List<FilterChipData> chips;
  final String selectedValue;
  final Function(String) onChanged;

  const GenericFilterChips({
    super.key,
    required this.title,
    required this.chips,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = chips[index];
              final isSelected = selectedValue == chip.value;
              
              return FilterChip(
                label: chip.icon != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            chip.icon,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(chip.label),
                        ],
                      )
                    : Text(chip.label),
                selected: isSelected,
                onSelected: (_) => onChanged(chip.value),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 1.5 : 1,
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FilterChipData {
  final String label;
  final String value;
  final IconData? icon;

  const FilterChipData({
    required this.label,
    required this.value,
    this.icon,
  });
}

// Quick filter options for common use cases
class QuickFilters {
  static const List<FilterChipData> priceRanges = [
    FilterChipData(label: 'Free', value: 'free'),
    FilterChipData(label: 'Under ₹500', value: 'under_500'),
    FilterChipData(label: '₹500-1000', value: '500_1000'),
    FilterChipData(label: 'Above ₹1000', value: 'above_1000'),
  ];

  static const List<FilterChipData> distances = [
    FilterChipData(label: 'Within 1km', value: '1km'),
    FilterChipData(label: 'Within 5km', value: '5km'),
    FilterChipData(label: 'Within 10km', value: '10km'),
    FilterChipData(label: 'Any distance', value: 'any'),
  ];

  static const List<FilterChipData> ratings = [
    FilterChipData(label: '4.5+ stars', value: '4.5+'),
    FilterChipData(label: '4.0+ stars', value: '4.0+'),
    FilterChipData(label: '3.5+ stars', value: '3.5+'),
    FilterChipData(label: 'Any rating', value: 'any'),
  ];

  static const List<FilterChipData> openStatus = [
    FilterChipData(label: 'Open now', value: 'open'),
    FilterChipData(label: 'All places', value: 'all'),
  ];
}
