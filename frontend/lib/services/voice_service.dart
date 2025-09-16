// lib/services/voice_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Unified permission status across platforms.
enum VoicePermissionStatus { granted, denied, deniedForever, restricted, unknown }

/// High-level voice system state for UI and analytics.
enum VoiceState { idle, listening, recognizing, speaking, paused, error }

/// Configuration for STT sessions.
@immutable
class VoiceListenConfig {
  const VoiceListenConfig({
    this.languageCode = 'en-US',
    this.partialResults = true,
    this.autoPunctuation = true,
    this.onDevice = false, // allow adapter to choose on-device model if available
    this.minSilenceMs = 800, // VAD hint for end of utterance if supported
    this.maxListenSeconds = 60, // safety stop
  });

  final String languageCode;
  final bool partialResults;
  final bool autoPunctuation;
  final bool onDevice;
  final int minSilenceMs;
  final int maxListenSeconds;

  VoiceListenConfig copyWith({
    String? languageCode,
    bool? partialResults,
    bool? autoPunctuation,
    bool? onDevice,
    int? minSilenceMs,
    int? maxListenSeconds,
  }) {
    return VoiceListenConfig(
      languageCode: languageCode ?? this.languageCode,
      partialResults: partialResults ?? this.partialResults,
      autoPunctuation: autoPunctuation ?? this.autoPunctuation,
      onDevice: onDevice ?? this.onDevice,
      minSilenceMs: minSilenceMs ?? this.minSilenceMs,
      maxListenSeconds: maxListenSeconds ?? this.maxListenSeconds,
    );
  }
}

/// A recognized transcript token; partial or final.
@immutable
class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    this.isFinal = false,
    this.confidence, // 0..1 if provided by adapter
    this.languageCode,
    required this.timestamp,
  });

  final String text;
  final bool isFinal;
  final double? confidence;
  final String? languageCode;
  final DateTime timestamp;
}

/// Abstract speech-to-text provider (e.g., speech_to_text adapter).
abstract class SpeechProvider {
  Future<bool> initialize();
  Future<VoicePermissionStatus> checkPermission();
  Future<VoicePermissionStatus> requestPermission();

  Future<void> startListening(VoiceListenConfig config);
  Future<void> stopListening(); // finalize with partial => final if supported
  Future<void> cancel(); // abort without result

  /// Emitted for both partial and final transcripts.
  Stream<VoiceTranscript> get onResult;

  /// Provider status messages, e.g., "listening", "notListening", platform hints.
  Stream<String> get onStatus;

  /// Provider error stream (human-readable).
  Stream<String> get onError;

  /// Optional supported locales (e.g., ["en-US","hi-IN"]).
  Future<List<String>> locales();
}

/// Abstract TTS provider (e.g., flutter_tts adapter).
abstract class TtsProvider {
  Future<bool> initialize();
  Future<void> setLanguage(String code);
  Future<void> setRate(double rate);  // typical range 0.0..1.0 (adapter maps)
  Future<void> setPitch(double pitch); // typical range 0.5..2.0 (adapter maps)

  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();

  Stream<void> get onStart;
  Stream<void> get onComplete;
  Stream<String> get onError;
}

/// Audio focus manager abstraction (Android/iOS use cases).
abstract class AudioFocusManager {
  /// Request audio focus; transient for short capture / TTS, mayDuck for mixing.
  Future<bool> requestFocus({bool transient = true, bool mayDuck = false});

  /// Abandon previously held focus.
  Future<void> abandonFocus();
}

/// A queued TTS item for sequential playback.
@immutable
class TtsItem {
  const TtsItem({required this.text, this.languageCode, this.rate, this.pitch});

  final String text;
  final String? languageCode;
  final double? rate;
  final double? pitch;
}

/// Orchestrates STT, TTS, and audio focus so listening/speaking coordinate cleanly.
class VoiceService {
  VoiceService({
    required SpeechProvider speech,
    required TtsProvider tts,
    required AudioFocusManager audioFocus,
  })  : _speech = speech,
        _tts = tts,
        _focus = audioFocus;

  final SpeechProvider _speech;
  final TtsProvider _tts;
  final AudioFocusManager _focus;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  final StreamController<VoiceTranscript> _transcripts$ = StreamController<VoiceTranscript>.broadcast();
  final StreamController<VoiceState> _states$ = StreamController<VoiceState>.broadcast();
  final StreamController<String> _errors$ = StreamController<String>.broadcast();

  Stream<VoiceTranscript> get transcripts$ => _transcripts$.stream;
  Stream<VoiceState> get states$ => _states$.stream;
  Stream<String> get errors$ => _errors$.stream;

  StreamSubscription<VoiceTranscript>? _sttSub;
  StreamSubscription<String>? _sttStatusSub;
  StreamSubscription<String>? _sttErrorSub;

  StreamSubscription<void>? _ttsStartSub;
  StreamSubscription<void>? _ttsCompleteSub;
  StreamSubscription<String>? _ttsErrorSub;

  final List<TtsItem> _ttsQueue = <TtsItem>[];
  bool _speaking = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final sttOk = await _speech.initialize();
    final ttsOk = await _tts.initialize();
    if (!sttOk || !ttsOk) {
      _setError('Voice initialization failed');
      return;
    }

    // Wire STT streams
    _sttSub = _speech.onResult.listen((r) {
      _transcripts$.add(r);
      _setState(r.isFinal ? VoiceState.recognizing : VoiceState.listening);
    }, onError: (e) => _setError(e.toString()));

    _sttStatusSub = _speech.onStatus.listen((s) {
      // Map provider status to high-level states conservatively.
      if (s.toLowerCase().contains('listening')) {
        _setState(VoiceState.listening);
      } else if (s.toLowerCase().contains('not')) {
        if (!_speaking) _setState(VoiceState.idle);
      }
    });

    _sttErrorSub = _speech.onError.listen((e) => _setError(e));

    // Wire TTS streams
    _ttsStartSub = _tts.onStart.listen((_) => _setState(VoiceState.speaking));
    _ttsCompleteSub = _tts.onComplete.listen((_) {
      _speaking = false;
      _drainTtsQueue();
    });
    _ttsErrorSub = _tts.onError.listen((e) {
      _speaking = false;
      _setError(e);
      _drainTtsQueue();
    });

    _initialized = true;
  }

  Future<VoicePermissionStatus> ensurePermission() async {
    final status = await _speech.checkPermission();
    if (status == VoicePermissionStatus.granted) return status;
    return _speech.requestPermission();
  }

  Future<void> startListening(VoiceListenConfig config) async {
    await init();
    final perm = await ensurePermission();
    if (perm != VoicePermissionStatus.granted) {
      _setError('Microphone permission not granted');
      return;
    }

    // If currently speaking, stop TTS and release focus to capture mic cleanly.
    if (_speaking) {
      await _stopTtsInternal();
    }

    // Request transient focus for capture.
    final gotFocus = await _focus.requestFocus(transient: true, mayDuck: false);
    if (!gotFocus) {
      _setError('Audio focus not granted for listening');
      return;
    }

    _setState(VoiceState.listening);
    await _speech.startListening(config);
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    // Leave focus decisions to next action (e.g., TTS or idle).
    if (!_speaking) _setState(VoiceState.idle);
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    if (!_speaking) {
      await _focus.abandonFocus();
      _setState(VoiceState.idle);
    }
  }

  /// Enqueue text for TTS; respects audio focus and pauses/cancels STT if needed.
  Future<void> speak(TtsItem item) async {
    await init();

    // Stop listening to avoid feedback/echo while speaking.
    await _speech.cancel();

    // Request focus for transient TTS playback (may duck others).
    final gotFocus = await _focus.requestFocus(transient: true, mayDuck: true);
    if (!gotFocus) {
      _setError('Audio focus not granted for speaking');
      return;
    }

    _ttsQueue.add(item);
    if (!_speaking) {
      _drainTtsQueue();
    }
  }

  Future<void> pauseTts() async {
    await _tts.pause();
    _setState(VoiceState.paused);
  }

  Future<void> resumeTts() async {
    final gotFocus = await _focus.requestFocus(transient: true, mayDuck: true);
    if (!gotFocus) {
      _setError('Audio focus not granted to resume speaking');
      return;
    }
    await _tts.resume();
    _setState(VoiceState.speaking);
  }

  Future<void> stopAll() async {
    await _speech.cancel();
    await _stopTtsInternal();
    _ttsQueue.clear();
    await _focus.abandonFocus();
    _setState(VoiceState.idle);
  }

  Future<void> dispose() async {
    await stopAll();
    await _sttSub?.cancel();
    await _sttStatusSub?.cancel();
    await _sttErrorSub?.cancel();
    await _ttsStartSub?.cancel();
    await _ttsCompleteSub?.cancel();
    await _ttsErrorSub?.cancel();
    await _transcripts$.close();
    await _states$.close();
    await _errors$.close();
  }

  // ---- Internals ----

  Future<void> _drainTtsQueue() async {
    if (_speaking) return;
    if (_ttsQueue.isEmpty) {
      await _focus.abandonFocus();
      _setState(VoiceState.idle);
      return;
    }
    _speaking = true;

    final next = _ttsQueue.removeAt(0);
    if (next.languageCode != null) {
      await _tts.setLanguage(next.languageCode!);
    }
    if (next.rate != null) {
      await _tts.setRate(next.rate!);
    }
    if (next.pitch != null) {
      await _tts.setPitch(next.pitch!);
    }

    await _tts.speak(next.text);
    // onComplete/onError set _speaking=false and recurse via stream handlers
  }

  Future<void> _stopTtsInternal() async {
    _speaking = false;
    await _tts.stop();
  }

  void _setState(VoiceState s) {
    _state = s;
    _states$.add(s);
  }

  void _setError(String message) {
    _setState(VoiceState.error);
    _errors$.add(message);
  }
}

/// A no-op audio focus manager for platforms that don’t need explicit focus.
class NoopAudioFocusManager implements AudioFocusManager {
  const NoopAudioFocusManager();

  @override
  Future<void> abandonFocus() async {
    // no-op
  }

  @override
  Future<bool> requestFocus({bool transient = true, bool mayDuck = false}) async {
    return true;
  }
}
