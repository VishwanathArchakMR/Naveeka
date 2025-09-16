import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/theme.dart';
import 'dart:async';

class AmbientAudioTile extends StatefulWidget {
  final String audioUrl;
  final String title;
  final EmotionKind? emotion;

  const AmbientAudioTile({
    super.key,
    required this.audioUrl,
    required this.title,
    this.emotion,
  });

  @override
  State<AmbientAudioTile> createState() => _AmbientAudioTileState();
}

class _AmbientAudioTileState extends State<AmbientAudioTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _buffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late EmotionTheme _theme;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _theme = widget.emotion != null
        ? EmotionTheme.of(widget.emotion!)
        : EmotionTheme.of(EmotionKind.peaceful);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _duration = _player.duration ?? Duration.zero;

      // Position subscription
      _posSub = _player.positionStream.listen((pos) {
        setState(() => _position = pos);
      });

      // Player state subscription
      _stateSub = _player.playerStateStream.listen((state) {
        setState(() {
          _playing = state.playing;
          _buffering = state.processingState == ProcessingState.buffering;
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      });
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          if (_playing)
            BoxShadow(
              color: _theme.glow,
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause Button with animation
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _theme.gradient,
              ),
              child: _buffering
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.black87),
                      ),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black87,
                      size: 30,
                    ).animate(target: _playing ? 1 : 0).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 200.ms,
                      ),
            ).animate().fadeIn(duration: 200.ms),
          ),
          const SizedBox(width: 14),

          // Title & Seekbar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final tapPos = details.localPosition.dx;
                      final newProgress = tapPos / box.size.width;
                      _player.seek(
                        _duration * newProgress.clamp(0.0, 1.0),
                      );
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(_theme.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Time
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                _formatTime(_duration),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
