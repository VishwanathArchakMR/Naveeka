// lib/features/places/presentation/widgets/address_details.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AddressDetails extends StatelessWidget {
  const AddressDetails({
    super.key,
    this.title,
    this.addressLine,
    this.city,
    this.region,
    this.postalCode,
    this.country,
    this.lat,
    this.lng,
    this.phone,
    this.website,
    this.showTitle = true,
  });

  /// Convenience factory to build from any place-like object (model or Map).
  /// Tries multiple common field names to maximize compatibility.
  factory AddressDetails.fromPlace(
    dynamic p, {
    Key? key,
    bool showTitle = true,
  }) {
    String? _str(dynamic v) => (v == null) ? null : v.toString();
    double? _num(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // Helper to read by property or map key
    T? _get<T>(List<String> names) {
      for (final n in names) {
        try {
          // Try property access
          final v = (p as dynamic).$n; // Will throw if not supported
          if (v is T) return v;
          if (T == String && v != null) return _str(v) as T?;
          if (T == double && v != null) return _num(v) as T?;
        } catch (_) {}
        // Try map access
        if (p is Map) {
          final v = p[n];
          if (v is T) return v;
          if (T == String && v != null) return _str(v) as T?;
          if (T == double && v != null) return _num(v) as T?;
        }
      }
      return null;
    }

    final name = _get<String>(['name', 'title', 'label']);
    final address = _get<String>(['address', 'addressLine', 'street', 'line1']);
    final city = _get<String>(['city', 'town', 'locality']);
    final region = _get<String>(['region', 'state', 'province', 'county']);
    final postal = _get<String>(['postalCode', 'zip', 'postcode']);
    final country = _get<String>(['country', 'countryName', 'country_code']);
    final lat = _get<double>(['lat', 'latitude']);
    final lng = _get<double>(['lng', 'lon', 'long', 'longitude']);
    final phone = _get<String>(['phone', 'tel', 'telephone', 'mobile']);
    final website = _get<String>(['website', 'url', 'site', 'link']);

    return AddressDetails(
      key: key,
      title: name,
      addressLine: address,
      city: city,
      region: region,
      postalCode: postal,
      country: country,
      lat: lat,
      lng: lng,
      phone: phone,
      website: website,
      showTitle: showTitle,
    );
  }

  final String? title;
  final String? addressLine;
  final String? city;
  final String? region;
  final String? postalCode;
  final String? country;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? website;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final full = _fullAddress();
    final canMap = (lat != null && lng != null) || (full?.isNotEmpty == true);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle && (title?.trim().isNotEmpty ?? false))
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(title!.trim(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          if (full != null && full.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Address'),
              subtitle: Text(full),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Copy',
                    child: IconButton(
                      icon: const Icon(Icons.copy_all_outlined),
                      onPressed: () => _copy(context, full),
                    ),
                  ),
                  if (canMap)
                    Tooltip(
                      message: 'Open in Maps',
                      child: IconButton(
                        icon: const Icon(Icons.map_outlined),
                        onPressed: () => _openMaps(context),
                      ),
                    ),
                ],
              ),
              onTap: canMap ? () => _openMaps(context) : null,
            ),
          if (phone != null && phone!.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: Text(phone!.trim()),
              trailing: Tooltip(
                message: 'Call',
                child: IconButton(
                  icon: const Icon(Icons.phone_forwarded_outlined),
                  onPressed: () => _call(context),
                ),
              ),
              onTap: () => _call(context),
            ),
          if (website != null && website!.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: Text(_displayHost(website!.trim())),
              subtitle: Text(website!.trim()),
              trailing: Tooltip(
                message: 'Open link',
                child: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openWebsite(context),
                ),
              ),
              onTap: () => _openWebsite(context),
            ),
        ],
      ),
    );
  }

  String? _fullAddress() {
    final parts = <String>[
      if ((addressLine ?? '').trim().isNotEmpty) addressLine!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
      if ((postalCode ?? '').trim().isNotEmpty) postalCode!.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(const SnackBar(content: Text('Copied'))); // Use captured messenger to avoid context after await [web:5680][web:5873]
  }

  Future<void> _openMaps(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = _mapsUri();
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open maps'))); // Avoids BuildContext across async gap by capturing messenger [web:5680][web:5873]
    }
  }

  Uri? _mapsUri() {
    // Prefer coordinates; otherwise query by address.
    if (lat != null && lng != null) {
      return Uri.parse('https://www.google.com/maps/search/?api=1&query=${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}');
    }
    final q = _fullAddress();
    if (q == null || q.isEmpty) return null;
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
  }

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final p = (phone ?? '').trim();
    if (p.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p);
    final ok = await launchUrl(uri);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not start call'))); // Capture before await to fix the lint [web:5680][web:5873]
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = (website ?? '').trim();
    if (raw.isEmpty) return;
    final Uri uri = _ensureHttp(raw);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open website'))); // External browser via LaunchMode.externalApplication [web:5878][web:5669]
    }
  }

  Uri _ensureHttp(String url) {
    final hasScheme = url.startsWith('http://') || url.startsWith('https://');
    return Uri.parse(hasScheme ? url : 'https://$url');
  }

  String _displayHost(String url) {
    try {
      final u = _ensureHttp(url);
      return u.host.isNotEmpty ? u.host : url;
    } catch (_) {
      return url;
    }
  }
}
