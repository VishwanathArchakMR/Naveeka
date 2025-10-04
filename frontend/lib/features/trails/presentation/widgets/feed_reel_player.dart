// lib/features/trails/presentation/widgets/feed_reel_player.dart

import 'dart:async';
import 'dart:ui' as ui; // <-- add this
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FeedReelPlayer extends StatefulWidget {
  const FeedReelPlayer({
    super.key,
    required this.url,
    this.autoplay = true,
    this.loop = true,
    this.mutedOnStart = true,
    this.aspectRatio, // if null, uses video aspect after init; fallback 9/16 for reels
    this.showControls = false, // minimal UI; keep false for immersive feed
    this.cornerRadius = 16,
    this.onReady,
    this.onError,
  });

  final String url;
  final bool autoplay;
  final bool loop;
  final bool mutedOnStart;
  final double? aspectRatio;
  final bool showControls;
  final double cornerRadius;
  final VoidCallback? onReady;
  final void Function(Object error)? onError;

  @override
  State<FeedReelPlayer> createState() => _FeedReelPlayerState();
}

class _FeedReelPlayerState extends State<FeedReelPlayer> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _visible = false;
  bool _muted = true;
  StreamSubscription<void>? _ticker;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _muted = widget.mutedOnStart || kIsWeb; // web: keep muted to satisfy autoplay policies
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();

      // Configure looping and audio
      await c.setLooping(widget.loop);
      if (_muted) {
        await c.setVolume(0.0);
      } else {
        await c.setVolume(1.0);
      }

      setState(() => _ready = true);
      widget.onReady?.call();

      // Autoplay only when visible to avoid wasted decode
      if (widget.autoplay && _visible) {
        unawaited(c.play());
      }

      // Attach a lightweight heartbeat to recover play if platform pauses
      _ticker = Stream<void>.periodic(const Duration(seconds: 5)).listen((_) {
        final ctrl = _controller;
        if (ctrl == null || !_ready) return;
        if (_visible && widget.autoplay && !ctrl.value.isPlaying) {
          unawaited(ctrl.play());
        }
      });
    } catch (e) {
      widget.onError?.call(e);
      if (mounted) {
        setState(() {
          _ready = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    _visible = info.visibleFraction >= 0.6; // play when at least 60% visible
    final c = _controller;
    if (c == null || !_ready) return;
    if (_visible && widget.autoplay) {
      unawaited(c.play());
    } else {
      unawaited(c.pause());
    }
  }

  void _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0.0 : 1.0);
    if (mounted) setState(() {});
  }

  void _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    final ar = widget.aspectRatio ??
        (_controller?.value.isInitialized == true ? _controller!.value.aspectRatio : (9 / 16));

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: VisibilityDetector(
        key: ValueKey('feed-reel-${widget.url}'),
        onVisibilityChanged: _onVisibility,
        child: AspectRatio(
          aspectRatio: ar,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or placeholder
              if (_ready && _controller != null)
                VideoPlayer(_controller!)
              else
                Container(
                  color: scheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // Minimal controls (optional)
              if (widget.showControls)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _RoundIconButton(
                        icon: _muted ? Icons.volume_off : Icons.volume_up,
                        onTap: _toggleMute,
                      ),
                      const SizedBox(height: 8),
                      _RoundIconButton(
                        icon: _controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
                        onTap: _togglePlay,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.28),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
