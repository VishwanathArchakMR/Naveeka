import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/glass_card.dart';
import '../../../ui/components/emotion_chip.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/components/media/gallery_carousel.dart';
import '../../../ui/components/media/ambient_audio_title.dart';
import '../../wishlist/data/wishlist_api.dart';
import '../providers/places_providers.dart';

class PlaceDetailScreen extends ConsumerWidget {
  final String placeId;
  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeDetailProvider);
    final notifier = ref.read(placeDetailProvider.notifier);

    // Load place data on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.place == null && !state.loading) {
        notifier.loadPlace(placeId);
      }
    });

    if (state.loading && state.place == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.place == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => notifier.loadPlace(placeId),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (state.place == null) {
      return const Scaffold(
        body: Center(child: Text('Place not found')),
      );
    }

    // Use non-null after prior checks
    final place = state.place!;
    final emotion = place.emotion ?? EmotionKind.peaceful;
    final theme = EmotionTheme.of(emotion);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero + wishlist icon + approved badge
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                place.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: place.coverImage ?? '',
                    fit: BoxFit.cover,
                  ),
                  if (place.isApproved)
                    Positioned(
                      top: 40,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Approved by SoulTrail',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: GestureDetector(
                      onTap: () async {
                        final wishApi = WishlistApi();
                        // Capture messenger BEFORE async work to avoid using context after awaits
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          if (place.isWishlisted) {
                            await wishApi.remove(place.id);
                          } else {
                            await wishApi.add(place.id);
                          }
                          // Optimistic UI update
                          notifier.updateWishlist(!place.isWishlisted);
                        } catch (_) {
                          // Use captured messenger; no context access across async gap
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Couldn't update wishlist"),
                            ),
                          );
                        }
                      },
                      child: Icon(
                        place.isWishlisted
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 28,
                        color: place.isWishlisted
                            ? Colors.pinkAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: theme.accent,
          ),

          // DETAILS
          SliverList(
            delegate: SliverChildListDelegate([
              // Gallery
              if (place.gallery.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: GalleryCarousel(
                    images: place.gallery,
                    emotion: place.emotion,
                  ),
                ),
              ],

              // Emotion & Category chips
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    EmotionChip(emotion: emotion, selected: true, onTap: () {}),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        place.category ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    place.description ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Ambient audio preview
              if (place.ambientAudio != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AmbientAudioTile(
                    audioUrl: place.ambientAudio!,
                    title: 'Ambient Sound',
                    emotion: place.emotion,
                  ),
                ),

              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }
}
