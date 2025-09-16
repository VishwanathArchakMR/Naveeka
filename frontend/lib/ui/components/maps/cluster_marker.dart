// lib/ui/components/maps/cluster_marker.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A compact circular cluster marker widget with an optional tap handler.
/// - Uses theme ColorScheme for consistent M3 visuals
/// - Scales size by count, supports selection emphasis
/// - Suitable for flutter_map (widget markers) or overlay UIs
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    super.key,
    required this.count,
    this.selected = false,
    this.baseColor,
    this.textColor,
    this.compact = false,
    this.onTap,
    this.semanticsLabel,
  });

  /// Number of items inside the cluster.
  final int count;

  /// Emphasis ring when selected/focused.
  final bool selected;

  /// Optional override for the accent color; defaults to ColorScheme.primary.
  final Color? baseColor;

  /// Optional override for label color; defaults to onPrimaryContainer/onSurface.
  final Color? textColor;

  /// Slightly smaller diameters when true.
  final bool compact;

  /// Optional tap handler (useful in flutter_map; google_maps markers are non-widget icons).
  final VoidCallback? onTap;

  /// Optional semantics label override.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color accent = baseColor ?? cs.primary;
    final (double diameter, double fontSize) = _layoutForCount(count, compact: compact);

    final String label = _shortCount(count);

    final Color bg = accent.withValues(alpha: 0.18);
    final Color ring = selected ? accent.withValues(alpha: 0.55) : cs.outlineVariant;
    final Color fg = textColor ?? cs.onPrimaryContainer;

    final marker = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: ring,
          width: selected ? 2 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1.0,
        ),
      ),
    );

    final semantics = Semantics(
      button: onTap != null,
      label: semanticsLabel ?? 'Cluster of $count',
      child: marker,
    );

    if (onTap == null) return semantics;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: semantics,
    );
  }

  (double, double) _layoutForCount(int c, {required bool compact}) {
    if (c < 10) return (compact ? 28 : 32, compact ? 12 : 13);
    if (c < 100) return (compact ? 32 : 36, compact ? 12.5 : 14);
    if (c < 1000) return (compact ? 38 : 44, compact ? 13 : 15);
    return (compact ? 44 : 52, compact ? 13.5 : 16);
  }

  String _shortCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// A fast, dependency‑free Canvas renderer to generate PNG bytes for map SDKs
/// that require bitmap icons (e.g., google_maps_flutter -> BitmapDescriptor.fromBytes).
/// - Matches ClusterMarker’s look and scales by count
/// - Avoids widget-to-image overlays for performance
class ClusterMarkerIcon {
  /// Paints a circular cluster marker to PNG bytes.
  /// Use with google_maps_flutter: BitmapDescriptor.fromBytes(bytes).
  static Future<Uint8List> generatePng({
    required int count,
    double devicePixelRatio = 3.0,
    Color? baseColor,
    Color? textColor,
    bool compact = false,
    bool selected = false,
    ColorScheme? colorScheme,
  }) async {
    // Fallback colors if ColorScheme not provided (use neutral but vivid defaults).
    final ColorScheme cs = colorScheme ??
        const ColorScheme.light(
          primary: Color(0xFF6750A4),
          onPrimaryContainer: Color(0xFF21005D),
          outlineVariant: Color(0xFFCAC4D0),
          surface: Colors.white,
        );

    final Color accent = baseColor ?? cs.primary;
    final (double diameter, double fontSize) = _layoutForCount(count, compact: compact);
    final double dpr = devicePixelRatio.clamp(1.0, 4.0);

    final double sizePx = diameter * dpr;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    final Offset center = Offset(sizePx / 2, sizePx / 2);
    final double radius = sizePx / 2;

    // Background circle (accent-tinted)
    paint.color = (baseColor ?? accent).withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, paint);

    // Soft halo/shadow
    paint
      ..color = accent.withValues(alpha: 0.10)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawCircle(center, radius * 0.9, paint);
    paint.maskFilter = null;

    // Ring (selected thicker)
    paint
      ..color = selected ? accent.withValues(alpha: 0.55) : cs.outlineVariant
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = selected ? (2.0 * dpr) : (1.0 * dpr);
    canvas.drawCircle(center, radius - paint.strokeWidth, paint);

    // Label
    final String label = _shortCount(count);
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontWeight: FontWeight.w800,
        fontSize: fontSize * dpr,
        height: 1.0,
      ),
    )..pushStyle(ui.TextStyle(color: (textColor ?? cs.onPrimaryContainer)));
    pb.addText(label);
    final ui.Paragraph paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: sizePx));
    final double textHeight = paragraph.height;
    canvas.drawParagraph(paragraph, Offset(0, center.dy - textHeight / 2));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(sizePx.toInt(), sizePx.toInt());
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static (double, double) _layoutForCount(int c, {required bool compact}) {
    if (c < 10) return (compact ? 28 : 32, compact ? 12 : 13);
    if (c < 100) return (compact ? 32 : 36, compact ? 12.5 : 14);
    if (c < 1000) return (compact ? 38 : 44, compact ? 13 : 15);
    return (compact ? 44 : 52, compact ? 13.5 : 16);
  }

  static String _shortCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
