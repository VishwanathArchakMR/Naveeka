// lib/features/atlas/presentation/widgets/pin_cluster.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

class PinCluster extends StatelessWidget {
  final List<Place> clusteredPlaces;
  final VoidCallback onTap;

  /// A widget representing a cluster of place pins.
  ///
  /// [clusteredPlaces] is the list of places in this cluster.
  /// [onTap] is called when the cluster marker is tapped.
  const PinCluster({
    super.key,
    required this.clusteredPlaces,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = clusteredPlaces.length;
    final displayCount = count > 99 ? '99+' : count.toString();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          displayCount,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}
