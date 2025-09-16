// lib/ui/components/cards/trip_group_card.dart

import 'package:flutter/material.dart';

/// Lightweight UI view model to keep this card decoupled from data layer models.
/// Map your TripGroup domain object into this in your feature layer.
class TripGroupViewData {
  const TripGroupViewData({
    required this.id,
    required this.name,
    this.coverImageUrl,
    this.description,
    this.startDate,
    this.endDate,
    this.datesLabel,        // e.g., "12–18 Sep 2025 (6d)"
    this.dayCount,
    this.status,            // planning | active | completed | archived | canceled
    this.visibility,        // private | friends | public
    this.destinations = const <String>[],
    this.memberAvatarUrls = const <String>[],
    this.memberCount = 0,
    this.tags = const <String>[],
    this.pendingInvites = 0,
  });

  final String id;
  final String name;
  final String? coverImageUrl;
  final String? description;

  final DateTime? startDate;
  final DateTime? endDate;
  final String? datesLabel;
  final int? dayCount;

  final String? status;       // use TripStatus.name if available
  final String? visibility;   // use TripVisibility.name if available

  final List<String> destinations;
  final List<String> memberAvatarUrls;
  final int memberCount;
  final List<String> tags;
  final int pendingInvites;
}

/// A Material 3 card for collaborative trip groups with cover, title/dates,
/// status/visibility chips, destinations, member avatars, tags, and actions.
class TripGroupCard extends StatelessWidget {
  const TripGroupCard({
    super.key,
    required this.data,
    this.onTap,
    this.onOpen,
    this.onInvite,
    this.onShare,
    this.dense = false,
    this.heroTag,
  });

  final TripGroupViewData data;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onInvite;
  final VoidCallback? onShare;
  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final border = BorderSide(color: cs.outlineVariant.withValues(alpha: 0.80));
    final radius = BorderRadius.circular(14);

    final Widget header = _Header(
      data: data,
      dense: dense,
      heroTag: heroTag,
    );

    final Widget info = _InfoRows(
      data: data,
      dense: dense,
    );

    final Widget members = _MembersRow(
      avatars: data.memberAvatarUrls,
      count: data.memberCount,
      pendingInvites: data.pendingInvites,
      dense: dense,
    );

    final Widget tags = _TagsWrap(tags: data.tags, dense: dense);

    final Widget actions = _ActionsRow(
      onOpen: onOpen,
      onInvite: onInvite,
      onShare: onShare,
      dense: dense,
    );

    final children = <Widget>[
      header,
      const SizedBox(height: 12),
      info,
      if (data.tags.isNotEmpty) SizedBox(height: dense ? 6 : 8),
      if (data.tags.isNotEmpty) tags,
      if (data.memberCount > 0 || data.pendingInvites > 0) SizedBox(height: dense ? 8 : 10),
      if (data.memberCount > 0 || data.pendingInvites > 0) members,
      if (onOpen != null || onInvite != null || onShare != null) SizedBox(height: dense ? 10 : 12),
      if (onOpen != null || onInvite != null || onShare != null) actions,
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius, side: border),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.dense, required this.heroTag});

  final TripGroupViewData data;
  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final title = Text(
      data.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (dense ? t.textTheme.titleSmall : t.textTheme.titleMedium)?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
    );

    final subtitleParts = <String>[];
    if (data.datesLabel != null && data.datesLabel!.trim().isNotEmpty) {
      subtitleParts.add(data.datesLabel!.trim());
    }
    if (data.dayCount != null && data.dayCount! > 0 && (data.datesLabel == null || !data.datesLabel!.contains('('))) {
      subtitleParts.add('${data.dayCount}d');
    }

    final subtitle = subtitleParts.isEmpty
        ? null
        : Text(
            subtitleParts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          );

    final chips = Row(
      children: <Widget>[
        if (data.status != null && data.status!.isNotEmpty)
          _Chip(
            label: _statusLabel(data.status!),
            icon: _statusIcon(data.status!),
            bg: _statusBg(context, data.status!),
            fg: _statusFg(context, data.status!),
            dense: dense,
          ),
        if (data.visibility != null && data.visibility!.isNotEmpty) ...[
          const SizedBox(width: 6),
          _Chip(
            label: _visibilityLabel(data.visibility!),
            icon: _visibilityIcon(data.visibility!),
            bg: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.90),
            fg: Theme.of(context).colorScheme.onSurfaceVariant,
            dense: dense,
          ),
        ],
      ],
    );

    final image = _Cover(coverUrl: data.coverImageUrl, dense: dense, heroTag: heroTag);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        image,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                subtitle,
              ],
              const SizedBox(height: 6),
              chips,
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'planning':
        return 'Planning';
      case 'active':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'archived':
        return 'Archived';
      case 'canceled':
        return 'Canceled';
      default:
        return s;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'planning':
        return Icons.fact_check_rounded;
      case 'active':
        return Icons.flight_takeoff_rounded;
      case 'completed':
        return Icons.celebration_rounded;
      case 'archived':
        return Icons.archive_rounded;
      case 'canceled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _statusBg(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    switch (s.toLowerCase()) {
      case 'planning':
        return cs.secondary.withValues(alpha: 0.16);
      case 'active':
        return cs.primary.withValues(alpha: 0.16);
      case 'completed':
        return cs.tertiary.withValues(alpha: 0.16);
      case 'archived':
        return cs.surfaceTint.withValues(alpha: 0.16);
      case 'canceled':
        return cs.error.withValues(alpha: 0.16);
      default:
        return cs.surfaceContainerHighest.withValues(alpha: 0.90);
    }
  }

  Color _statusFg(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    switch (s.toLowerCase()) {
      case 'planning':
        return cs.onSecondaryContainer;
      case 'active':
        return cs.onPrimaryContainer;
      case 'completed':
        return cs.onTertiaryContainer;
      case 'archived':
        return cs.onSurface;
      case 'canceled':
        return cs.onErrorContainer;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _visibilityLabel(String s) {
    switch (s.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'friends':
        return 'Friends';
      case 'private':
        return 'Private';
      default:
        return s;
    }
  }

  IconData _visibilityIcon(String s) {
    switch (s.toLowerCase()) {
      case 'public':
        return Icons.public_rounded;
      case 'friends':
        return Icons.group_rounded;
      case 'private':
        return Icons.lock_rounded;
      default:
        return Icons.visibility_rounded;
    }
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.coverUrl, required this.dense, required this.heroTag});

  final String? coverUrl;
  final bool dense;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final size = dense ? const Size(72, 60) : const Size(96, 72);
    final cs = Theme.of(context).colorScheme;

    final placeholder = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.landscape_rounded, color: cs.onSurfaceVariant),
    );

    final widget = (coverUrl == null || coverUrl!.trim().isEmpty)
        ? placeholder
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
            ),
          );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: widget);
    }
    return widget;
  }
}

class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.data, required this.dense});

  final TripGroupViewData data;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final List<Widget> rows = <Widget>[];

    if (data.destinations.isNotEmpty) {
      rows.add(Row(
        children: <Widget>[
          Icon(Icons.place_rounded, size: dense ? 14 : 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              data.destinations.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ));
    }

    if (data.description != null && data.description!.trim().isNotEmpty) {
      rows.add(SizedBox(height: dense ? 4 : 6));
      rows.add(Text(
        data.description!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: t.textTheme.bodySmall?.copyWith(color: cs.onSurface),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _MembersRow extends StatelessWidget {
  const _MembersRow({
    required this.avatars,
    required this.count,
    required this.pendingInvites,
    required this.dense,
  });

  final List<String> avatars;
  final int count;
  final int pendingInvites;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final double avatarSize = dense ? 24 : 28;

    final stack = SizedBox(
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(avatars.length.clamp(0, 5), (i) {
          final left = i * (avatarSize - 8);
          return Positioned(
            left: left.toDouble(),
            child: _Avatar(url: avatars[i], size: avatarSize),
          );
        }),
      ),
    );

    final moreCount = count - avatars.length;
    final moreChip = moreCount > 0
        ? Container(
            margin: EdgeInsets.only(left: (avatars.length.clamp(0, 5)) * (avatarSize - 8).toDouble()),
            padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              '+$moreCount',
              style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          )
        : const SizedBox.shrink();

    final invite = pendingInvites > 0
        ? Container(
            padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.mail_rounded, size: dense ? 14 : 16, color: cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  '$pendingInvites pending',
                  style: t.textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Row(
      children: <Widget>[
        stack,
        if (moreCount > 0) const SizedBox(width: 8),
        if (moreCount > 0) moreChip,
        if (pendingInvites > 0) const SizedBox(width: 8),
        if (pendingInvites > 0) invite,
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: size * 0.6, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _TagsWrap extends StatelessWidget {
  const _TagsWrap({required this.tags, required this.dense});

  final List<String> tags;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final padH = dense ? 6.0 : 8.0;
    final padV = dense ? 3.0 : 4.0;

    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((t) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            t,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.onOpen,
    required this.onInvite,
    required this.onShare,
    required this.dense,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onInvite;
  final VoidCallback? onShare;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final v = dense ? VisualDensity.compact : VisualDensity.standard;

    final actions = <Widget>[];
    if (onInvite != null) {
      actions.add(OutlinedButton.icon(
        onPressed: onInvite,
        style: OutlinedButton.styleFrom(visualDensity: v),
        icon: const Icon(Icons.person_add_rounded, size: 18),
        label: const Text('Invite'),
      ));
      actions.add(const SizedBox(width: 8));
    }
    if (onShare != null) {
      actions.add(OutlinedButton.icon(
        onPressed: onShare,
        style: OutlinedButton.styleFrom(visualDensity: v),
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: const Text('Share'),
      ));
      actions.add(const SizedBox(width: 8));
    }
    if (onOpen != null) {
      actions.add(FilledButton.tonalIcon(
        onPressed: onOpen,
        style: FilledButton.styleFrom(visualDensity: v),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('Open'),
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: actions);
  }
}
