// lib/features/profile/presentation/widgets/about_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// A lightweight profile model adapter (replace with your real model's fields).
class ProfileView {
  const ProfileView({
    required this.name,
    this.username,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.location,
    this.joinedOn, // DateTime?
    this.website,
    this.email,
    this.twitter,
    this.instagram,
    this.linkedin,
    this.github,
    this.skills = const <String>[],
    this.verified = false,
  });

  final String name;
  final String? username;
  final String? headline;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final DateTime? joinedOn;
  final String? website;
  final String? email;
  final String? twitter;
  final String? instagram;
  final String? linkedin;
  final String? github;
  final List<String> skills;
  final bool verified;
}

/// About section with avatar, name, headline, expandable bio, social/contact links,
/// location/joined rows, and optional skills chips.
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
    required this.profile,
    this.onEdit,
    this.showEdit = false,
    this.compact = false,
    this.sectionTitle = 'About',
  });

  final ProfileView profile;
  final VoidCallback? onEdit;
  final bool showEdit;
  final bool compact;
  final String sectionTitle;

  // Helper to construct from an app-specific User/Account model without coupling.
  // Example:
  // AboutSection.fromUser(user: myUser, ...) maps fields into ProfileView.
  factory AboutSection.fromUser({
    Key? key,
    required String name,
    String? username,
    String? headline,
    String? bio,
    String? avatarUrl,
    String? location,
    DateTime? joinedOn,
    String? website,
    String? email,
    String? twitter,
    String? instagram,
    String? linkedin,
    String? github,
    List<String> skills = const <String>[],
    bool verified = false,
    VoidCallback? onEdit,
    bool showEdit = false,
    bool compact = false,
    String sectionTitle = 'About',
  }) {
    return AboutSection(
      key: key,
      profile: ProfileView(
        name: name,
        username: username,
        headline: headline,
        bio: bio,
        avatarUrl: avatarUrl,
        location: location,
        joinedOn: joinedOn,
        website: website,
        email: email,
        twitter: twitter,
        instagram: instagram,
        linkedin: linkedin,
        github: github,
        skills: skills,
        verified: verified,
      ),
      onEdit: onEdit,
      showEdit: showEdit,
      compact: compact,
      sectionTitle: sectionTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final bio = (p.bio ?? '').trim();
    final hasBio = bio.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _Avatar(url: p.avatarUrl, size: compact ? 44 : 56),
                const SizedBox(width: 12),
                Expanded(
                  child: _TitleBlock(
                    name: p.name,
                    verified: p.verified,
                    username: p.username,
                    headline: p.headline,
                    onCopyHandle: () => _copy(context, '@${p.username}'),
                  ),
                ),
                if (showEdit && onEdit != null)
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
              ],
            ), // ListTile-like composition with leading avatar and trailing action follows Material patterns for profile headers. [1]

            const SizedBox(height: 12),

            // Bio
            if (hasBio)
              _ExpandableBio(text: bio),

            if (hasBio) const SizedBox(height: 8),

            // Social & contact row
            _SocialRow(
              website: p.website,
              email: p.email,
              twitter: p.twitter,
              instagram: p.instagram,
              linkedin: p.linkedin,
              github: p.github,
            ),

            // Location / Joined
            if ((p.location ?? '').trim().isNotEmpty || p.joinedOn != null) ...[
              const SizedBox(height: 8),
              if ((p.location ?? '').trim().isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(p.location!.trim()),
                ),
              if (p.joinedOn != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text('Joined ${_fmtDate(p.joinedOn!)}'),
                ),
            ], // ListTile rows provide accessible, aligned metadata presentation consistent with Material lists. [1]

            // Skills
            if (p.skills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Skills', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.skills
                    .where((s) => s.trim().isNotEmpty)
                    .map((s) => Chip(label: Text(s), visualDensity: VisualDensity.compact))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    // e.g., Sep 2025
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black12,
      backgroundImage: (url != null && url!.trim().isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.trim().isEmpty)
          ? Icon(Icons.person_outline, size: radius)
          : null,
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.name,
    required this.verified,
    this.username,
    this.headline,
    this.onCopyHandle,
  });

  final String name;
  final bool verified;
  final String? username;
  final String? headline;
  final VoidCallback? onCopyHandle;

  @override
  Widget build(BuildContext context) {
    final handle = (username ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            if (verified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Colors.lightBlue, size: 18),
            ],
          ],
        ),
        if (handle.isNotEmpty)
          Row(
            children: [
              Text('@$handle', style: const TextStyle(color: Colors.black54)),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                onPressed: onCopyHandle,
              ),
            ],
          ),
        if ((headline ?? '').trim().isNotEmpty)
          Text(headline!.trim(), style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}

class _ExpandableBio extends StatefulWidget {
  const _ExpandableBio({required this.text});
  final String text;

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> with TickerProviderStateMixin {
  bool _open = false;
  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: SelectionArea(
            child: Text(
              widget.text,
              maxLines: _open ? null : 4,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ), // AnimatedSize provides a smooth expand/collapse for the bio while SelectionArea allows text copying. [10]
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(_open ? 'Show less' : 'Show more'),
          ),
        ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    this.website,
    this.email,
    this.twitter,
    this.instagram,
    this.linkedin,
    this.github,
  });

  final String? website;
  final String? email;
  final String? twitter;
  final String? instagram;
  final String? linkedin;
  final String? github;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    void add(IconData icon, String? value, VoidCallback onTap) {
      if (value == null || value.trim().isEmpty) return;
      buttons.add(IconButton(
        tooltip: value,
        icon: Icon(icon),
        onPressed: onTap,
      ));
    }

    add(Icons.public_outlined, website, () => _launchWeb(website!.trim()));
    add(Icons.mail_outline, email, () => _launchEmail(email!.trim()));
    add(Icons.alternate_email, twitter, () => _launchSocial(twitter!.trim(), 'https://twitter.com/'));
    add(Icons.camera_alt_outlined, instagram, () => _launchSocial(instagram!.trim(), 'https://instagram.com/'));
    add(Icons.work_outline, linkedin, () => _launchSocial(linkedin!.trim(), 'https://www.linkedin.com/in/'));
    add(Icons.code, github, () => _launchSocial(github!.trim(), 'https://github.com/'));

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(children: buttons);
  }

  Future<void> _launchWeb(String raw) async {
    final url = raw.startsWith('http') ? raw : 'https://$raw';
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      // optionally handle failure
    }
  }

  Future<void> _launchEmail(String to) async {
    final uri = Uri(scheme: 'mailto', path: to);
    await launchUrl(uri);
  }

  Future<void> _launchSocial(String input, String base) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      await launchUrl(Uri.parse(input), mode: LaunchMode.externalApplication);
      return;
    }
    final handle = input.startsWith('@') ? input.substring(1) : input;
    await launchUrl(Uri.parse('$base$handle'), mode: LaunchMode.externalApplication);
  } // url_launcher opens http(s)/mailto schemes across platforms; fallbacks are handled by the OS/browser. [6][9]
}
