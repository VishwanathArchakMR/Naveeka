// lib/features/trails/presentation/widgets/suggested_travelers.dart

import 'package:flutter/material.dart';

class SuggestedTravelerItem {
  const SuggestedTravelerItem({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.mutualTrails = 0,
    this.mutualFriends = 0,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final int mutualTrails;
  final int mutualFriends;
}

class SuggestedTravelers extends StatelessWidget {
  const SuggestedTravelers({
    super.key,
    required this.items,
    this.title = 'Suggested travelers',
    this.onViewProfile, // void Function(String userId)
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 8),
    this.itemExtent = 220,
    this.spacing = 12,
    this.isFollowingOf, // bool Function(String userId)
    this.onToggleFollow, // Future<bool> Function(String userId, bool next)
  });

  final List<SuggestedTravelerItem> items;
  final String title;
  final void Function(String userId)? onViewProfile;
  final EdgeInsets padding;
  final double itemExtent;
  final double spacing;

  // Injectable follow state/toggle (no hard dependency on a specific provider name)
  final bool Function(String userId)? isFollowingOf;
  final Future<bool> Function(String userId, bool next)? onToggleFollow;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 6),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),

        // Horizontal list of traveler cards
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (context, i) {
              final it = items[i];
              final isFollowing = isFollowingOf?.call(it.userId) ?? false;
              final toggle = onToggleFollow ?? ((_, __) async => true);

              return _TravelerCard(
                width: itemExtent,
                item: it,
                isFollowing: isFollowing,
                onFollowToggle: () => toggle(it.userId, !isFollowing),
                onView: onViewProfile == null ? null : () => onViewProfile!(it.userId),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.width,
    required this.item,
    required this.isFollowing,
    required this.onFollowToggle,
    this.onView,
  });

  final double width;
  final SuggestedTravelerItem item;
  final bool isFollowing;
  final Future<bool> Function() onFollowToggle;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAvatar = (item.avatarUrl ?? '').trim().isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onView,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                  backgroundImage: hasAvatar ? NetworkImage(item.avatarUrl!) : null,
                  child: hasAvatar ? null : Icon(Icons.person_outline, color: cs.onSurfaceVariant, size: 24),
                ),

                const SizedBox(width: 10),

                // Texts + actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Display name
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      // Username / mutuals
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),

                      const SizedBox(height: 8),

                      // Follow / Following + View
                      Row(
                        children: [
                          _FollowButton(
                            isFollowing: isFollowing,
                            onPressed: onFollowToggle,
                          ),
                          const SizedBox(width: 8),
                          if (onView != null)
                            OutlinedButton(
                              onPressed: onView,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: cs.outlineVariant),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('View'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(SuggestedTravelerItem it) {
    final parts = <String>[];
    if ((it.username ?? '').isNotEmpty) parts.add('@${it.username}');
    if (it.mutualTrails > 0) parts.add('${it.mutualTrails} mutual trails');
    if (it.mutualFriends > 0) parts.add('${it.mutualFriends} mutual');
    return parts.isEmpty ? 'Traveler' : parts.join(' • ');
  }
}

class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.isFollowing, required this.onPressed});

  final bool isFollowing;
  final Future<bool> Function() onPressed;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = widget.isFollowing ? cs.surfaceContainerHigh.withValues(alpha: 1.0) : cs.primary.withValues(alpha: 1.0);
    final fg = widget.isFollowing ? cs.onSurface : cs.onPrimary.withValues(alpha: 1.0);
    final side = widget.isFollowing ? BorderSide(color: cs.outlineVariant) : BorderSide.none;

    return ElevatedButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onPressed.call();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        backgroundColor: bg,
        foregroundColor: fg,
        side: side,
        minimumSize: const Size(0, 36),
      ),
      child: _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.isFollowing ? Icons.check : Icons.person_add_alt_1, size: 16),
                const SizedBox(width: 6),
                Text(widget.isFollowing ? 'Following' : 'Follow'),
              ],
            ),
    );
  }
}
