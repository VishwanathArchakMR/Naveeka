// lib/ui/components/location/gps_indicator.dart

import 'package:flutter/material.dart';

/// High-level GPS/Location fix status derived from signal + accuracy.
enum GpsFixStatus {
  disabled,
  permissionDenied,
  noSignal,
  searching,
  weak,
  good,
  excellent,
}

/// Presentation variant: a compact pill or a small badge overlay.
enum GpsIndicatorVariant { pill, badge }

/// Provider type hint for the fix source.
enum LocationProviderKind { gps, network, fused, unknown }

/// A theme-aware GPS indicator showing fix status, accuracy (± meters),
/// provider, satellite count, and staleness (time since fix).
/// - Uses Material 3 surfaces and tokens
/// - Wide-gamut safe alpha via Color.withValues (no withOpacity)
/// - Can render as a pill (standalone) or a small Badge overlay (for icons)
class GpsIndicator extends StatelessWidget {
  const GpsIndicator({
    super.key,
    required this.status,
    this.accuracyMeters,
    this.lastFixTime,
    this.provider = LocationProviderKind.unknown,
    this.satellites,
    this.variant = GpsIndicatorVariant.pill,
    this.compact = false,
    this.onTap,
    this.tooltip,
  });

  /// Overall status to display (map signal + permissions + accuracy to this).
  final GpsFixStatus status;

  /// Horizontal accuracy radius in meters (Android 68% confidence), optional.
  final double? accuracyMeters;

  /// Timestamp of the last fix; used to show staleness (e.g., "15s ago").
  final DateTime? lastFixTime;

  /// Fix provider hint (GPS / network / fused).
  final LocationProviderKind provider;

  /// Optional satellite count if available (GNSS).
  final int? satellites;

  /// Presentation variant: standalone pill or overlay badge.
  final GpsIndicatorVariant variant;

  /// Denser paddings and icon size.
  final bool compact;

  /// Optional tap handler (e.g., open location settings).
  final VoidCallback? onTap;

  /// Optional tooltip text.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, label, desc) = _contentLines(status, accuracyMeters, lastFixTime, provider, satellites);
    final (bg, fg, border) = _colorsForStatus(cs, status);

    if (variant == GpsIndicatorVariant.badge) {
      // Small badge (e.g., overlay for an icon).
      final dot = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: compact ? 10 : 12, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
      final withSemantics = Semantics(
        label: 'GPS $label${desc == null ? '' : ', $desc'}',
        child: dot,
      );
      final wrapped = (tooltip != null && tooltip!.trim().isNotEmpty)
          ? Tooltip(message: tooltip!, child: withSemantics)
          : withSemantics;
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: wrapped);
    }

    // Pill
    final double padH = compact ? 10 : 12;
    final double padV = compact ? 6 : 8;
    final double iconSize = compact ? 14 : 16;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: iconSize, color: fg),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
            if (desc != null)
              Text(
                desc,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.85)),
              ),
          ],
        ),
      ],
    );

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: content,
    );

    final semantics = Semantics(
      label: 'GPS $label${desc == null ? '' : ', $desc'}',
      button: onTap != null,
      child: pill,
    );

    final wrapped = (tooltip != null && tooltip!.trim().isNotEmpty)
        ? Tooltip(message: tooltip!, child: semantics)
        : semantics;

    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: wrapped);
  }

  // ----------------- helpers -----------------

  (IconData, String, String?) _contentLines(
    GpsFixStatus s,
    double? acc,
    DateTime? time,
    LocationProviderKind p,
    int? sats,
  ) {
    switch (s) {
      case GpsFixStatus.disabled:
        return (Icons.location_disabled_rounded, 'Location off', _desc(time, null, p, null));
      case GpsFixStatus.permissionDenied:
        return (Icons.lock_rounded, 'Permission denied', _desc(time, null, p, null));
      case GpsFixStatus.noSignal:
        return (Icons.portable_wifi_off_rounded, 'No signal', _desc(time, acc, p, sats));
      case GpsFixStatus.searching:
        return (Icons.location_searching_rounded, 'Searching…', _desc(time, acc, p, sats));
      case GpsFixStatus.weak:
        return (Icons.gps_not_fixed_rounded, _labelWithAcc('Weak', acc), _desc(time, acc, p, sats));
      case GpsFixStatus.good:
        return (Icons.gps_fixed_rounded, _labelWithAcc('Good', acc), _desc(time, acc, p, sats));
      case GpsFixStatus.excellent:
        return (Icons.gps_fixed_rounded, _labelWithAcc('Excellent', acc), _desc(time, acc, p, sats));
    }
  }

  String _labelWithAcc(String base, double? acc) {
    if (acc == null) return base;
    final int rounded = acc.round();
    return '$base · ±$rounded m';
  }

  String? _desc(DateTime? time, double? acc, LocationProviderKind p, int? sats) {
    final parts = <String>[];
    if (time != null) {
      parts.add(_agoShort(time));
    }
    // Provider + sats as context
    switch (p) {
      case LocationProviderKind.gps:
        parts.add('GPS');
        break;
      case LocationProviderKind.network:
        parts.add('Network');
        break;
      case LocationProviderKind.fused:
        parts.add('Fused');
        break;
      case LocationProviderKind.unknown:
        break;
    }
    if (sats != null && sats > 0) {
      parts.add('$sats sats');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String _agoShort(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  (Color, Color, Color) _colorsForStatus(ColorScheme cs, GpsFixStatus s) {
    switch (s) {
      case GpsFixStatus.disabled:
        return (cs.surfaceContainerHighest, cs.onSurfaceVariant, cs.outlineVariant);
      case GpsFixStatus.permissionDenied:
        return (cs.error.withValues(alpha: 0.14), cs.onErrorContainer, cs.outlineVariant);
      case GpsFixStatus.noSignal:
        return (cs.surfaceContainerHighest, cs.onSurfaceVariant, cs.outlineVariant);
      case GpsFixStatus.searching:
        return (cs.primary.withValues(alpha: 0.14), cs.onPrimaryContainer, cs.outlineVariant);
      case GpsFixStatus.weak:
        return (cs.tertiary.withValues(alpha: 0.14), cs.onTertiaryContainer, cs.outlineVariant);
      case GpsFixStatus.good:
        return (cs.primary.withValues(alpha: 0.14), cs.onPrimaryContainer, cs.outlineVariant);
      case GpsFixStatus.excellent:
        return (cs.primary.withValues(alpha: 0.18), cs.onPrimaryContainer, cs.outlineVariant);
    }
  }
}
