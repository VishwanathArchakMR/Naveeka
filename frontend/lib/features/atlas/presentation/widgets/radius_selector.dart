// lib/features/atlas/presentation/widgets/radius_selector.dart

import 'package:flutter/material.dart';

/// A compact inline chip that shows the current radius and opens a
/// modal bottom sheet for adjustment.
class RadiusSelectorChip extends StatelessWidget {
  final double radiusKm;
  final double minKm;
  final double maxKm;
  final int divisions;
  final ValueChanged<double> onRadiusChanged;
  final String labelPrefix;

  const RadiusSelectorChip({
    super.key,
    required this.radiusKm,
    required this.onRadiusChanged,
    this.minKm = 1,
    this.maxKm = 50,
    this.divisions = 49,
    this.labelPrefix = 'Within',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text('$labelPrefix ${radiusKm.toStringAsFixed(0)} km'),
      avatar: const Icon(Icons.near_me_rounded, size: 16),
      selected: true,
      onSelected: (_) async {
        final result = await showRadiusSelectorSheet(
          context: context,
          initialKm: radiusKm.clamp(minKm, maxKm),
          minKm: minKm,
          maxKm: maxKm,
          divisions: divisions,
          title: 'Search radius',
        );
        if (result != null) onRadiusChanged(result);
      },
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
    );
  }
}

/// Opens a bottom sheet radius selector and returns the picked value in km.
/// Returns null if cancelled.
Future<double?> showRadiusSelectorSheet({
  required BuildContext context,
  required double initialKm,
  double minKm = 1,
  double maxKm = 50,
  int divisions = 49,
  String title = 'Radius',
  List<double> presets = const [1, 5, 10, 25, 50],
}) async {
  double temp = initialKm.clamp(minKm, maxKm);

  return showModalBottomSheet<double>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
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

                // Slider (discrete between min..max)
                Slider(
                  value: temp,
                  min: minKm,
                  max: maxKm,
                  divisions: divisions,
                  label: '${temp.toStringAsFixed(0)} km',
                  onChanged: (v) => setState(() => temp = v),
                  activeColor: theme.colorScheme.primary,
                  inactiveColor:
                      theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 8),

                // Preset chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final selected = temp.round() == p.round();
                    return FilterChip(
                      label: Text('${p.toStringAsFixed(0)} km'),
                      selected: selected,
                      onSelected: (_) => setState(() => temp = p),
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
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(temp),
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
