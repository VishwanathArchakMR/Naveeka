// lib/features/wishlist/presentation/wishlist_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Corrected import path to the providers file located alongside "presentation" at ../providers
import '../providers/wishlist_providers.dart';
import '../../../models/place.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load once when the screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(wishlistProvider);
      if (!state.initialized && !state.loading) {
        ref.read(wishlistProvider.notifier).load();
      }
    });
  }

  Future<void> _refresh() => ref.read(wishlistProvider.notifier).load(refresh: true);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(wishlistProvider.notifier).load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Loading grid skeleton
          if (state.loading && state.items.isEmpty) {
            return const _SkeletonGrid(
              itemCount: 6,
            );
          }

          // Error state with retry
          if (state.error != null && state.items.isEmpty) {
            return _ErrorState(
              message: state.error!,
              onRetry: _refresh,
            );
          }

          // Empty state
          if (state.items.isEmpty) {
            return const _EmptyWishlist();
          }

          // Content
          return RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _maxTileWidth(context),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final place = state.items[i];
                return _WishlistCard(
                  place: place,
                  onOpen: () => context.go('/places/${place.id}'),
                  onRemove: () async {
                    // Guard BuildContext across async gap: capture messenger before await, then check mounted. [web:6182][web:6183]
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref.read(wishlistProvider.notifier).remove(place.id);
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(ok ? 'Removed from wishlist' : "Couldn't remove from wishlist")),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      backgroundColor: cs.surface,
    );
  }

  // Keep card width comfortable across phones/tablets
  double _maxTileWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 360;
    if (w >= 900) return 340;
    if (w >= 600) return 320;
    return 300;
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.place,
    required this.onOpen,
    required this.onRemove,
  });

  final Place place;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover area (placeholder when no image URL available)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.photo_outlined, color: cs.onSurfaceVariant, size: 32),
                    ),
                  ),
                  // Top-right remove button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Name
              Text(
                place.name, // assume non-nullable name field
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),

              const SizedBox(height: 6),

              // Secondary line (ID for now; replace with category or location if available in Place)
              Text(
                'ID: ${place.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxTileWidth(context),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: itemCount,
      itemBuilder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // image block
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 10),
              // title line
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              // subtitle line
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _maxTileWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 360;
    if (w >= 900) return 340;
    if (w >= 600) return 320;
    return 300;
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 72, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Your wishlist is empty',
              style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add places you love and find them here later.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 28),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
