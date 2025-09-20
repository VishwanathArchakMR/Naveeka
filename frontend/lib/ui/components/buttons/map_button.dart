// lib/ui/components/buttons/map_button.dart

import 'package:flutter/material.dart';

/// Map rendering styles to toggle via the button menu.
enum MapStyle { standard, satellite, terrain }

/// Visual variants using Material 3 IconButton constructors.
enum MapButtonVariant { standard, filled, filledTonal, outlined }

/// A compact "map layers" button with a menu for style and traffic,
/// and an optional action to open a full-screen map.
/// The widget is stateless on its own; pass the current state and react to callbacks.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.style,
    required this.trafficEnabled,
    this.onStyleChanged,
    this.onTrafficChanged,
    this.onOpenMap,
    this.tooltip = 'Map options',
    this.variant = MapButtonVariant.filledTonal,
    this.size = 24.0,
    this.enabled = true,
  });

  /// Current selected map style.
  final MapStyle style;

  /// Whether traffic overlay is enabled.
  final bool trafficEnabled;

  /// Called when the user selects a new style.
  final ValueChanged<MapStyle>? onStyleChanged;

  /// Called when the user toggles the traffic overlay.
  final ValueChanged<bool>? onTrafficChanged;

  /// Optional quick action to open a full-screen map or map screen.
  final VoidCallback? onOpenMap;

  /// Tooltip for accessibility.
  final String? tooltip;

  /// M3 icon-button variant to use.
  final MapButtonVariant variant;

  /// Icon size in logical pixels.
  final double size;

  /// Disable interactions when false.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    final wrapped = (tooltip != null && tooltip!.trim().isNotEmpty)
        ? Tooltip(message: tooltip!, child: button)
        : button;

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip ?? 'Map options',
      child: wrapped,
    );
  }

  Widget _buildButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Show a small indicator dot when any non-default layer is active
    final bool hasActiveLayer = style != MapStyle.standard || trafficEnabled;

    final Widget baseIcon = Icon(Icons.map_rounded, size: size);

    final Widget indicator = Positioned(
      right: -2,
      top: -2,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          // Use withValues for alpha instead of withOpacity.
          color: cs.primary.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1.5,
          ),
        ),
      ),
    );

    final Widget iconWithIndicator = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        baseIcon,
        if (hasActiveLayer) indicator,
      ],
    );

    final VoidCallback? onPressed = enabled ? () => _showMenu(context) : null;

    switch (variant) {
      case MapButtonVariant.filled:
        return IconButton.filled(
          onPressed: onPressed,
          icon: iconWithIndicator,
        );
      case MapButtonVariant.filledTonal:
        return IconButton.filledTonal(
          onPressed: onPressed,
          icon: iconWithIndicator,
        );
      case MapButtonVariant.outlined:
        return IconButton.outlined(
          onPressed: onPressed,
          icon: iconWithIndicator,
        );
      case MapButtonVariant.standard:
        return IconButton(
          onPressed: onPressed,
          icon: iconWithIndicator,
        );
    }
  }

  void _showMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset pos = box.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      pos.dx,
      pos.dy + box.size.height,
      pos.dx + box.size.width,
      pos.dy,
    );

    final selected = await showMenu<_MapMenuSelection>(
      context: context,
      position: position,
      items: <PopupMenuEntry<_MapMenuSelection>>[
        if (onOpenMap != null)
          const PopupMenuItem<_MapMenuSelection>(
            value: _MapMenuSelection.openMap(),
            child: Row(
              children: <Widget>[
                Icon(Icons.open_in_full_rounded, size: 18),
                SizedBox(width: 8),
                Text('Open map'),
              ],
            ),
          ),
        if (onOpenMap != null) const PopupMenuDivider(),
        // Style radio items
        PopupMenuItem<_MapMenuSelection>(
          value: const _MapMenuSelection.style(MapStyle.standard),
          child: _RadioRow<MapStyle>(
            label: 'Standard',
            value: MapStyle.standard,
            groupValue: style,
          ),
        ),
        PopupMenuItem<_MapMenuSelection>(
          value: const _MapMenuSelection.style(MapStyle.satellite),
          child: _RadioRow<MapStyle>(
            label: 'Satellite',
            value: MapStyle.satellite,
            groupValue: style,
          ),
        ),
        PopupMenuItem<_MapMenuSelection>(
          value: const _MapMenuSelection.style(MapStyle.terrain),
          child: _RadioRow<MapStyle>(
            label: 'Terrain',
            value: MapStyle.terrain,
            groupValue: style,
          ),
        ),
        const PopupMenuDivider(),
        // Traffic checkbox
        PopupMenuItem<_MapMenuSelection>(
          value: const _MapMenuSelection.traffic(),
          child: _CheckboxRow(
            label: 'Traffic',
            checked: trafficEnabled,
          ),
        ),
      ],
    );

    if (selected == null) return;

    selected.when(
      onOpenMap: () => onOpenMap?.call(),
      onStyle: (s) => onStyleChanged?.call(s),
      onTraffic: () => onTrafficChanged?.call(!trafficEnabled),
    );
  }
}

@immutable
class _MapMenuSelection {
  const _MapMenuSelection.openMap()
      : kind = _MapMenuKind.openMap,
        style = null;
  const _MapMenuSelection.style(this.style) : kind = _MapMenuKind.style;
  const _MapMenuSelection.traffic()
      : kind = _MapMenuKind.traffic,
        style = null;

  final _MapMenuKind kind;
  final MapStyle? style;

  void when({
    required VoidCallback onOpenMap,
    required ValueChanged<MapStyle> onStyle,
    required VoidCallback onTraffic,
  }) {
    switch (kind) {
      case _MapMenuKind.openMap:
        onOpenMap();
        break;
      case _MapMenuKind.style:
        onStyle(style ?? MapStyle.standard);
        break;
      case _MapMenuKind.traffic:
        onTraffic();
        break;
    }
  }
}

enum _MapMenuKind { openMap, style, traffic }

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.value,
    required this.groupValue,
  });

  final String label;
  final T value;
  final T groupValue;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Row(
      children: <Widget>[
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 20,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: 20,
          color: checked ? Theme.of(context).colorScheme.primary : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
