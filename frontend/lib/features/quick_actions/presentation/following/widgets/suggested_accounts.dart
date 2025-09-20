// lib/features/quick_actions/presentation/following/widgets/suggested_accounts.dart

import 'dart:async';
import 'package:flutter/material.dart';

class SuggestedAccount {
  const SuggestedAccount({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.headline,
    this.verified = false,
    this.isFollowing = false,
    this.mutualCount = 0,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? headline;
  final bool verified;
  final bool isFollowing;
  final int mutualCount;

  SuggestedAccount copyWith({
    bool? isFollowing,
  }) {
    return SuggestedAccount(
      id: id,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      headline: headline,
      verified: verified,
      isFollowing: isFollowing ?? this.isFollowing,
      mutualCount: mutualCount,
    );
  }
}

class SuggestedAccounts extends StatefulWidget {
  const SuggestedAccounts({
    super.key,
    required this.items,
    this.loading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.onOpenProfile,
    this.onToggleFollow, // Future<bool> Function(SuggestedAccount acc, bool next)
    this.onSeeAll,
    this.sectionTitle = 'Suggested accounts',
    this.cardWidth = 280,
    this.height = 180,
  });

  final List<SuggestedAccount> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function()? onLoadMore;

  final void Function(SuggestedAccount acc)? onOpenProfile;
  final Future<bool> Function(SuggestedAccount acc, bool next)? onToggleFollow;

  final VoidCallback? onSeeAll;

  final String sectionTitle;
  final double cardWidth;
  final double height;

  @override
  State<SuggestedAccounts> createState() => _SuggestedAccountsState();
}

class _SuggestedAccountsState extends State<SuggestedAccounts> {
  final _scroll = ScrollController();
  bool _loadRequested = false;
  late List<SuggestedAccount> _local;

  @override
  void initState() {
    super.initState();
    _local = [...widget.items];
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant SuggestedAccounts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _local = [...widget.items];
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!.call().whenComplete(() => _loadRequested = false);
    }
  } // Horizontal ListView pagination triggers near the trailing edge for seamless loading.

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: widget.height + 56,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (widget.onSeeAll != null)
                    TextButton(
                      onPressed: widget.onSeeAll,
                      child: const Text('See all'),
                    ),
                  if (widget.loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),

            // Body
            SizedBox(
              height: widget.height,
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: _local.length + 1,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (context, i) {
                  if (i == _local.length) return _tail();
                  final acc = _local[i];
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 8 : 6, right: i == _local.length - 1 ? 8 : 6),
                    child: _AccountCard(
                      account: acc,
                      width: widget.cardWidth,
                      height: widget.height,
                      onOpen: widget.onOpenProfile,
                      onToggleFollow: widget.onToggleFollow == null
                          ? null
                          : (next) async {
                              final idx = _local.indexWhere((e) => e.id == acc.id);
                              if (idx != -1) {
                                setState(() => _local[idx] = _local[idx].copyWith(isFollowing: next));
                              }
                              final ok = await widget.onToggleFollow!(acc, next);
                              if (!ok) {
                                if (idx != -1 && mounted) {
                                  setState(() => _local[idx] = _local[idx].copyWith(isFollowing: !next));
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not update follow')),
                                );
                              }
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tail() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Text('· end ·')),
      );
    }
    return const SizedBox(width: 24);
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.account,
    required this.width,
    required this.height,
    this.onOpen,
    this.onToggleFollow,
  });

  final SuggestedAccount account;
  final double width;
  final double height;
  final void Function(SuggestedAccount acc)? onOpen;
  final Future<void> Function(bool next)? onToggleFollow;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _busy = false;
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.account.isFollowing;
  }

  @override
  void didUpdateWidget(covariant _AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.isFollowing != widget.account.isFollowing) {
      _following = widget.account.isFollowing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              _Avatar(name: widget.account.name, url: widget.account.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: widget.onOpen == null ? null : () => widget.onOpen!(widget.account),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + verified
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (widget.account.verified) const Icon(Icons.verified, size: 18, color: Colors.blue),
                        ],
                      ),
                      // Username
                      if ((widget.account.username ?? '').trim().isNotEmpty)
                        Text(
                          '@${widget.account.username!.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      // Headline
                      if ((widget.account.headline ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.account.headline!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const Spacer(),
                      // Mutuals chip
                      if (widget.account.mutualCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${widget.account.mutualCount} mutual${widget.account.mutualCount == 1 ? '' : 's'}',
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Follow / Following button
              SizedBox(
                width: 112,
                child: _following
                    ? OutlinedButton(
                        onPressed: _busy || widget.onToggleFollow == null
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _following = false;
                                });
                                try {
                                  await widget.onToggleFollow!.call(false);
                                } catch (_) {
                                  // revert on any thrown error
                                  if (mounted) _following = true;
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: _busy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Following'),
                      )
                    : ElevatedButton(
                        onPressed: _busy || widget.onToggleFollow == null
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _following = true;
                                });
                                try {
                                  await widget.onToggleFollow!.call(true);
                                } catch (_) {
                                  if (mounted) _following = false;
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: _busy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Follow'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.black12,
      backgroundImage: (url != null && url!.trim().isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.trim().isEmpty)
          ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase())
          : null,
    );
  }
}
