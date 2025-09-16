// lib/ui/components/maps/place_marker.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Visual variants for the place marker.
enum PlaceMarkerStyle { primary, neutral, warning, danger }

/// A compact place marker widget suitable for widget-based map layers (e.g., flutter_map).
/// - Rounded pin with an accent fill and subtle halo
/// - Optional emoji/icon and label
/// - Tappable with Ink ripple when onTap provided
/// - Colors derived from ColorScheme; alpha via withValues (wide-gamut safe)
class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    super.key,
    this.icon,
    this.emoji,
    this.label,
    this.selected = false,
    this.compact = false,
    this.style = PlaceMarkerStyle.primary,
    this.onTap,
    this.semanticsLabel,
  });

  /// Optional Material icon rendered centered in the pin.
  final IconData? icon;

  /// Optional emoji string; if provided, takes precedence over icon.
  final String? emoji;

  /// Optional short label under the pin.
  final String? label;

  /// Selected adds a stronger ring and larger halo.
  final bool selected;

  /// Slightly smaller pin when compact.
  final bool compact;

  /// Color style for the pin.
  final PlaceMarkerStyle style;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Optional semantics label override.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color fill, Color ring, Color fg, Color border) = _colors(cs, style, selected);

    final (double pinW, double pinH, double halo) = compact
        ? (26.0, 32.0, selected ? 16.0 : 12.0)
        : (30.0, 38.0, selected ? 18.0 : 14.0);

    final Widget glyph = emoji != null && emoji!.isNotEmpty
        ? Text(
            emoji!,
            style: TextStyle(fontSize: compact ? 13 : 15, height: 1.0),
          )
        : Icon(icon ?? Icons.place_rounded, size: compact ? 14 : 16, color: fg);

    final Widget pin = SizedBox(
      width: pinW,
      height: pinH,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Halo
          Container(
            width: pinW + halo,
            height: pinW + halo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill.withValues(alpha: 0.18),
              border: Border.all(color: border),
            ),
          ),
          // Pin body (rounded drop shape approximated by a circle + pointer)
          CustomPaint(
            size: Size(pinW, pinH),
            painter: _PinPainter(fill: fill, ring: ring, selected: selected),
          ),
          // Glyph
          Positioned(
            top: pinH * 0.22,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontWeight: FontWeight.w800),
              child: IconTheme(
                data: IconThemeData(color: fg),
                child: glyph,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        pin,
        if (label != null && label!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
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
        ],
      ],
    );

    final Widget semantics = Semantics(
      label: semanticsLabel ?? 'Place marker${label == null ? '' : ' $label'}',
      button: onTap != null,
      child: column,
    );

    if (onTap == null) return semantics;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: semantics,
      ),
    );
  }

  (Color, Color, Color, Color) _colors(ColorScheme cs, PlaceMarkerStyle s, bool selected) {
    switch (s) {
      case PlaceMarkerStyle.primary:
        return (
          cs.primary,
          cs.primary.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onPrimary,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.neutral:
        return (
          cs.surfaceTint,
          cs.surfaceTint.withValues(alpha: selected ? 0.60 : 0.38),
          cs.onSurface,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.warning:
        return (
          cs.tertiary,
          cs.tertiary.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onTertiary,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.danger:
        return (
          cs.error,
          cs.error.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onError,
          cs.outlineVariant
        );
    }
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.fill, required this.ring, required this.selected});
  final Color fill;
  final Color ring;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Body circle
    final Offset c = Offset(w / 2, h * 0.40);
    final double r = w * 0.42;

    final Paint pFill = Paint()..color = fill;
    final Paint pRing = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2 : 1;

    canvas.drawCircle(c, r, pFill);
    canvas.drawCircle(c, r, pRing);

    // Pointer triangle
    final Path pointer = Path()
      ..moveTo(w / 2, h)
      ..lineTo(w / 2 - w * 0.14, h * 0.55)
      ..lineTo(w / 2 + w * 0.14, h * 0.55)
      ..close();

    final Paint pPointer = Paint()..color = fill;
    final Paint pPointerRing = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2 : 1;

    canvas.drawPath(pointer, pPointer);
    canvas.drawPath(pointer, pPointerRing);
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.ring != ring || oldDelegate.selected != selected;
  }
}

/// A Canvas renderer to generate PNG bytes for bitmap-only map SDKs (e.g., google_maps_flutter).
/// Use as: BitmapDescriptor.fromBytes(await PlaceMarkerIcon.generatePng(...))
class PlaceMarkerIcon {
  static Future<Uint8List> generatePng({
    IconData? icon,
    String? emoji,
    String? label, // ignored in bitmap marker; show in info window instead
    PlaceMarkerStyle style = PlaceMarkerStyle.primary,
    bool selected = false,
    bool compact = false,
    double devicePixelRatio = 3.0,
    ColorScheme? colorScheme,
  }) async {
    final ColorScheme cs = colorScheme ??
        const ColorScheme.light(
          primary: Color(0xFF2B50C7),
          onPrimary: Colors.white,
          tertiary: Color(0xFFEEA243),
          onTertiary: Colors.black,
          error: Color(0xFFB3261E),
          onError: Colors.white,
          surfaceTint: Color(0xFF8A8A8A),
          onSurface: Colors.black87,
          outlineVariant: Color(0xFFCAC4D0),
        );

    final (Color fill, Color ring, Color fg, Color border) = _colors(cs, style, selected);

    final (double pinW, double pinH, double halo) = compact
        ? (26.0, 38.0, selected ? 16.0 : 12.0)
        : (30.0, 44.0, selected ? 18.0 : 14.0);

    final double dpr = devicePixelRatio.clamp(1.0, 4.0);
    final double wPx = (pinW + halo) * dpr;
    final double hPx = (pinH + halo) * dpr;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..isAntiAlias = true;

    // Translate so the pin is centered within halo
    canvas.translate(halo * dpr / 2, halo * dpr / 2);

    // Halo
    paint
      ..color = fill.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pinW * dpr / 2, pinW * dpr / 2), (pinW * dpr / 2), paint);

    // Body circle
    final Offset c = Offset(pinW * dpr / 2, pinH * dpr * 0.40);
    final double r = pinW * dpr * 0.42;

    paint
      ..color = fill
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, paint);

    paint
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = (selected ? 2.0 : 1.0) * dpr;
    canvas.drawCircle(c, r, paint);

    // Pointer
    final Path pointer = Path()
      ..moveTo(pinW * dpr / 2, pinH * dpr)
      ..lineTo(pinW * dpr / 2 - pinW * dpr * 0.14, pinH * dpr * 0.55)
      ..lineTo(pinW * dpr / 2 + pinW * dpr * 0.14, pinH * dpr * 0.55)
      ..close();

    paint
      ..color = fill
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointer, paint);

    paint
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = (selected ? 2.0 : 1.0) * dpr;
    canvas.drawPath(pointer, paint);

    // Glyph (emoji or icon)
    if (emoji != null && emoji.isNotEmpty) {
      final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: (compact ? 13.0 : 15.0) * dpr),
      )..pushStyle(ui.TextStyle(color: fg));
      pb.addText(emoji);
      final ui.Paragraph ph = pb.build()
        ..layout(ui.ParagraphConstraints(width: pinW * dpr));
      final double ty = (pinH * dpr * 0.22);
      canvas.drawParagraph(ph, Offset(0, ty));
    } else {
      final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: (compact ? 16.0 : 18.0) * dpr),
      )..pushStyle(ui.TextStyle(color: fg, fontWeight: ui.FontWeight.w800));
      // Draw a Material icon as text glyph via codepoint; alternative is vector path painting.
      final String ch = String.fromCharCode((icon ?? Icons.place_rounded).codePoint);
      pb.addText(String.fromCharCode(ch.codeUnitAt(0)));
      pb.pushStyle; // no-op, keep single run
      final ui.Paragraph ph = pb.build()
        ..layout(ui.ParagraphConstraints(width: pinW * dpr));
      final double ty = (pinH * dpr * 0.22);
      canvas.drawParagraph(ph, Offset(0, ty));
    }

    final ui.Picture pic = recorder.endRecording();
    final ui.Image img = await pic.toImage(wPx.toInt(), hPx.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static (Color, Color, Color, Color) _colors(ColorScheme cs, PlaceMarkerStyle s, bool selected) {
    switch (s) {
      case PlaceMarkerStyle.primary:
        return (
          cs.primary,
          cs.primary.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onPrimary,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.neutral:
        return (
          cs.surfaceTint,
          cs.surfaceTint.withValues(alpha: selected ? 0.60 : 0.38),
          cs.onSurface,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.warning:
        return (
          cs.tertiary,
          cs.tertiary.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onTertiary,
          cs.outlineVariant
        );
      case PlaceMarkerStyle.danger:
        return (
          cs.error,
          cs.error.withValues(alpha: selected ? 0.70 : 0.45),
          cs.onError,
          cs.outlineVariant
        );
    }
  }
}
