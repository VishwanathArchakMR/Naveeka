// lib/ui/components/location/distance_badge.dart

import 'package:flutter/material.dart';

/// Preferred units selection.
enum UnitsPref { auto, metric, imperial }

/// Optional travel mode icon to pair with the distance.
enum TravelMode { walking, driving, bicycling, transit }

/// High-level color style for the badge.
enum DistanceBadgeStyle { neutral, primary, success, error }

/// A compact, theme-aware badge for displaying distance, with optional icon and
/// metric/imperial formatting.
/// - Uses Material 3 surfaces (surfaceContainerHighest) and withValues for alpha
/// - Pure UI: no dependencies; wire navigation or launchers at call site
class DistanceBadge extends StatelessWidget {
  const DistanceBadge({
    super.key,
    required this.meters,
    this.units = UnitsPref.auto,
    this.compact = false,
    this.mode,
    this.style = DistanceBadgeStyle.neutral,
    this.showIcon = true,
    this.precisionKm = 1,
    this.precisionMi = 1,
    this.tooltip,
  });

  /// Distance in meters (double for precision).
  final double meters;

  /// Units preference: auto (locale-based), metric, or imperial.
  final UnitsPref units;

  /// Denser paddings and icon size.
  final bool compact;

  /// Optional travel mode to show an appropriate icon.
  final TravelMode? mode;

  /// Visual style for background/foreground colors.
  final DistanceBadgeStyle style;

  /// If false, hides the leading icon.
  final bool showIcon;

  /// Fractional digits for kilometers display.
  final int precisionKm;

  /// Fractional digits for miles display.
  final int precisionMi;

  /// Optional tooltip for accessibility hints.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bool useImperial = _resolveImperial(units, Localizations.localeOf(context).countryCode);
    final String text = _formatDistance(meters, useImperial, precisionKm: precisionKm, precisionMi: precisionMi);

    final (Color bg, Color fg, Color border) = _colorsForStyle(cs, style);

    final double padH = compact ? 8 : 10;
    final double padV = compact ? 3 : 5;
    final double iconSize = compact ? 14 : 16;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showIcon) ...<Widget>[
          Icon(_iconForMode(mode), size: iconSize, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );

    final Widget pill = Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: content,
    );

    final semantics = Semantics(
      label: 'Distance $text',
      child: pill,
    );

    if (tooltip != null && tooltip!.trim().isNotEmpty) {
      return Tooltip(message: tooltip!, child: semantics);
    }
    return semantics;
  }

  // ----------------- helpers -----------------

  bool _resolveImperial(UnitsPref pref, String? countryCode) {
    if (pref == UnitsPref.metric) return false;
    if (pref == UnitsPref.imperial) return true;
    // Auto: fall back to imperial for US, Liberia, Myanmar; otherwise metric.
    switch ((countryCode ?? '').toUpperCase()) {
      case 'US':
      case 'LR':
      case 'MM':
        return true;
      default:
        return false;
    }
  }

  String _formatDistance(
    double m,
    bool imperial, {
    required int precisionKm,
    required int precisionMi,
  }) {
    if (!imperial) {
      // show meters under 1000, else km
      if (m < 1000) {
        final int metersRounded = m.round();
        return '$metersRounded m';
      }
      final double km = m / 1000.0;
      return '${km.toStringAsFixed(precisionKm)} km';
    } else {
      // imperial: feet for short distances, else miles
      final double feet = m * 3.28084; // 1 m = 3.28084 ft
      if (feet < 1000) {
        final int ftRounded = feet.round();
        return '$ftRounded ft';
      }
      final double miles = m / 1609.34; // 1 mi = 1609.34 m
      return '${miles.toStringAsFixed(precisionMi)} mi';
    }
  }

  IconData _iconForMode(TravelMode? mode) {
    switch (mode) {
      case TravelMode.walking:
        return Icons.directions_walk_rounded;
      case TravelMode.driving:
        return Icons.directions_car_rounded;
      case TravelMode.bicycling:
        return Icons.directions_bike_rounded;
      case TravelMode.transit:
        return Icons.directions_transit_rounded;
      case null:
        return Icons.place_rounded;
    }
  }

  (Color, Color, Color) _colorsForStyle(ColorScheme cs, DistanceBadgeStyle s) {
    switch (s) {
      case DistanceBadgeStyle.neutral:
        return (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          cs.outlineVariant,
        );
      case DistanceBadgeStyle.primary:
        return (
          cs.primary.withValues(alpha: 0.14),
          cs.onPrimaryContainer,
          cs.outlineVariant,
        );
      case DistanceBadgeStyle.success:
        return (
          cs.tertiary.withValues(alpha: 0.14),
          cs.onTertiaryContainer,
          cs.outlineVariant,
        );
      case DistanceBadgeStyle.error:
        return (
          cs.error.withValues(alpha: 0.14),
          cs.onErrorContainer,
          cs.outlineVariant,
        );
    }
  }
}
