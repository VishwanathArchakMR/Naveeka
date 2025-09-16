// lib/ui/components/maps/interactive_map.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Simple coordinate POJO used by the component.
@immutable
class MapLatLng {
  const MapLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  String toString() => '($latitude, $longitude)';
}

/// Minimal camera model that works across map SDKs.
@immutable
class MapCameraPosition {
  const MapCameraPosition({
    required this.target,
    required this.zoom,
    this.bearing = 0,
    this.tilt = 0,
  });

  final MapLatLng target;
  final double zoom;
  final double bearing;
  final double tilt;

  MapCameraPosition copyWith({
    MapLatLng? target,
    double? zoom,
    double? bearing,
    double? tilt,
  }) {
    return MapCameraPosition(
      target: target ?? this.target,
      zoom: zoom ?? this.zoom,
      bearing: bearing ?? this.bearing,
      tilt: tilt ?? this.tilt,
    );
  }
}

/// A bridge interface the host supplies to control the embedded map
/// without importing the SDK types into UI. Implement using your map plugin.
abstract class InteractiveMapControllerBridge {
  Future<void> animateTo(MapCameraPosition camera);
  Future<void> setMapType(String type); // 'normal' | 'satellite' | 'terrain' etc.
  Future<void> setMyLocationEnabled(bool enabled);
  Future<void> zoomBy(double delta);
  Future<MapCameraPosition> getCameraPosition();
}

/// Builder signature to render the SDK map inside this scaffold.
/// - Provide the current camera and change callbacks
/// - Provide a controller setter so this widget can drive the map via the bridge
typedef MapWidgetBuilder = Widget Function(
  BuildContext context,
  MapCameraPosition initialCamera,
  void Function(InteractiveMapControllerBridge controller) provideController,
  void Function(MapCameraPosition camera) onCameraMoved,
  void Function(MapLatLng tap) onTap,
);

/// A reusable interactive map scaffold:
/// - Accepts any SDK via builder (google_maps_flutter, flutter_map, etc.)
/// - Overlays Material 3 controls (zoom, my-location, layers)
/// - Emits camera/tap events, exposes a controller bridge for animations
/// - Uses wide-gamut safe Color.withValues and modern surfaces
class InteractiveMap extends StatefulWidget {
  const InteractiveMap({
    super.key,
    required this.initialCamera,
    required this.mapBuilder,
    this.onCameraMoved,
    this.onMapTap,
    this.onMyLocation,
    this.onToggleTraffic,
    this.onToggleBuildings,
    this.onRecenter,
    this.mapTypes = const <String>['normal', 'satellite', 'terrain'],
    this.currentMapType = 'normal',
    this.controlsPadding = const EdgeInsets.all(12),
    this.compact = false,
    this.showMyLocation = true,
    this.showZoomControls = true,
    this.showLayersControl = true,
    this.trafficEnabled = false,
    this.buildingsEnabled = true,
  });

  final MapCameraPosition initialCamera;
  final MapWidgetBuilder mapBuilder;

  final ValueChanged<MapCameraPosition>? onCameraMoved;
  final ValueChanged<MapLatLng>? onMapTap;

  /// Provide the user's current position; this widget will recenter if returned.
  final Future<MapLatLng?> Function()? onMyLocation;

  /// Optional toggles wired to your SDK/theming.
  final Future<void> Function(bool enabled)? onToggleTraffic;
  final Future<void> Function(bool enabled)? onToggleBuildings;

  /// Optional external recenter callback; if not provided, will animate to initialCamera.
  final Future<void> Function(InteractiveMapControllerBridge controller)? onRecenter;

  /// Available map types and current selection label.
  final List<String> mapTypes;
  final String currentMapType;

  final EdgeInsets controlsPadding;
  final bool compact;

  final bool showMyLocation;
  final bool showZoomControls;
  final bool showLayersControl;

  final bool trafficEnabled;
  final bool buildingsEnabled;

  @override
  State<InteractiveMap> createState() => _InteractiveMapState();
}

class _InteractiveMapState extends State<InteractiveMap> {
  InteractiveMapControllerBridge? _controller;
  late MapCameraPosition _camera = widget.initialCamera;

  bool _traffic = false;
  bool _buildings = true;
  late String _mapType = widget.currentMapType;

  @override
  void initState() {
    super.initState();
    _traffic = widget.trafficEnabled;
    _buildings = widget.buildingsEnabled;
  }

  void _provideController(InteractiveMapControllerBridge c) {
    _controller = c;
  }

  void _onCameraMoved(MapCameraPosition c) {
    _camera = c;
    widget.onCameraMoved?.call(c);
    setState(() {}); // update badges/stateful overlays if any
  }

  void _onTap(MapLatLng latLng) {
    widget.onMapTap?.call(latLng);
  }

  Future<void> _recenter() async {
    if (_controller == null) return;
    if (widget.onRecenter != null) {
      await widget.onRecenter!(_controller!);
      return;
    }
    await _controller!.animateTo(widget.initialCamera);
  }

  Future<void> _zoomBy(double delta) async {
    if (_controller == null) return;
    await _controller!.zoomBy(delta);
    final pos = await _controller!.getCameraPosition();
    _onCameraMoved(pos);
  }

  Future<void> _toggleTraffic() async {
    final next = !_traffic;
    setState(() => _traffic = next);
    await widget.onToggleTraffic?.call(next);
  }

  Future<void> _toggleBuildings() async {
    final next = !_buildings;
    setState(() => _buildings = next);
    await widget.onToggleBuildings?.call(next);
  }

  Future<void> _cycleMapType() async {
    if (_controller == null) return;
    final idx = widget.mapTypes.indexOf(_mapType);
    final next = widget.mapTypes[(idx + 1) % widget.mapTypes.length];
    setState(() => _mapType = next);
    await _controller!.setMapType(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pad = widget.controlsPadding;

    final map = widget.mapBuilder(
      context,
      widget.initialCamera,
      _provideController,
      _onCameraMoved,
      _onTap,
    );

    final controls = Positioned(
      right: pad.right,
      bottom: pad.bottom,
      child: _ControlsColumn(
        compact: widget.compact,
        showMyLocation: widget.showMyLocation,
        showZoom: widget.showZoomControls,
        showLayers: widget.showLayersControl,
        onMyLocation: () async {
          if (widget.onMyLocation == null || _controller == null) return;
          final me = await widget.onMyLocation!.call();
          if (me == null) return;
          await _controller!.animateTo(
            _camera.copyWith(target: MapLatLng(me.latitude, me.longitude)),
          );
        },
        onZoomIn: () => _zoomBy(1),
        onZoomOut: () => _zoomBy(-1),
        onRecenter: _recenter,
        onToggleTraffic: widget.onToggleTraffic != null ? _toggleTraffic : null,
        trafficOn: _traffic,
        onToggleBuildings: widget.onToggleBuildings != null ? _toggleBuildings : null,
        buildingsOn: _buildings,
        onCycleMapType: _cycleMapType,
        currentType: _mapType,
      ),
    );

    // Small status chip top-left showing current zoom and type
    final status = Positioned(
      left: pad.left,
      top: pad.top,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10, vertical: widget.compact ? 6 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.zoom_in_map_rounded, size: widget.compact ? 16 : 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'z ${_camera.zoom.toStringAsFixed(1)} • ${_mapType}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: map),
        status,
        controls,
      ],
    );
  }
}

class _ControlsColumn extends StatelessWidget {
  const _ControlsColumn({
    required this.compact,
    required this.showMyLocation,
    required this.showZoom,
    required this.showLayers,
    required this.onMyLocation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onToggleTraffic,
    required this.trafficOn,
    required this.onToggleBuildings,
    required this.buildingsOn,
    required this.onCycleMapType,
    required this.currentType,
  });

  final bool compact;
  final bool showMyLocation;
  final bool showZoom;
  final bool showLayers;

  final Future<void> Function()? onMyLocation;
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onRecenter;

  final Future<void> Function()? onToggleTraffic;
  final bool trafficOn;

  final Future<void> Function()? onToggleBuildings;
  final bool buildingsOn;

  final Future<void> Function() onCycleMapType;
  final String currentType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final double spacing = compact ? 8 : 10;
    final EdgeInsets btnPad = EdgeInsets.all(compact ? 10 : 12);
    final BorderRadius radius = BorderRadius.circular(12);

    Widget tile(IconData icon, {String? tooltip, VoidCallback? onTap, Color? bg}) {
      final child = DecoratedBox(
        decoration: BoxDecoration(
          color: (bg ?? cs.surfaceContainerHighest).withValues(alpha: 0.92),
          borderRadius: radius,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: btnPad,
          child: Icon(icon, size: compact ? 18 : 20, color: cs.onSurface),
        ),
      );
      final wrapped = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: child,
        ),
      );
      return tooltip != null ? Tooltip(message: tooltip, child: wrapped) : wrapped;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (showMyLocation && onMyLocation != null)
          tile(Icons.my_location_rounded, tooltip: 'My location', onTap: () => onMyLocation!.call()),
        if (showZoom) SizedBox(height: spacing),
        if (showZoom)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              tile(Icons.add_rounded, tooltip: 'Zoom in', onTap: onZoomIn),
              SizedBox(height: spacing),
              tile(Icons.remove_rounded, tooltip: 'Zoom out', onTap: onZoomOut),
              SizedBox(height: spacing),
              tile(Icons.center_focus_strong_rounded, tooltip: 'Recenter', onTap: onRecenter),
            ],
          ),
        if (showLayers) SizedBox(height: spacing),
        if (showLayers)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              tile(
                trafficOn ? Icons.traffic_rounded : Icons.traffic_outlined,
                tooltip: trafficOn ? 'Traffic on' : 'Traffic off',
                onTap: onToggleTraffic != null ? () => onToggleTraffic!.call() : null,
              ),
              SizedBox(height: spacing),
              tile(
                buildingsOn ? Icons.apartment_rounded : Icons.domain_disabled_rounded,
                tooltip: buildingsOn ? 'Buildings on' : 'Buildings off',
                onTap: onToggleBuildings != null ? () => onToggleBuildings!.call() : null,
              ),
              SizedBox(height: spacing),
              tile(Icons.layers_rounded, tooltip: 'Cycle map type ($currentType)', onTap: onCycleMapType),
            ],
          ),
      ],
    );
  }
}
