// lib/ui/components/maps/mini_map.dart

import 'package:flutter/material.dart';

/// A simple lat/lng model for MiniMap.
@immutable
class MiniMapLatLng {
  const MiniMapLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// A minimal camera model for centering the mini map.
@immutable
class MiniMapCamera {
  const MiniMapCamera({
    required this.target,
    this.zoom = 12,
  });
  final MiniMapLatLng target;
  final double zoom;

  MiniMapCamera copyWith({MiniMapLatLng? target, double? zoom}) =>
      MiniMapCamera(target: target ?? this.target, zoom: zoom ?? this.zoom);
}

/// Signature to embed any map widget inside MiniMap (e.g., GoogleMap/flutter_map).
/// Implementations should:
/// - Render the map bounded to the given size
/// - Center at [camera.target] with [camera.zoom]
/// - Honor [interactive] by disabling gestures when false
typedef MiniMapBuilder = Widget Function(
  BuildContext context,
  MiniMapCamera camera,
  bool interactive,
);

/// A plugin‑agnostic mini map preview card:
/// - Works with any map SDK via [builder]
/// - Rounded M3 card with ripple and “View” CTA
/// - Optional center marker dot
/// - Non‑interactive by default (tap to open full map)
/// - Uses surfaceContainerHighest and Color.withValues (no withOpacity)
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.builder,
    required this.camera,
    this.onTap,
    this.width,
    this.height = 140,
    this.borderRadius = 16,
    this.interactive = false,
    this.showCenterDot = true,
    this.label,
    this.heroTag,
    this.foregroundActions,
  });

  /// Map builder (GoogleMap, flutter_map, etc.).
  final MiniMapBuilder builder;

  /// Initial camera for the preview center/zoom.
  final MiniMapCamera camera;

  /// Tap handler, typically to open a full screen or picker.
  final VoidCallback? onTap;

  /// Size; width defaults to max available if null.
  final double? width;
  final double height;

  /// Corner radius for the card container.
  final double borderRadius;

  /// If true, enables map gestures; else it’s a static preview.
  final bool interactive;

  /// Shows a small center marker dot for clarity.
  final bool showCenterDot;

  /// Optional overlay label (e.g., area name or “Preview”).
  final String? label;

  /// Optional Hero tag to animate the mini map to a larger map.
  final Object? heroTag;

  /// Optional overlay actions (e.g., a small icon button row).
  final List<Widget>? foregroundActions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final map = builder(context, camera, interactive);

    final overlayTop = Positioned(
      left: 8,
      right: 8,
      top: 8,
      child: Row(
        children: <Widget>[
          if (label != null && label!.trim().isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          const Spacer(),
          if (foregroundActions != null && foregroundActions!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: foregroundActions!,
            ),
        ],
      ),
    );

    final overlayBottom = Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Row(
        children: <Widget>[
          if (!interactive && onTap != null)
            FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              label: const Text('View'),
            ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.zoom_in_map_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'z ${camera.zoom.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final centerDot = showCenterDot
        ? IgnorePointer(
            child: Center(
              child: _CenterDot(),
            ),
          )
        : const SizedBox.shrink();

    final child = Stack(
      children: <Widget>[
        // Map fills the card
        Positioned.fill(child: map),
        // Center marker
        Positioned.fill(child: centerDot),
        // Overlays
        overlayTop,
        overlayBottom,
        // Tap cover for non‑interactive preview
        if (!interactive && onTap != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ),
      ],
    );

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: framed,
      ),
    );

    final withHero = heroTag != null ? Hero(tag: heroTag!, child: card) : card;

    return withHero;
  }
}

class _CenterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -1.5),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
