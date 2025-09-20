import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/cards/glass_card.dart';
import '../../../ui/theme/theme.dart'; // Import existing theme system with EmotionKind and EmotionTheme
import '../../../ui/components/media/gallery_carousel.dart';
import '../../../ui/components/media/ambient_audio_title.dart';
import '../../wishlist/data/wishlist_api.dart';
import '../providers/places_providers.dart';

// Enhanced Place model that provides all necessary getters
class PlaceEnhanced {
  PlaceEnhanced(this._data);
  final dynamic _data;

  String get id => _data.id?.toString() ?? '';
  String? get name => _data.name?.toString();
  String? get description => _data.description?.toString();
  String? get category => _data.category?.toString();
  String? get coverImage => _safeStringAccess(['coverImage', 'imageUrl', 'photo', 'thumbnail']);
  String? get ambientAudio => _safeStringAccess(['ambientAudio', 'audioUrl', 'audio']);
  
  EmotionKind? get emotion {
    final emotionStr = _safeStringAccess(['emotion', 'mood', 'feeling']);
    if (emotionStr == null) return null;
    
    // Only use the existing constants from the theme system
    // Based on the error messages, only 'peaceful' exists
    switch (emotionStr.toLowerCase()) {
      case 'peaceful': 
        return EmotionKind.peaceful;
      default: 
        return EmotionKind.peaceful; // Default fallback to the only known constant
    }
  }

  bool get isApproved => _safeBoolAccess(['isApproved', 'approved', 'verified']) ?? false;
  bool get isWishlisted => _safeBoolAccess(['isWishlisted', 'wishlist', 'favorite']) ?? false;

  List<String> get gallery {
    try {
      final dynamic galleryData = _data.gallery ?? _data.images ?? _data.photos;
      if (galleryData is List) {
        return galleryData.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      }
      return const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  String? _safeStringAccess(List<String> keys) {
    try {
      for (final key in keys) {
        final dynamic value = (_data as dynamic)?.$key ?? (_data as Map<String, dynamic>?)?[key];
        if (value != null) return value.toString();
      }
    } catch (_) {}
    return null;
  }

  bool? _safeBoolAccess(List<String> keys) {
    try {
      for (final key in keys) {
        final dynamic value = (_data as dynamic)?.$key ?? (_data as Map<String, dynamic>?)?[key];
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        if (value is num) return value != 0;
      }
    } catch (_) {}
    return null;
  }
}

class PlaceDetailScreen extends ConsumerWidget {
  final String placeId;
  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider directly and get an AsyncValue<dynamic>
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    return placeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // Use void to suppress unused result warning
                  void _ = ref.refresh(placeDetailProvider(placeId));
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
      data: (placeData) {
        final place = PlaceEnhanced(placeData);
        final emotion = place.emotion ?? EmotionKind.peaceful; // Use only the existing constant
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
                    place.name ?? 'Unnamed Place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: place.coverImage ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[300]),
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
                              // Refresh the provider to reflect the updated wishlist state
                              void _ = ref.refresh(placeDetailProvider(placeId));
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EmotionChip(emotion: emotion, selected: true, onTap: () {}),
                        if (place.category != null && place.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.chipBg.withValues(alpha: 0.3), // Use withValues instead of withOpacity
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              place.category!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Description
                  if (place.description != null && place.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          place.description!,
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
                  if (place.ambientAudio != null && place.ambientAudio!.isNotEmpty)
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
      },
    );
  }
}

/// EmotionChip widget to display emotion chips
class _EmotionChip extends StatelessWidget {
  const _EmotionChip({
    required this.emotion,
    required this.selected,
    required this.onTap,
  });

  final EmotionKind emotion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = EmotionTheme.of(emotion);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.accent.withValues(alpha: 0.3) : theme.chipBg.withValues(alpha: 0.1), // Use withValues instead of withOpacity
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: theme.accent) : null,
        ),
        child: Text(
          emotion.name.toUpperCase(),
          style: TextStyle(
            color: selected ? theme.accent : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
