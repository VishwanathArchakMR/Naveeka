// lib/features/places/presentation/widgets/contact_accessibility.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/place.dart';

class ContactAccessibility extends StatelessWidget {
  const ContactAccessibility({
    super.key,
    this.title = 'Contact & accessibility',
    this.phone,
    this.email,
    this.website,
    this.whatsapp,
    this.instagram,
    this.facebook,
    this.twitter,
    this.tiktok,
    this.openingHours, // e.g., "Mon–Fri 10:00–20:00"
    // Accessibility flags
    this.wheelchairAccessible,
    this.accessibleParking,
    this.accessibleRestroom,
    this.elevator,
    this.brailleMenu,
    this.signLanguage,
    this.serviceAnimalsAllowed,
    this.familyFriendly,
    this.smokeFree,
    this.hearingLoop,
    this.highContrast,
    this.largePrint,
    this.titleIcon = Icons.info_outline,
    this.showTitle = true,
  });

  /// Convenience factory to build from your app's Place model without compile-time
  /// dependencies on optional fields; missing fields resolve to null safely.
  factory ContactAccessibility.fromPlace(
    Place p, {
    Key? key,
    bool showTitle = true,
  }) {
    final d = p as dynamic;

    T? _try<T>(T? Function() f) {
      try {
        return f();
      } catch (_) {
        return null;
      }
    }

    return ContactAccessibility(
      key: key,
      showTitle: showTitle,
      phone: _try<String?>(() => d.phone as String?),
      email: _try<String?>(() => d.email as String?),
      website: _try<String?>(() => d.website as String?),
      openingHours: _try<String?>(() => d.openingHours as String?),
      whatsapp: _try<String?>(() => d.whatsapp as String?),
      instagram: _try<String?>(() => d.instagram as String?),
      facebook: _try<String?>(() => d.facebook as String?),
      twitter: _try<String?>(() => d.twitter as String?),
      tiktok: _try<String?>(() => d.tiktok as String?),
      wheelchairAccessible: _try<bool?>(() => d.wheelchairAccessible as bool?),
      accessibleParking: _try<bool?>(() => d.accessibleParking as bool?),
      accessibleRestroom: _try<bool?>(() => d.accessibleRestroom as bool?),
      elevator: _try<bool?>(() => d.elevator as bool?),
      brailleMenu: _try<bool?>(() => d.brailleMenu as bool?),
      signLanguage: _try<bool?>(() => d.signLanguage as bool?),
      serviceAnimalsAllowed: _try<bool?>(() => d.serviceAnimalsAllowed as bool?),
      familyFriendly: _try<bool?>(() => d.familyFriendly as bool?),
      smokeFree: _try<bool?>(() => d.smokeFree as bool?),
      hearingLoop: _try<bool?>(() => d.hearingLoop as bool?),
      highContrast: _try<bool?>(() => d.highContrast as bool?),
      largePrint: _try<bool?>(() => d.largePrint as bool?),
    );
  }

  final String title;
  final bool showTitle;
  final IconData titleIcon;

  // Contact
  final String? phone;
  final String? email;
  final String? website;
  final String? whatsapp; // e.g., "+919999999999" or "919999999999"
  final String? instagram; // profile URL or handle
  final String? facebook; // page URL
  final String? twitter; // profile URL or handle
  final String? tiktok; // profile URL or handle
  final String? openingHours;

  // Accessibility flags (nullable => hidden if null)
  final bool? wheelchairAccessible;
  final bool? accessibleParking;
  final bool? accessibleRestroom;
  final bool? elevator;
  final bool? brailleMenu;
  final bool? signLanguage;
  final bool? serviceAnimalsAllowed;
  final bool? familyFriendly;
  final bool? smokeFree;
  final bool? hearingLoop;
  final bool? highContrast;
  final bool? largePrint;

  @override
  Widget build(BuildContext context) {
    final actions = <_RowAction>[
      if (_nonEmpty(phone))
        _RowAction(Icons.call_outlined, 'Call', () => _launch(Uri(scheme: 'tel', path: _trim(phone))), semantic: 'Call phone'),
      if (_nonEmpty(email))
        _RowAction(Icons.mail_outline, 'Email', () => _openEmail(_trim(email)), semantic: 'Send email'),
      if (_nonEmpty(website))
        _RowAction(Icons.public_outlined, 'Website', () => _openWeb(_trim(website)), semantic: 'Open website'),
      if (_nonEmpty(whatsapp))
        _RowAction(Icons.chat_outlined, 'WhatsApp', () => _openWhatsApp(_trim(whatsapp)), semantic: 'Open WhatsApp'),
      if (_nonEmpty(instagram))
        _RowAction(Icons.camera_alt_outlined, 'Instagram', () => _openSocial(_trim(instagram), 'https://instagram.com/'),
            semantic: 'Open Instagram'),
      if (_nonEmpty(facebook))
        _RowAction(Icons.facebook_outlined, 'Facebook', () => _openSocial(_trim(facebook), 'https://facebook.com/'),
            semantic: 'Open Facebook'),
      if (_nonEmpty(twitter))
        _RowAction(Icons.alternate_email, 'Twitter', () => _openSocial(_trim(twitter), 'https://twitter.com/'),
            semantic: 'Open Twitter'),
      if (_nonEmpty(tiktok))
        _RowAction(Icons.movie_creation_outlined, 'TikTok', () => _openSocial(_trim(tiktok), 'https://tiktok.com/@'),
            semantic: 'Open TikTok'),
    ];

    final amenities = <_Amenity>[
      _Amenity(Icons.accessible, 'Wheelchair accessible', wheelchairAccessible),
      _Amenity(Icons.local_parking_outlined, 'Accessible parking', accessibleParking),
      _Amenity(Icons.wc_outlined, 'Accessible restroom', accessibleRestroom),
      _Amenity(Icons.elevator_outlined, 'Elevator', elevator),
      _Amenity(Icons.menu_book_outlined, 'Braille menu', brailleMenu),
      _Amenity(Icons.sign_language_outlined, 'Sign language support', signLanguage),
      _Amenity(Icons.pets_outlined, 'Service animals allowed', serviceAnimalsAllowed),
      _Amenity(Icons.family_restroom_outlined, 'Family-friendly', familyFriendly),
      _Amenity(Icons.smoke_free, 'Smoke-free', smokeFree),
      _Amenity(Icons.hearing_disabled_outlined, 'Hearing loop', hearingLoop),
      _Amenity(Icons.contrast_outlined, 'High contrast materials', highContrast),
      _Amenity(Icons.article_outlined, 'Large print materials', largePrint),
    ].where((a) => a.value != null).toList(growable: false);

    if (actions.isEmpty && amenities.isEmpty && !_nonEmpty(openingHours)) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(titleIcon),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            if (_nonEmpty(openingHours))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Hours'),
                subtitle: Text(openingHours!.trim()),
              ),
            if (actions.isNotEmpty)
              ...actions.map(
                (a) => Semantics(
                  label: a.semantic,
                  button: true,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a.icon),
                    title: Text(a.label),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: a.onTap,
                  ),
                ),
              ),
            if (amenities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Accessibility', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: amenities.map((a) {
                  final on = a.value == true;
                  return InputChip(
                    avatar: Icon(a.icon, size: 16, color: on ? Colors.green : Colors.black45),
                    label: Text(a.label),
                    selected: on,
                    onSelected: null,
                  );
                }).toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------- helpers ---------------

  bool _nonEmpty(String? s) => (s ?? '').trim().isNotEmpty;
  String _trim(String? s) => (s ?? '').trim();

  Future<void> _openEmail(String to) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: const {
        // Add defaults if desired.
      },
    );
    await _launch(uri);
  }

  Future<void> _openWeb(String raw) async {
    final url = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'https://$raw';
    await _launch(Uri.parse(url));
  }

  Future<void> _openWhatsApp(String msisdn) async {
    final digits = msisdn.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    await _launch(uri);
  }

  Future<void> _openSocial(String input, String base) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      await _launch(Uri.parse(input));
      return;
    }
    final handle = input.startsWith('@') ? input.substring(1) : input;
    await _launch(Uri.parse('$base$handle'));
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(
      uri,
      mode: uri.scheme.startsWith('http') ? LaunchMode.externalApplication : LaunchMode.platformDefault,
    );
    if (!ok) {
      // Optionally surface a toast/snackbar from caller if needed.
    }
  }
}

class _RowAction {
  const _RowAction(this.icon, this.label, this.onTap, {required this.semantic});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String semantic;
}

class _Amenity {
  const _Amenity(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final bool? value;
}
