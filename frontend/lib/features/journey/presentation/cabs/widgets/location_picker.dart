// lib/features/journey/presentation/cabs/widgets/location_picker.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/storage/location_cache.dart';

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
  final MapController _map = MapController();

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounce;
  final Duration _debounceDuration = const Duration(milliseconds: 350);

  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggest = false;

  LatLng? _selected;
  String? _address;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
      _address = widget.initialAddress;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _useCurrent() async {
    final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
    if (!mounted) return;
    if (snap == null) {
      _snack('Location not available yet');
      return;
    }
    setState(() {
      _selected = LatLng(snap.latitude, snap.longitude);
      _address = 'Current location';
      _suggestions = const [];
    });
    _map.move(_selected!, _map.camera.zoom);
    // Optionally perform reverse geocode
    if (widget.reverseGeocode != null) {
      final addr = await widget.reverseGeocode!(_selected!.latitude, _selected!.longitude);
      if (!mounted) return;
      if (addr != null && addr.isNotEmpty) setState(() => _address = addr);
    }
  } // Uses a cached last known location for quick centering and selection [3]

  void _onTapMap(TapPosition tapPos, LatLng latlng) async {
    setState(() {
      _selected = latlng;
      _address = null;
      _suggestions = const [];
    });
    // Optional reverse geocode
    if (widget.reverseGeocode != null) {
      final addr = await widget.reverseGeocode!(latlng.latitude, latlng.longitude);
      if (!mounted) return;
      if (addr != null && addr.isNotEmpty) setState(() => _address = addr);
    }
  } // Map taps assign selection; reverse geocoding hook can resolve human-readable address [3]

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
  } // Debounces geocoding calls to avoid spamming APIs during typing [4]

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
    });
    _map.move(_selected!, 16);
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
  } // SnackBar via ScaffoldMessenger for reliable feedback in sheets [2]

  double? _toD(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected ?? const LatLng(12.9716, 77.5946); // Default center if none selected yet (Bengaluru)
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                    title: Text(addr.isEmpty ? 'Result' : addr, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: (lat != null && lng != null) ? Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}') : null,
                    onTap: () => _applySuggestion(s),
                  );
                },
              ),
            ),

          // Map
          SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selected == null ? 12 : 16,
                    onTap: _onTapMap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                    ),
                  ), // MapOptions configures center/zoom and tap handling for selection [3]
                  children: [
                    TileLayer(
                      urlTemplate: widget.tileUrl,
                      subdomains: widget.tileSubdomains,
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_selected != null)
                          Marker(
                            point: _selected!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: const _Pin(color: Colors.red, icon: Icons.place),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ), // MarkerLayer renders the selected point with a custom, interactive widget marker [1]

          // Coordinates + address
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selected == null
                        ? 'Tap on the map to select'
                        : '${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
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
