// lib/features/places/presentation/widgets/coordinates_display.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/place.dart';

class CoordinatesDisplay extends StatelessWidget {
  const CoordinatesDisplay({
    super.key,
    required this.lat,
    required this.lng,
    this.title = 'Coordinates',
    this.decimals = 6,
    this.showTitle = true,
  });

  /// Convenience factory to use with your app's Place model.
  factory CoordinatesDisplay.fromPlace(
    Place p, {
    Key? key,
    String title = 'Coordinates',
    int decimals = 6,
    bool showTitle = true,
  }) {
    return CoordinatesDisplay(
      key: key,
      lat: p.lat,
      lng: p.lng,
      title: title,
      decimals: decimals,
      showTitle: showTitle,
    );
  }

  final double? lat;
  final double? lng;
  final String title;
  final int decimals;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) return const SizedBox.shrink();

    final decStr = '${lat!.toStringAsFixed(decimals)}, ${lng!.toStringAsFixed(decimals)}';
    final dmsStr = _formatDms(lat!, lng!);

    final mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}',
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),

            // Decimal row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location_outlined),
              title: const Text('Decimal'),
              subtitle: Text(decStr),
              trailing: IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () => _copy(context, decStr),
              ),
              onTap: () => _copy(context, decStr),
            ),

            // DMS row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.explore_outlined),
              title: const Text('DMS'),
              subtitle: Text(dmsStr),
              trailing: IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () => _copy(context, dmsStr),
              ),
              onTap: () => _copy(context, dmsStr),
            ),

            // Open in Maps
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openMaps(mapUri),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  Future<void> _openMaps(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDms(double lat, double lng) {
    String dms(double d, String pos, String neg) {
      final dir = d >= 0 ? pos : neg;
      final abs = d.abs();
      final deg = abs.floor();
      final minFloat = (abs - deg) * 60;
      final min = minFloat.floor();
      final sec = ((minFloat - min) * 60);
      return '$deg° $min\' ${sec.toStringAsFixed(2)}" $dir';
    }

    final latDms = dms(lat, 'N', 'S');
    final lngDms = dms(lng, 'E', 'W');
    return '$latDms, $lngDms';
  }
}
