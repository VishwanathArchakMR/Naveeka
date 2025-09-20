// lib/features/quick_actions/presentation/planning/widgets/invite_friends.dart

import 'package:flutter/material.dart';

/// Lightweight contact model for inviting.
class FriendContact {
  const FriendContact({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.source = ContactSource.onApp, // onApp | contacts | email
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final ContactSource source;
}

enum ContactSource { onApp, contacts, email }

extension _ContactSourceLabel on ContactSource {
  String get label {
    switch (this) {
      case ContactSource.onApp:
        return 'On app';
      case ContactSource.contacts:
        return 'Contacts';
      case ContactSource.email:
        return 'Email';
    }
  }

  IconData get icon {
    switch (this) {
      case ContactSource.onApp:
        return Icons.person_outline;
      case ContactSource.contacts:
        return Icons.contacts_outlined;
      case ContactSource.email:
        return Icons.alternate_email;
    }
  }
}

/// Small card with an action to open the Invite Friends sheet.
class InviteFriendsCard extends StatelessWidget {
  const InviteFriendsCard({
    super.key,
    required this.suggested,
    this.loading = false,
    this.onOpen,
  });

  /// Short curated list to show inline (top 3-6 suggestions).
  final List<FriendContact> suggested;
  final bool loading;

  /// Optional callback when "Invite" is pressed (to track analytics).
  final VoidCallback? onOpen;

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
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text('Invite friends', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Inline suggestions (avatars)
            if (suggested.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggested.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = suggested[i];
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black12,
                          backgroundImage:
                              (c.avatarUrl != null && c.avatarUrl!.trim().isNotEmpty) ? NetworkImage(c.avatarUrl!) : null,
                          child: (c.avatarUrl == null || c.avatarUrl!.trim().isEmpty)
                              ? Text(
                                  c.name.isEmpty ? '?' : c.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            // Open sheet
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  onOpen?.call();
                  if (!context.mounted) return;
                  await InviteFriendsSheet.show(context);
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded modal sheet: search, filter, multi-select contacts, copy/share link, send invites.
class InviteFriendsSheet extends StatefulWidget {
  const InviteFriendsSheet({
    super.key,
    this.initialContacts = const <FriendContact>[],
    this.loading = false,
    this.hasMore = false,
    this.onRefresh,
    this.onLoadMore,
    this.onSendInvites, // Future<void> Function(List<FriendContact> selected)
    this.onCopyLink, // Future<void> Function()
    this.onShareLink, // Future<void> Function()
  });

  final List<FriendContact> initialContacts;
  final bool loading;
  final bool hasMore;

  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;

  final Future<void> Function(List<FriendContact> selected)? onSendInvites;
  final Future<void> Function()? onCopyLink;
  final Future<void> Function()? onShareLink;

  static Future<void> show(
    BuildContext context, {
    List<FriendContact> initialContacts = const <FriendContact>[],
    bool loading = false,
    bool hasMore = false,
    Future<void> Function()? onRefresh,
    Future<void> Function()? onLoadMore,
    Future<void> Function(List<FriendContact> selected)? onSendInvites,
    Future<void> Function()? onCopyLink,
    Future<void> Function()? onShareLink,
  }) {
    // Present as a rounded modal bottom sheet; useSafeArea handles cutouts. [1][3]
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: InviteFriendsSheet(
          initialContacts: initialContacts,
          loading: loading,
          hasMore: hasMore,
          onRefresh: onRefresh,
          onLoadMore: onLoadMore,
          onSendInvites: onSendInvites,
          onCopyLink: onCopyLink,
          onShareLink: onShareLink,
        ),
      ),
    );
  }

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  final TextEditingController _q = TextEditingController();
  final ScrollController _scroll = ScrollController();

  ContactSource? _filter; // null = all
  late List<FriendContact> _items;
  final Set<String> _selected = <String>{};

  bool _busySend = false;
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _items = [...widget.initialContacts];
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _q.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Infinite pagination triggers near the end of the list and pairs well with ListView.separated. [2]

  List<FriendContact> _applyFilters() {
    final q = _q.text.trim().toLowerCase();
    return _items.where((c) {
      final matchesText = q.isEmpty || c.name.toLowerCase().contains(q) || (c.username ?? '').toLowerCase().contains(q);
      final matchesSrc = _filter == null || c.source == _filter;
      return matchesText && matchesSrc;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _applyFilters();

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Invite friends', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or @username',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surface.withValues(alpha: 1.0),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Filter chips (single-choice)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SourceChips(
                selected: _filter,
                onChanged: (s) => setState(() => _filter = s),
              ),
            ), // ChoiceChip provides compact single-selection filters for source. [4]

            const SizedBox(height: 8),

            // Selected pills bar
            if (_selected.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final id = _selected.elementAt(i);
                    final c = _items.firstWhere((e) => e.id == id, orElse: () => const FriendContact(id: '', name: ''));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.name, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _selected.remove(id)),
                            customBorder: const CircleBorder(),
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 6),

            // List
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: () async {
                  if (widget.onRefresh != null) await widget.onRefresh!();
                },
                child: ListView.separated(
                  controller: _scroll,
                  itemCount: filtered.length + 1,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    if (i == filtered.length) {
                      if (widget.loading && widget.hasMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      if (!widget.hasMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No more contacts')),
                        );
                      }
                      return const SizedBox(height: 24);
                    }

                    final c = filtered[i];
                    final isSel = _selected.contains(c.id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black12,
                        backgroundImage:
                            (c.avatarUrl != null && c.avatarUrl!.trim().isNotEmpty) ? NetworkImage(c.avatarUrl!) : null,
                        child: (c.avatarUrl == null || c.avatarUrl!.trim().isEmpty)
                            ? Text(c.name.isEmpty ? '?' : c.name.toUpperCase(), style: const TextStyle(fontSize: 12))
                            : null,
                      ),
                      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Row(
                        children: [
                          Icon(c.source.icon, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            c.username?.trim().isNotEmpty == true ? '@${c.username!.trim()}' : c.source.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      trailing: isSel
                          ? OutlinedButton(
                              onPressed: () => setState(() => _selected.remove(c.id)),
                              child: const Text('Added'),
                            )
                          : FilledButton(
                              onPressed: () => setState(() => _selected.add(c.id)),
                              child: const Text('Add'),
                            ),
                      onTap: () => setState(() => isSel ? _selected.remove(c.id) : _selected.add(c.id)),
                    );
                  },
                ),
              ),
            ), // RefreshIndicator.adaptive wraps the list for platform-appropriate pull-to-refresh behavior. [5]

            // Footer: copy/share link + send invites
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onCopyLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Copy link'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onShareLink,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty || widget.onSendInvites == null || _busySend
                        ? null
                        : () async {
                            setState(() => _busySend = true);
                            try {
                              final sel = _items.where((e) => _selected.contains(e.id)).toList();
                              await widget.onSendInvites!(sel);

                              // Guard the captured BuildContext after await
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invited ${sel.length} ${sel.length == 1 ? 'friend' : 'friends'}')),
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context);
                            } finally {
                              if (mounted) setState(() => _busySend = false);
                            }
                          },
                    icon: _busySend
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_selected.isEmpty ? 'Invite' : 'Invite ${_selected.length}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.selected, required this.onChanged});

  final ContactSource? selected; // null = all
  final ValueChanged<ContactSource?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = <(ContactSource?, String, IconData)>[
      (null, 'All', Icons.filter_alt_outlined),
      (ContactSource.onApp, ContactSource.onApp.label, ContactSource.onApp.icon),
      (ContactSource.contacts, ContactSource.contacts.label, ContactSource.contacts.icon),
      (ContactSource.email, ContactSource.email.label, ContactSource.email.icon),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all.map((t) {
        final isOn = selected == t.$1;
        final fg = isOn ? cs.primary : cs.onSurface;
        return ChoiceChip(
          avatar: Icon(t.$3, size: 16, color: fg),
          label: Text(t.$2, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
          selected: isOn,
          onSelected: (_) => onChanged(t.$1),
          selectedColor: cs.primary.withValues(alpha: 0.18),
          backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: isOn ? cs.primary : cs.outlineVariant),
        );
      }).toList(growable: false),
    ); // ChoiceChip is a Material single-choice chip suitable for simple filters. [4][6]
  }
}
