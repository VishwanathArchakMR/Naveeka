// lib/features/places/presentation/widgets/photo_gallery.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

/// A responsive gallery with:
/// - Grid of thumbnail images with rounded corners and Hero transitions
/// - Full-screen viewer using PageView (swipe) + InteractiveViewer (pinch/zoom)
/// - Optional fromPlace() factory to bind your Place model
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({
    super.key,
    required this.imageUrls,
    this.crossAxisCount = 3,
    this.spacing = 6,
    this.radius = 10,
    this.initialHeroPrefix = 'gallery',
    this.emptyPlaceholder,
    this.onOpenIndex,
  });

  /// Build the gallery from a Place model if it exposes a photos list (urls).
  factory PhotoGallery.fromPlace(
    Place place, {
    Key? key,
    int crossAxisCount = 3,
    double spacing = 6,
    double radius = 10,
    String initialHeroPrefix = 'gallery',
    Widget? emptyPlaceholder,
    void Function(int index)? onOpenIndex,
  }) {
    final urls = (place.photos ?? <String>[])
        .where((e) => (e).toString().trim().isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    return PhotoGallery(
      key: key,
      imageUrls: urls,
      crossAxisCount: crossAxisCount,
      spacing: spacing,
      radius: radius,
      initialHeroPrefix: initialHeroPrefix,
      emptyPlaceholder: emptyPlaceholder,
      onOpenIndex: onOpenIndex,
    );
  }

  final List<String> imageUrls;
  final int crossAxisCount;
  final double spacing;
  final double radius;
  final String initialHeroPrefix;

  /// Optional widget shown when imageUrls is empty.
  final Widget? emptyPlaceholder;

  /// Optional callback fired when a thumbnail opens the full-screen viewer.
  final void Function(int index)? onOpenIndex;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return emptyPlaceholder ?? const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, i) {
        final url = imageUrls[i];
        final tag = _heroTag(i);
        return _ThumbTile(
          url: url,
          radius: radius,
          heroTag: tag,
          onTap: () {
            onOpenIndex?.call(i);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _GalleryViewer(
                  urls: imageUrls,
                  initialIndex: i,
                  heroPrefix: initialHeroPrefix,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _heroTag(int index) => '$initialHeroPrefix-$index';
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.url,
    required this.radius,
    required this.heroTag,
    required this.onTap,
  });

  final String url;
  final double radius;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        child: Hero(
          tag: heroTag,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, prog) {
              if (prog == null) return child;
              return Container(
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({
    required this.urls,
    required this.initialIndex,
    required this.heroPrefix,
  });

  final List<String> urls;
  final int initialIndex;
  final String heroPrefix;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / $total'),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final url = widget.urls[i];
          final tag = '${widget.heroPrefix}-$i';
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: tag,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, prog) {
                    if (prog == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.white70),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
