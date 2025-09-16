import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/theme.dart';

class GalleryCarousel extends StatefulWidget {
  final List<String> images;
  final EmotionKind? emotion; // Optional accent for indicators
  final double height;
  final BorderRadius borderRadius;

  const GalleryCarousel({
    super.key,
    required this.images,
    this.emotion,
    this.height = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<GalleryCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  late EmotionTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.emotion != null
        ? EmotionTheme.of(widget.emotion!)
        : EmotionTheme.of(EmotionKind.peaceful);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Convert url to a stable hero-safe tag
  String _heroTagFor(String url, int index) {
    // Keep only safe chars and append index to ensure uniqueness
    final safe = url.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    return 'gallery_${safe}_$index';
  }

  void _openFullscreen(int startIndex) async {
    // Enter immersive mode
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;

    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _FullScreenGallery(
        images: widget.images,
        startIndex: startIndex,
        emotion: widget.emotion,
        tagBuilder: _heroTagFor,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));

    // Restore overlays on return
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: const Center(
          child: Text('No images available',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              final image = widget.images[i];
              final tag = _heroTagFor(image, i);

              return GestureDetector(
                onTap: () => _openFullscreen(i),
                child: Hero(
                  tag: tag,
                  flightShuttleBuilder: (ctx, anim, dir, from, to) {
                    // Smooth scale during flight
                    return ScaleTransition(
                      scale: Tween(begin: 0.98, end: 1.0).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      ),
                      child: to.widget,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: widget.borderRadius,
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.white12,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white38),
                      ),
                    ),
                  ),
                ),
              ).animate().scale(
                    begin: const Offset(0.98, 0.98),
                    end: const Offset(1, 1),
                    duration: 260.ms,
                    curve: Curves.easeOut,
                  );
            },
          ),
        ),
        const SizedBox(height: 10),
        _Indicators(
          count: widget.images.length,
          current: _currentIndex,
          color: _theme.accent,
        ),
      ],
    );
  }
}

class _Indicators extends StatelessWidget {
  final int count;
  final int current;
  final Color color;

  const _Indicators({
    required this.count,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = current == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 8,
          width: selected ? 20 : 8,
          decoration: BoxDecoration(
            color: selected ? color : Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

// -----------------------------
// Fullscreen image viewer
// -----------------------------
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int startIndex;
  final EmotionKind? emotion;
  final String Function(String, int) tagBuilder;

  const _FullScreenGallery({
    required this.images,
    required this.startIndex,
    required this.tagBuilder,
    this.emotion,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _index;
  late EmotionTheme _theme;

  // One TransformationController per page to track scale and pan
  final Map<int, TransformationController> _controllers = {};
  bool _pagingEnabled = true;
  double _verticalDrag = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, max(0, widget.images.length - 1));
    _pageController = PageController(initialPage: _index);
    _theme = widget.emotion != null
        ? EmotionTheme.of(widget.emotion!)
        : EmotionTheme.of(EmotionKind.peaceful);
  }

  TransformationController _controllerFor(int i) {
    return _controllers.putIfAbsent(i, () => TransformationController());
  }

  void _onInteractionEnd(int i) {
    final ctrl = _controllerFor(i);
    final scale = ctrl.value.getMaxScaleOnAxis();
    setState(() {
      // Disable page swiping when zoomed in; enable when back to 1.0
      _pagingEnabled = scale <= 1.0 + 1e-3;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final physics = _pagingEnabled
        ? const PageScrollPhysics()
        : const NeverScrollableScrollPhysics();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (d) {
          _verticalDrag += d.primaryDelta ?? 0;
          // Subtle translate effect while dragging down
          setState(() {});
        },
        onVerticalDragEnd: (_) {
          if (_verticalDrag > 120) {
            Navigator.pop(context);
          } else {
            _verticalDrag = 0;
            setState(() {});
          }
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.identity()
                ..translateByDouble(
                  0.0,
                  _verticalDrag.clamp(0, 160).toDouble(),
                  0.0,
                  0.0,
                ),
              child: PageView.builder(
                physics: physics,
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.images.length,
                itemBuilder: (context, i) {
                  final img = widget.images[i];
                  final tag = widget.tagBuilder(img, i);
                  final tc = _controllerFor(i);
                  return Center(
                    child: Hero(
                      tag: tag,
                      child: InteractiveViewer(
                        transformationController: tc,
                        minScale: 1.0,
                        maxScale: 5.0,
                        clipBehavior: Clip.none,
                        onInteractionEnd: (_) => _onInteractionEnd(i),
                        child: CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 40),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 40,
              child: _Indicators(
                count: widget.images.length,
                current: _index,
                color: _theme.accent,
              ),
            ),
            Positioned(
              top: 44,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
