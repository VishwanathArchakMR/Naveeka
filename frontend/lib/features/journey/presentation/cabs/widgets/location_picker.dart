// lib/features/journey/presentation/cabs/widgets/location_picker.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../core/storage/location_cache.dart';

/// Minimal coordinate model (replaces latlong2.LatLng for this widget)
@immutable
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    this.title = 'Pick location',
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.geocodeSearch, // Future<List<{address,lat,lng}>> Function(q)
    this.reverseGeocode, // Future<String?> Function(lat,lng)
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final String title;

  // Kept for future extensibility; not used in this dependency-free version.
  final String tileUrl;
  final List<String> tileSubdomains;

  final Future<List<Map<String, dynamic>>> Function(String q)? geocodeSearch;
  final Future<String?> Function(double lat, double lng)? reverseGeocode;

  @override
  State<LocationPicker> createState() => _LocationPickerState();

  /// Helper to present as a modal bottom sheet and return a result map:
  /// { 'lat': double, 'lng': double, 'address': String? }
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
    String? initialAddress,
    String title = 'Pick location',
    String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    List<String> tileSubdomains = const ['a', 'b', 'c'],
    Future<List<Map<String, dynamic>>> Function(String q)? geocodeSearch,
    Future<String?> Function(double lat, double lng)? reverseGeocode,
  }) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: LocationPicker(
          initialLat: initialLat,
          initialLng: initialLng,
          initialAddress: initialAddress,
          title: title,
          tileUrl: tileUrl,
          tileSubdomains: tileSubdomains,
          geocodeSearch: geocodeSearch,
          reverseGeocode: reverseGeocode,
        ),
      ),
    );
  }
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounce;
  final Duration _debounceDuration = const Duration(milliseconds: 350);

  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggest = false;

  LatLng? _selected;
  String? _address;

  // Simple zoom scalar to vary coordinate spread when tapping
  double _zoom = 12; // 12 ~ city view; 16 ~ street-level

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
      _address = widget.initialAddress;
      _zoom = 16;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
    // GestureDetector-based approach is dependency-free and uses standard Flutter APIs. [web:5945][web:5946]
  }

  Future<void> _useCurrent() async {
    final snap = await LocationCache.instance
        .getLast(maxAge: const Duration(minutes: 10));
    if (!mounted) return;
    if (snap == null) {
      _snack('Location not available yet');
      return;
    }
    setState(() {
      _selected = LatLng(snap.latitude, snap.longitude);
      _address = 'Current location';
      _suggestions = const [];
      _zoom = 16;
    });
    // Optional reverse geocode
    if (widget.reverseGeocode != null) {
      final addr = await widget.reverseGeocode!(
          _selected!.latitude, _selected!.longitude);
      if (!mounted) return;
      if (addr != null && addr.isNotEmpty) setState(() => _address = addr);
    }
  }

  void _onCanvasTapDown(TapDownDetails details, Size size) async {
    // Approximate conversion: map the tap within the box to lat/lng deltas around current center.
    final center = _selected ??
        const LatLng(12.9716, 77.5946); // Bengaluru fallback center
    final local = details.localPosition;
    final nx = (local.dx.clamp(0, size.width)) / size.width; // 0..1
    final ny = (local.dy.clamp(0, size.height)) / size.height; // 0..1

    // Span shrinks as zoom increases (very rough model).
    final scale = math.pow(2.0, (_zoom - 12)).toDouble(); // zoom 12 => 1.0
    const baseSpan = 0.05; // ~5km-ish at zoom 12; adjust as needed
    final spanLat = baseSpan / scale;
    final spanLng = baseSpan / scale;

    final lat = center.latitude + (0.5 - ny) * 2 * spanLat;
    final lng = center.longitude + (nx - 0.5) * 2 * spanLng;

    setState(() {
      _selected = LatLng(lat, lng);
      _address = null;
      _suggestions = const [];
      _zoom = 16;
    });

    if (widget.reverseGeocode != null) {
      final addr = await widget.reverseGeocode!(lat, lng);
      if (!mounted) return;
      if (addr != null && addr.isNotEmpty) setState(() => _address = addr);
    }
    // This replaces flutter_map's MapOptions.onTap(TapPosition, LatLng) using native GestureDetector. [web:5951][web:5945]
  }

  void _onSearchChanged(String q) {
    if (widget.geocodeSearch == null) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () async {
      final query = q.trim();
      if (query.isEmpty) {
        if (!mounted) return;
        setState(() => _suggestions = const []);
        return;
      }
      setState(() {
        _loadingSuggest = true;
        _suggestions = const [];
      });
      try {
        final res = await widget.geocodeSearch!(query);
        if (!mounted) return;
        setState(() {
          _suggestions = res;
          _loadingSuggest = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingSuggest = false;
          _suggestions = const [];
        });
      }
    });
  } // Debounce typing with a Timer; triggers geocodeSearch after user pause. [web:5945][web:5952]

  void _applySuggestion(Map<String, dynamic> s) {
    final lat = _toD(s['lat']);
    final lng = _toD(s['lng']);
    if (lat == null || lng == null) return;
    final addr = (s['address'] ?? '').toString();
    setState(() {
      _selected = LatLng(lat, lng);
      _address = addr.isNotEmpty ? addr : _address;
      _suggestions = const [];
      _searchCtrl.text = addr.isNotEmpty ? addr : _searchCtrl.text;
      _searchFocus.unfocus();
      _zoom = 16;
    });
  }

  void _confirm() {
    if (_selected == null) {
      _snack('Tap on map to pick a location');
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'lat': _selected!.latitude,
      'lng': _selected!.longitude,
      'address': _address,
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } // Use ScaffoldMessenger to display SnackBars from modals/sheets. [web:5903][web:5873]

  double? _toD(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected ??
        const LatLng(12.9716, 77.5946); // Default center if none selected yet
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search address or place',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Use current location',
                  onPressed: _useCurrent,
                  icon: const Icon(Icons.my_location),
                ),
              ),
            ),
          ),
          if (_loadingSuggest)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Suggestions
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final addr = (s['address'] ?? '').toString();
                  final lat = _toD(s['lat']);
                  final lng = _toD(s['lng']);
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(addr.isEmpty ? 'Result' : addr,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: (lat != null && lng != null)
                        ? Text(
                            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}')
                        : null,
                    onTap: () => _applySuggestion(s),
                  );
                },
              ),
            ),

          // "Map" area (dependency-free mock map with tap-to-pick using GestureDetector)
          SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _onCanvasTapDown(details,
                          Size(constraints.maxWidth, constraints.maxHeight)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background placeholder (could be replaced with a static map image if desired)
                          Container(
                            color: Colors.grey.shade200,
                            child: CustomPaint(
                              painter: _GridPainter(),
                            ),
                          ),
                          // Centered pin to indicate current selection point (center = _selected or default)
                          if (_selected != null)
                            const Align(
                              alignment: Alignment.center,
                              child: _Pin(color: Colors.red, icon: Icons.place),
                            )
                          else
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Tap to pick',
                                    style: TextStyle(color: Colors.black54)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ), // GestureDetector lets the widget capture taps and compute positions without external plugins. [web:5945][web:5946]

          // Coordinates + address
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selected == null
                        ? 'Tap on the map to select'
                        : '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_address != null && _address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _address!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),

          // Confirm
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// Simple background grid painter for the mock map
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);

    final line = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final cross = Paint()
      ..color = Colors.black26
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width / 2 - 8, size.height / 2),
        Offset(size.width / 2 + 8, size.height / 2), cross);
    canvas.drawLine(Offset(size.width / 2, size.height / 2 - 8),
        Offset(size.width / 2, size.height / 2 + 8), cross);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
