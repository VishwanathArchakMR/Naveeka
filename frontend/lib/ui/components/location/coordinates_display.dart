// lib/ui/components/location/coordinates_display.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Coordinate formatting options.
enum CoordFormat { dd, dms }

/// A compact coordinates card with DD/DMS formats, copy, and optional map open.
/// - Uses Material 3 surfaces and tokens
/// - Wide-gamut safe alpha via Color.withValues (no withOpacity)
/// - Dependency-free: expose launcher/share callbacks from the caller
class CoordinatesDisplay extends StatefulWidget {
  const CoordinatesDisplay({
    super.key,
    required this.latitude,
    required this.longitude,
    this.altitude, // meters, optional
    this.initialFormat = CoordFormat.dd,
    this.precision = 5,
    this.compact = false,
    this.showCopy = true,
    this.showMapButton = true,
    this.onLaunchUri, // e.g., (uri) => launchUrl(uri)
    this.onShareText, // e.g., (text) => Share.share(text)
    this.title = 'Coordinates',
  });

  final double latitude;
  final double longitude;
  final double? altitude;

  final CoordFormat initialFormat;
  final int precision;

  final bool compact;
  final bool showCopy;
  final bool showMapButton;

  /// Optional launcher callback to keep UI decoupled from plugins.
  final Future<bool> Function(Uri uri)? onLaunchUri;

  /// Optional share callback if the host app provides sharing.
  final Future<void> Function(String text)? onShareText;

  final String title;

  @override
  State<CoordinatesDisplay> createState() => _CoordinatesDisplayState();
}

class _CoordinatesDisplayState extends State<CoordinatesDisplay> {
  late CoordFormat _format = widget.initialFormat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final String dd = _formatDD(widget.latitude, widget.longitude, widget.precision);
    final String dms = _formatDMS(widget.latitude, widget.longitude);

    final String value = _format == CoordFormat.dd ? dd : dms;
    final String? alt = widget.altitude != null ? '${widget.altitude!.toStringAsFixed(0)} m' : null;

    final double padV = widget.compact ? 10 : 14;
    final double padH = widget.compact ? 12 : 14;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            children: <Widget>[
              Icon(Icons.my_location_rounded, size: widget.compact ? 18 : 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Format switcher
              SegmentedButton<CoordFormat>(
                style: ButtonStyle(
                  visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                ),
                segments: const <ButtonSegment<CoordFormat>>[
                  ButtonSegment<CoordFormat>(value: CoordFormat.dd, label: Text('DD')),
                  ButtonSegment<CoordFormat>(value: CoordFormat.dms, label: Text('DMS')),
                ],
                selected: <CoordFormat>{_format},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) setState(() => _format = s.first);
                },
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 8 : 10),
          // Value lines
          SelectableText(
            value,
            style: t.textTheme.bodyLarge?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (alt != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Altitude: $alt',
              style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          SizedBox(height: widget.compact ? 8 : 10),
          // Actions
          Row(
            children: <Widget>[
              if (widget.showCopy)
                OutlinedButton.icon(
                  onPressed: () => _copyText(value),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                  ),
                ),
              if (widget.onShareText != null) ...<Widget>[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.onShareText!.call(value),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                  ),
                ),
              ],
              const Spacer(),
              if (widget.showMapButton)
                FilledButton.tonalIcon(
                  onPressed: () => _openMaps(),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Open map'),
                  style: FilledButton.styleFrom(
                    visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.95),
      ),
    );
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse('geo:${widget.latitude},${widget.longitude}?q=${widget.latitude},${widget.longitude}');
    if (widget.onLaunchUri != null) {
      try {
        await widget.onLaunchUri!(uri);
      } catch (_) {
        // ignore launcher errors; keep UI silent
      }
    }
  }

  String _formatDD(double lat, double lon, int precision) {
    final String nss = lat >= 0 ? 'N' : 'S';
    final String ews = lon >= 0 ? 'E' : 'W';
    final String alat = lat.abs().toStringAsFixed(precision);
    final String alon = lon.abs().toStringAsFixed(precision);
    return '$alat° $nss, $alon° $ews';
  }

  String _formatDMS(double lat, double lon) {
    String latStr = _toDMS(lat, isLat: true);
    String lonStr = _toDMS(lon, isLat: false);
    return '$latStr, $lonStr';
  }

  String _toDMS(double v, {required bool isLat}) {
    final String hemi = isLat ? (v >= 0 ? 'N' : 'S') : (v >= 0 ? 'E' : 'W');
    final double av = v.abs();
    final int deg = av.floor();
    final double minFloat = (av - deg) * 60.0;
    final int min = minFloat.floor();
    final double sec = (minFloat - min) * 60.0;
    final String d = isLat ? deg.toString().padLeft(2, '0') : deg.toString().padLeft(3, '0');
    final String m = min.toString().padLeft(2, '0');
    final String s = sec.toStringAsFixed(2).padLeft(5, '0');
    return '$d°$m\'$s" $hemi';
  }
}
