// lib/features/atlas/presentation/widgets/map_controls.dart

import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          icon: Icons.add_rounded,
          label: 'Zoom In',
          onTap: onZoomIn,
          color: theme.colorScheme.surface,
          iconColor: theme.colorScheme.onSurface,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.remove_rounded,
          label: 'Zoom Out',
          onTap: onZoomOut,
          color: theme.colorScheme.surface,
          iconColor: theme.colorScheme.onSurface,
        ),
        const SizedBox(height: 16),
        _ControlButton(
          icon: Icons.my_location_rounded,
          label: 'My Location',
          onTap: onMyLocation,
          color: theme.colorScheme.primary,
          iconColor: theme.colorScheme.onPrimary,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
