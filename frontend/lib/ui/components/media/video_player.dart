// lib/ui/components/media/video_player.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A flexible Material 3 video player with custom controls:
/// - Works with an external VideoPlayerController or creates its own from a URL/asset
/// - Control overlay: play/pause, scrubber with buffered preview, time labels, mute, speed, fullscreen
/// - Uses surfaceContainerHighest and Color.withValues (no withOpacity)
/// - Clean loading and error states; const-friendly where possible
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({
    super.key,
    this.controller,
    this.networkUrl,
    this.assetPath,
    this.autoPlay = false,
    this.looping = false,
    this.aspectRatio,
    this.showFullscreenButton = true,
    this.title,
  }) : assert(
          controller != null || networkUrl != null || assetPath != null,
          'Provide a controller or a source (networkUrl or assetPath).',
        );

  /// Provide an existing controller to manage lifecycle externally (won’t be disposed here).
  final VideoPlayerController? controller;

  /// If no controller is provided, a network controller is created from this URL.
  final Uri? networkUrl;

  /// If no controller is provided, an asset controller is created from this asset path.
  final String? assetPath;

  /// Auto-play on init.
  final bool autoPlay;

  /// Loop playback.
  final bool looping;

  /// Override aspect ratio; falls back to video aspect when available.
  final double? aspectRatio;

  /// Show/hide fullscreen button.
  final bool showFullscreenButton;

  /// Optional title shown in fullscreen header.
  final String? title;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _internalController;
  VideoPlayerController get _controller => widget.controller ?? _internalController!;
  Future<void>? _initialize;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _muted = false;
  double _speed = 1.0;

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild if source/controller changed.
    if (oldWidget.controller != widget.controller ||
        oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.assetPath != widget.assetPath) {
      _disposeInternal();
      _setupController();
    }
  }

  void _setupController() {
    if (widget.controller != null) {
      _initialize = widget.controller!.initialize();
      _applyFlags();
      return;
    }
    if (widget.networkUrl != null) {
      _internalController = VideoPlayerController.networkUrl(widget.networkUrl!);
    } else if (widget.assetPath != null) {
      _internalController = VideoPlayerController.asset(widget.assetPath!);
    }
    if (_internalController != null) {
      _initialize = _internalController!.initialize();
      _applyFlags();
    }
  }

  void _applyFlags() {
    _controller.setLooping(widget.looping);
    if (widget.autoPlay) {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _disposeInternal();
    super.dispose();
  }

  void _disposeInternal() {
    if (_ownsController && _internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }
  }

  void _togglePlayPause() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _kickAutoHide();
  }

  void _toggleMute() {
    if (!_controller.value.isInitialized) return;
    _muted = !_muted;
    _controller.setVolume(_muted ? 0.0 : 1.0);
    setState(() {});
    _kickAutoHide();
  }

  void _changeSpeed(double s) {
    if (!_controller.value.isInitialized) return;
    _speed = s;
    _controller.setPlaybackSpeed(s);
    setState(() {});
    _kickAutoHide();
  }

  void _seekTo(Duration pos) {
    if (!_controller.value.isInitialized) return;
    final total = _controller.value.duration;
    final clamped = pos < Duration.zero ? Duration.zero : (pos > total ? total : pos);
    _controller.seekTo(clamped);
    _kickAutoHide();
  }

  // Removed unused _fmtTime helper.

  void _kickAutoHide() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _LoadingShell(title: widget.title);
        }
        if (!_controller.value.isInitialized) {
          return const _ErrorShell(message: 'Failed to load video');
        }

        final ar = widget.aspectRatio ?? _controller.value.aspectRatio;
        final video = AspectRatio(
          aspectRatio: ar == 0 ? 16 / 9 : ar,
          child: VideoPlayer(_controller),
        );

        final overlay = _ControlsOverlay(
          visible: _controlsVisible,
          title: widget.title,
          isPlaying: _controller.value.isPlaying,
          muted: _muted,
          speed: _speed,
          position: _controller.value.position,
          duration: _controller.value.duration,
          buffered: _controller.value.buffered,
          showFullscreen: widget.showFullscreenButton,
          onPlayPause: _togglePlayPause,
          onToggleVisible: () {
            setState(() => _controlsVisible = !_controlsVisible);
            if (_controlsVisible) _kickAutoHide();
          },
          onSeek: _seekTo,
          onMute: _toggleMute,
          onSpeed: _changeSpeed,
          onFullscreen: () => _openFullscreen(context),
        );

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            video,
            Positioned.fill(child: overlay),
          ],
        );
      },
    );
  }

  Future<void> _openFullscreen(BuildContext context) async {
    if (!widget.showFullscreenButton) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) {
          return _FullscreenScaffold(
            player: this,
          );
        },
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
    // Restore controls state after returning
    _kickAutoHide();
  }
}

class _FullscreenScaffold extends StatelessWidget {
  const _FullscreenScaffold({required this.player});
  final _AppVideoPlayerState player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = player._controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        bottom: true,
        child: Stack(
          children: <Widget>[
            Center(
              child: AspectRatio(
                aspectRatio:
                    ctrl.value.isInitialized ? (ctrl.value.aspectRatio == 0 ? 16 / 9 : ctrl.value.aspectRatio) : 16 / 9,
                child: VideoPlayer(ctrl),
              ),
            ),
            // Top bar
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                    Expanded(
                      child: Text(
                        player.widget.title ?? 'Video',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ControlsOverlay(
                visible: true,
                title: player.widget.title,
                isPlaying: ctrl.value.isPlaying,
                muted: player._muted,
                speed: player._speed,
                position: ctrl.value.position,
                duration: ctrl.value.duration,
                buffered: ctrl.value.buffered,
                showFullscreen: false,
                onPlayPause: player._togglePlayPause,
                onToggleVisible: () {},
                onSeek: player._seekTo,
                onMute: player._toggleMute,
                onSpeed: player._changeSpeed,
                onFullscreen: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell({this.title});
  final String? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: <Widget>[
          Container(color: Colors.black),
          Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (title != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.visible,
    required this.title,
    required this.isPlaying,
    required this.muted,
    required this.speed,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.showFullscreen,
    required this.onPlayPause,
    required this.onToggleVisible,
    required this.onSeek,
    required this.onMute,
    required this.onSpeed,
    required this.onFullscreen,
  });

  final bool visible;
  final String? title;
  final bool isPlaying;
  final bool muted;
  final double speed;
  final Duration position;
  final Duration duration;
  final List<DurationRange> buffered;

  final bool showFullscreen;

  final VoidCallback onPlayPause;
  final VoidCallback onToggleVisible;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onMute;
  final ValueChanged<double> onSpeed;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final overlayColor = cs.surfaceContainerHighest.withValues(alpha: 0.92);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1.0 : 0.0,
        child: Stack(
          children: <Widget>[
            // Center play/pause
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: IconButton.filledTonal(
                  onPressed: onPlayPause,
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),

            // Title (top-left)
            if (title != null && title!.trim().isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _BufferedSeekBar(
                        position: position,
                        duration: duration,
                        buffered: buffered,
                        onChanged: (v) => onSeek(Duration(milliseconds: v.toInt())),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Text(_fmt(position), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface)),
                          const Spacer(),
                          Text(_fmt(duration), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: muted ? 'Unmute' : 'Mute',
                            onPressed: onMute,
                            icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<double>(
                            tooltip: 'Playback speed',
                            itemBuilder: (context) => const <PopupMenuEntry<double>>[
                              PopupMenuItem<double>(value: 0.5, child: Text('0.5x')),
                              PopupMenuItem<double>(value: 0.75, child: Text('0.75x')),
                              PopupMenuItem<double>(value: 1.0, child: Text('1.0x')),
                              PopupMenuItem<double>(value: 1.25, child: Text('1.25x')),
                              PopupMenuItem<double>(value: 1.5, child: Text('1.5x')),
                              PopupMenuItem<double>(value: 2.0, child: Text('2.0x')),
                            ],
                            onSelected: onSpeed,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.speed_rounded),
                                const SizedBox(width: 6),
                                Text('${speed.toStringAsFixed(2)}x'),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (showFullscreen)
                            IconButton(
                              tooltip: 'Fullscreen',
                              onPressed: onFullscreen,
                              icon: const Icon(Icons.fullscreen_rounded),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _BufferedSeekBar extends StatefulWidget {
  const _BufferedSeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onChanged,
  });

  final Duration position;
  final Duration duration;
  final List<DurationRange> buffered;
  final ValueChanged<double> onChanged;

  @override
  State<_BufferedSeekBar> createState() => _BufferedSeekBarState();
}

class _BufferedSeekBarState extends State<_BufferedSeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalMs = widget.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final posMs = (_drag ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, totalMs);

    double bufferedEndMs = 0.0;
    if (widget.buffered.isNotEmpty) {
      final last = widget.buffered.last;
      bufferedEndMs = last.end.inMilliseconds.toDouble().clamp(0.0, totalMs);
    }

    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          // Buffered bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          FractionallySizedBox(
            widthFactor: bufferedEndMs / totalMs,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // Progress bar
          FractionallySizedBox(
            widthFactor: posMs / totalMs,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // Slider thumb (transparent slider capturing gestures)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              min: 0,
              max: totalMs,
              value: posMs,
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                widget.onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
