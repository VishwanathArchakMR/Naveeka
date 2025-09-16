// lib/features/home/presentation/widgets/location_banner.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/storage/location_cache.dart';

/// A compact location banner for the Home screen that reacts to cached
/// location updates and exposes actions for permissions/settings. [6]
class LocationBanner extends StatefulWidget {
  const LocationBanner({
    super.key,
    this.title = 'Discover nearby',
    this.compact = true,
    this.listenChanges = true,
    this.ttl = const Duration(minutes: 10),
    this.onUseLocation,
    this.onChangeLocation,
    this.onOpenSettings,
    this.loading = false,
  });

  final String title;
  final bool compact;
  final bool listenChanges;
  final Duration ttl;

  /// Called when the user taps "Use location" (request permission + fetch). [6]
  final VoidCallback? onUseLocation;

  /// Called when the user taps "Change" (choose a city/region manually). [1]
  final VoidCallback? onChangeLocation;

  /// Called when the user taps "Settings" (open app/system settings). [6]
  final VoidCallback? onOpenSettings;

  /// When true, the primary action shows a small progress indicator. [1]
  final bool loading;

  @override
  State<LocationBanner> createState() => _LocationBannerState();
}

class _LocationBannerState extends State<LocationBanner> {
  LocationSnapshot? _last;
  StreamSubscription<LocationSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.listenChanges) {
      _sub = LocationCache.instance.changes.listen((snap) {
        setState(() => _last = snap);
      });
    }
  }

  @override
  void didUpdateWidget(covariant LocationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenChanges != widget.listenChanges) {
      _sub?.cancel();
      _sub = null;
      if (widget.listenChanges) {
        _sub = LocationCache.instance.changes.listen((snap) {
          setState(() => _last = snap);
        });
      }
    }
  }

  Future<void> _load() async {
    final snap = await LocationCache.instance.getLast(maxAge: widget.ttl);
    if (mounted) setState(() => _last = snap);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFresh = _last != null &&
        DateTime.now().difference(_last!.timestamp) <= widget.ttl;
    final subtitle = _subtitle(isFresh);

    return Container(
      padding: widget.compact
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Actions(
            loading: widget.loading,
            onUseLocation: widget.onUseLocation,
            onChangeLocation: widget.onChangeLocation,
            onOpenSettings: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  String? _subtitle(bool isFresh) {
    if (_last == null) {
      return 'Enable location to see places nearby'; // No cached location yet
    }
    final label = _last!.address ??
        'Lat ${_last!.latitude.toStringAsFixed(4)}, Lng ${_last!.longitude.toStringAsFixed(4)}';
    final age = _ageString(_last!.timestamp);
    return isFresh ? label : '$label • $age';
  }

  String _ageString(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.loading,
    this.onUseLocation,
    this.onChangeLocation,
    this.onOpenSettings,
  });

  final bool loading;
  final VoidCallback? onUseLocation;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      TextButton(
        onPressed: loading ? null : onUseLocation,
        child: loading
            ? const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Use location'),
      ),
      if (onChangeLocation != null)
        TextButton(onPressed: onChangeLocation, child: const Text('Change')),
      if (onOpenSettings != null)
        TextButton(onPressed: onOpenSettings, child: const Text('Settings')),
    ];
    return Wrap(spacing: 4, runSpacing: 0, children: buttons);
  }
}

/// Optional helper to present the same UI as a MaterialBanner using ScaffoldMessenger. [5]
class LocationBannerPresenter {
  static void showAsMaterialBanner(
    BuildContext context, {
    required Widget content,
    required List<Widget> actions,
    Widget? leading,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: content,
        actions: actions,
        leading: leading ?? const Icon(Icons.location_on_outlined),
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  }
}
