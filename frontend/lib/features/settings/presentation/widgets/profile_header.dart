// lib/features/settings/presentation/widgets/profile_header.dart

import 'package:flutter/material.dart';

/// A compact, editable profile header for the Settings screen:
/// - Circular avatar with tap-to-change action sheet (camera/gallery/remove)
/// - Display name and handle/email
/// - Optional verification badge and counters (followers/following/favorites)
/// - Uses Color.withValues (no withOpacity) and const where possible
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    this.handleOrEmail,
    this.avatarUrl,
    this.verified = false,

    // Optional counters row
    this.followersCount,
    this.followingCount,
    this.favoritesCount,

    // Actions
    this.onEditProfile, // VoidCallback
    this.onOpenFollowers, // VoidCallback
    this.onOpenFollowing, // VoidCallback
    this.onOpenFavorites, // VoidCallback

    // Photo changes (provided by host to perform actual picking)
    this.onPickFromCamera, // Future<void> Function()
    this.onPickFromGallery, // Future<void> Function()
    this.onRemovePhoto, // Future<void> Function()
  });

  final String displayName;
  final String? handleOrEmail;
  final String? avatarUrl;
  final bool verified;

  final int? followersCount;
  final int? followingCount;
  final int? favoritesCount;

  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenFollowers;
  final VoidCallback? onOpenFollowing;
  final VoidCallback? onOpenFavorites;

  final Future<void> Function()? onPickFromCamera;
  final Future<void> Function()? onPickFromGallery;
  final Future<void> Function()? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + edit button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(
                  avatarUrl: avatarUrl,
                  onTap: (onPickFromCamera != null || onPickFromGallery != null || onRemovePhoto != null)
                      ? () => _openChangePhotoSheet(context)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NameBlock(
                    displayName: displayName,
                    handleOrEmail: handleOrEmail,
                    verified: verified,
                  ),
                ),
                const SizedBox(width: 8),
                if (onEditProfile != null)
                  OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Counters row (optional)
            if ((followersCount ?? 0) + (followingCount ?? 0) + (favoritesCount ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (followingCount != null)
                      _Counter(
                        label: 'Following',
                        count: followingCount!,
                        onTap: onOpenFollowing,
                      ),
                    if (followersCount != null)
                      _Counter(
                        label: 'Followers',
                        count: followersCount!,
                        onTap: onOpenFollowers,
                      ),
                    if (favoritesCount != null)
                      _Counter(
                        label: 'Favorites',
                        count: favoritesCount!,
                        onTap: onOpenFavorites,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openChangePhotoSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Change photo', style: TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 6),
              if (onPickFromCamera != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () async {
                    await onPickFromCamera!.call();
                    if (context.mounted) Navigator.maybePop(context);
                  },
                ),
              if (onPickFromGallery != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () async {
                    await onPickFromGallery!.call();
                    if (context.mounted) Navigator.maybePop(context);
                  },
                ),
              if (onRemovePhoto != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () async {
                    await onRemovePhoto!.call();
                    if (context.mounted) Navigator.maybePop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, this.onTap});
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final has = (avatarUrl ?? '').trim().isNotEmpty;

    final avatar = CircleAvatar(
      radius: 30,
      backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
      backgroundImage: has ? NetworkImage(avatarUrl!) : null,
      child: has
          ? null
          : Icon(Icons.person_outline, color: cs.onSurfaceVariant, size: 28),
    ); // CircleAvatar is the standard Material widget for user profile images/initials. [1][3]

    return Stack(
      children: [
        avatar,
        if (onTap != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: cs.primary.withValues(alpha: 1.0),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.displayName,
    required this.handleOrEmail,
    required this.verified,
  });

  final String displayName;
  final String? handleOrEmail;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            if (verified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: cs.primary, size: 16),
                    const SizedBox(width: 4),
                    Text('Verified', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
        if ((handleOrEmail ?? '').trim().isNotEmpty)
          Text(
            handleOrEmail!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.count, this.onTap});

  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              Text(
                _format(count),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
