// lib/ui/components/buttons/location_button.dart

import 'package:flutter/material.dart';

/// A compact "center on my location" button with locating spinner and M3 variants.
/// Keep this decoupled: call onPressed to trigger GPS recenter in a service/repository.
class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.isLocating = false,
    this.following = false,
    this.tooltip,
    this.size = 24.0,
    this.variant = LocationButtonVariant.filledTonal,
  });

  /// Triggered when the user requests to center on current location.
  final VoidCallback onPressed;

  /// Optional long-press action (e.g., toggle follow mode).
  final VoidCallback? onLongPress;

  /// Show a small spinner overlay to indicate an active locate request.
  final bool isLocating;

  /// If true, renders a higher emphasis style to indicate "follow my location" mode.
  final bool following;

  /// Optional tooltip.
  final String? tooltip;

  /// Icon size in logical pixels.
  final double size;

  /// Visual style using Material 3 IconButton variants.
  final LocationButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final btn = _buildButton(context);

    final wrapped = (tooltip != null && tooltip!.trim().isNotEmpty)
        ? Tooltip(message: tooltip!, child: btn)
        : btn;

    return Semantics(
      button: true,
      label: tooltip ?? (following ? 'Following location' : 'Center on my location'),
      value: isLocating ? 'Locating' : null,
      child: wrapped,
    );
  }

  Widget _buildButton(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Widget baseIcon = Icon(
      following ? Icons.my_location_rounded : Icons.location_searching_rounded,
      size: size,
    );

    final Widget spinner = SizedBox(
      width: size - 8,
      height: size - 8,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          // Wide-gamut safe alpha instead of withOpacity.
          cs.onPrimaryContainer.withValues(alpha: 0.9),
        ),
      ),
    );

    final Widget stackIcon = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        baseIcon,
        if (isLocating)
          // Subtle translucent backdrop to improve spinner legibility.
          Container(
            width: size + 6,
            height: size + 6,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
          ),
        if (isLocating) spinner,
      ],
    );

    final VoidCallback onTap = onPressed;
    final VoidCallback? onLP = onLongPress;

    // Use a higher-emphasis variant when following, else the configured variant.
    final useVariant = following ? LocationButtonVariant.filled : variant;

    switch (useVariant) {
      case LocationButtonVariant.filled:
        return IconButton.filled(
          onPressed: onTap,
          onLongPress: onLP,
          icon: stackIcon,
          isSelected: following,
          selectedIcon: stackIcon,
        );
      case LocationButtonVariant.filledTonal:
        return IconButton.filledTonal(
          onPressed: onTap,
          onLongPress: onLP,
          icon: stackIcon,
          isSelected: following,
          selectedIcon: stackIcon,
        );
      case LocationButtonVariant.outlined:
        return IconButton.outlined(
          onPressed: onTap,
          onLongPress: onLP,
          icon: stackIcon,
          isSelected: following,
          selectedIcon: stackIcon,
        );
      case LocationButtonVariant.standard:
        return IconButton(
          onPressed: onTap,
          onLongPress: onLP,
          icon: stackIcon,
          isSelected: following,
          selectedIcon: stackIcon,
        );
    }
  }
}

enum LocationButtonVariant { standard, filled, filledTonal, outlined }
