// lib/ui/components/location/location_picker.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Simple coordinate value object used by the picker.
@immutable
class Coordinates {
  const Coordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  String toString() => '($latitude,$longitude)';
}

/// Signature for embedding a map widget inside the picker.
/// Implementations should render a map centered at [center] and call:
/// - onCameraMoved(center) whenever the camera/viewport center changes
/// - onTap(pos) when the user taps a new position to recenter/select
typedef LocationMapBuilder = Widget Function(
  BuildContext context,
  Coordinates center,
  ValueChanged<Coordinates> onCameraMoved,
  ValueChanged<Coordinates> onTap,
);

/// Reverse‑geocode callback to show a human‑readable address preview.
typedef ReverseGeocode = Future<String?> Function(Coordinates coords);

/// A reusable, plugin‑agnostic location picker:
/// - Host app provides [mapBuilder] (e.g., GoogleMap/flutter_map) and connects camera/tap callbacks
/// - Center crosshair indicates the selected coordinate
/// - Debounced [reverseGeocode] preview shown in a top chip
/// - Optional “Use current location” action
/// - Confirm/Cancel actions return the selected coordinate
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.initialCenter,
    required this.mapBuilder,
    required this.onConfirm,
    this.onCancel,
    this.onUseMyLocation,
    this.reverseGeocode,
    this.title = 'Pick location',
    this.compact = false,
    this.showMyLocation = true,
    this.addressDebounce = const Duration(milliseconds: 350),
  });

  /// Initial map center/selection.
  final Coordinates initialCenter;

  /// Builder to embed any map widget and wire camera/tap callbacks.
  final LocationMapBuilder mapBuilder;

  /// Return the final selected coordinate.
  final ValueChanged<Coordinates> onConfirm;

  /// Optional cancel handler.
  final VoidCallback? onCancel;

  /// Optional quick action to recenter on device location (host wires GPS flow).
  final Future<Coordinates?> Function()? onUseMyLocation;

  /// Optional reverse‑geocode to get a display address for the current center.
  final ReverseGeocode? reverseGeocode;

  /// Title shown in the top overlay.
  final String title;

  /// Denser paddings and controls.
  final bool compact;

  /// Show the “my location” floating control.
  final bool showMyLocation;

  /// Debounce for reverse‑geocode calls while panning.
  final Duration addressDebounce;

  @override
  State<LocationPicker> createState() => _LocationPickerState();

  /// Convenience modal presenter (bottom sheet).
  static Future<Coordinates?> showModal(
    BuildContext context, {
    required Coordinates initialCenter,
    required LocationMapBuilder mapBuilder,
    ReverseGeocode? reverseGeocode,
    Future<Coordinates?> Function()? onUseMyLocation,
    String title = 'Pick location',
    bool compact = false,
    bool showMyLocation = true,
    Duration addressDebounce = const Duration(milliseconds: 350),
  }) async {
    Coordinates? result;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: LocationPicker(
                  initialCenter: initialCenter,
                  mapBuilder: mapBuilder,
                  reverseGeocode: reverseGeocode,
                  onUseMyLocation: onUseMyLocation,
                  title: title,
                  compact: compact,
                  showMyLocation: showMyLocation,
                  addressDebounce: addressDebounce,
                  onConfirm: (c) {
                    result = c;
                    Navigator.of(ctx).pop();
                  },
                  onCancel: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
    return result;
  }
}

class _LocationPickerState extends State<LocationPicker> {
  late Coordinates _center = widget.initialCenter;

  Timer? _debounceTimer;
  String? _address;
  bool _fetchingAddress = false;

  @override
  void initState() {
    super.initState();
    _debouncedReverseGeocode();
  }

  @override
  void didUpdateWidget(LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCenter != widget.initialCenter) {
      setState(() => _center = widget.initialCenter);
      _debouncedReverseGeocode(immediate: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onCameraMoved(Coordinates c) {
    setState(() => _center = c);
    _debouncedReverseGeocode();
  }

  void _onTap(Coordinates c) {
    setState(() => _center = c);
    _debouncedReverseGeocode();
  }

  void _debouncedReverseGeocode({bool immediate = false}) {
    if (widget.reverseGeocode == null) return;
    _debounceTimer?.cancel();
    final delay = immediate ? Duration.zero : widget.addressDebounce;
    _debounceTimer = Timer(delay, () async {
      if (!mounted) return;
      setState(() {
        _fetchingAddress = true;
      });
      try {
        final res = await widget.reverseGeocode!(_center);
        if (!mounted) return;
        setState(() => _address = res);
      } finally {
        if (mounted) setState(() => _fetchingAddress = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final double pad = widget.compact ? 10 : 12;
    final map = widget.mapBuilder(context, _center, _onCameraMoved, _onTap);

    // Crosshair marker
    final crosshair = IgnorePointer(
      child: Center(
        child: _CrosshairMarker(compact: widget.compact),
      ),
    );

    // Top overlay: title + address preview
    final header = SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: widget.compact ? 8 : 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.location_on_rounded, color: cs.onSurfaceVariant, size: widget.compact ? 18 : 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_fetchingAddress)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(cs.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Finding address…',
                              style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        )
                      else
                        Text(
                          _address?.trim().isNotEmpty == true
                              ? _address!
                              : '${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (widget.showMyLocation && widget.onUseMyLocation != null) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Use my location',
                    onPressed: () async {
                      final cur = await widget.onUseMyLocation!.call();
                      if (cur != null && mounted) {
                        setState(() => _center = cur);
                        _debouncedReverseGeocode(immediate: true);
                      }
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Bottom actions
    final actionsBar = SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          children: <Widget>[
            OutlinedButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => widget.onConfirm(_center),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        // MAP
        Positioned.fill(child: map),

        // Crosshair overlay
        Positioned.fill(child: crosshair),

        // Header overlay
        Positioned(left: 0, right: 0, top: 0, child: header),

        // Bottom action bar
        Positioned(left: 0, right: 0, bottom: 0, child: actionsBar),
      ],
    );
  }
}

class _CrosshairMarker extends StatelessWidget {
  const _CrosshairMarker({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double outer = compact ? 22 : 26;
    final double inner = compact ? 8 : 10;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // slight lift so the point feels above the exact pixel center
        Transform.translate(
          offset: const Offset(0, -2),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
              Container(
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
