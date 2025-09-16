// lib/features/navee_ai/presentation/widgets/voice_input.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Button that opens the VoiceInputSheet and returns the final transcript.
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({
    super.key,
    this.label = 'Voice',
    this.onFinal,        // void Function(String text)
    this.onPartial,      // void Function(String text)
    this.initialLocale,  // e.g. "en_US"
    this.tooltip = 'Speak your prompt',
    this.icon = Icons.mic_none_rounded,
  });

  final String label;
  final void Function(String text)? onFinal;
  final void Function(String text)? onPartial;
  final String? initialLocale;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton.icon(
      onPressed: () => VoiceInputSheet.show(
        context,
        onFinal: onFinal,
        onPartial: onPartial,
        initialLocale: initialLocale,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
    return Tooltip(message: tooltip, child: btn); // Tooltip provides an accessible label for the input action. [21]
  }
}

/// Shaped modal bottom sheet that captures speech and returns transcripts through callbacks.
class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({
    super.key,
    this.onFinal,
    this.onPartial,
    this.initialLocale,
  });

  final void Function(String text)? onFinal;
  final void Function(String text)? onPartial;
  final String? initialLocale;

  static Future<void> show(
    BuildContext context, {
    void Function(String text)? onFinal,
    void Function(String text)? onPartial,
    String? initialLocale,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: VoiceInputSheet(
          onFinal: onFinal,
          onPartial: onPartial,
          initialLocale: initialLocale,
        ),
      ),
    ); // showModalBottomSheet returns after the sheet is closed and isolates focus while capturing audio. [7][10]
  }

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _initializing = true;
  bool _listening = false;

  String _transcript = '';
  String _finalText = '';
  String? _error;

  double _level = 0.0;

  List<stt.LocaleName> _locales = const [];
  String? _localeId;

  Timer? _stopSafety;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _stopSafety?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Request mic permission before initializing speech engine.
    final mic = await Permission.microphone.request(); // permission_handler requests mic access on Android/iOS with consistent API. [9][17]
    if (!mic.isGranted) {
      setState(() {
        _initializing = false;
        _available = false;
        _error = 'Microphone permission denied';
      });
      return;
    }

    try {
      final ok = await _speech.initialize(
        onError: (err) => setState(() => _error = err.errorMsg),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
            _emitFinal();
          }
        },
      ); // Initialize once per session; then listen/stop for subsequent captures per plugin guidance. [1]

      List<stt.LocaleName> locales = const [];
      try {
        locales = await _speech.locales();
      } catch (_) {
        locales = const [];
      }

      setState(() {
        _available = ok;
        _initializing = false;
        _locales = locales;
        // Pick initial locale: provided, device default from plugin, else first available.
        _localeId = widget.initialLocale ??
            (_speech.systemLocale()?.localeId ?? (locales.isNotEmpty ? locales.first.localeId : null));
      });
    } catch (e) {
      setState(() {
        _initializing = false;
        _available = false;
        _error = 'Speech engine unavailable';
      });
    }
  }

  Future<void> _start() async {
    if (!_available || _listening) return;
    setState(() {
      _error = null;
      _finalText = '';
      _transcript = '';
    });

    // Safety timer: auto-stop after 60 seconds to avoid stuck sessions.
    _stopSafety?.cancel();
    _stopSafety = Timer(const Duration(seconds: 60), _stop);

    try {
      await _speech.listen(
        onResult: _onResult,
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        localeId: _localeId,
        onSoundLevelChange: (level) => setState(() => _level = level.clamp(0, 60)), // UI meter from plugin sound level callback. [1]
      ); // Call listen with onResult and optional localeId/partialResults for real-time transcription. [1]
      setState(() => _listening = true);
    } catch (e) {
      setState(() {
        _listening = false;
        _error = 'Failed to start listening';
      });
    }
  }

  Future<void> _stop() async {
    if (!_listening) return;
    _stopSafety?.cancel();
    await _speech.stop();
    setState(() => _listening = false);
    _emitFinal();
  }

  Future<void> _cancel() async {
    _stopSafety?.cancel();
    await _speech.cancel();
    setState(() {
      _listening = false;
      _transcript = '';
      _finalText = '';
    });
  }

  void _emitFinal() {
    final out = _finalText.isNotEmpty ? _finalText : _transcript;
    if (out.isNotEmpty && widget.onFinal != null) {
      widget.onFinal!(out);
    }
  }

  void _onResult(SpeechRecognitionResult res) {
    final words = res.recognizedWords.trim();
    setState(() {
      _transcript = words;
      if (res.finalResult) {
        _finalText = words;
      }
    });
    if (!res.finalResult && words.isNotEmpty && widget.onPartial != null) {
      widget.onPartial!(words);
    }
  } // onResult is invoked with partial and final segments; use finalResult to commit the transcript. [1]

  @override
  Widget build(BuildContext context) {
    final canListen = _available && !_initializing;
    final statusText = _initializing
        ? 'Initializing…'
        : (!_available ? (_error ?? 'Speech unavailable') : (_listening ? 'Listening…' : 'Ready'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text('Voice input', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),

          // Status and locale
          Row(
            children: [
              Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : Colors.black54),
              const SizedBox(width: 6),
              Text(statusText),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _localeId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _locales
                      .map((l) => DropdownMenuItem<String>(
                            value: l.localeId,
                            child: Text(l.name),
                          ))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _localeId = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Transcript view
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _finalText.isNotEmpty ? _finalText : _transcript,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 12),

          // Sound level meter
          _LevelMeter(level: _level),

          const SizedBox(height: 12),

          // Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !_listening ? (canListen ? _start : null) : _cancel,
                  icon: Icon(!_listening ? Icons.mic : Icons.close),
                  label: Text(!_listening ? 'Start' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _listening ? _stop : (canListen ? _start : null),
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? 'Stop' : 'Speak'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    // Smooth visual between 0..60 mapped to 0..1 for width fill
    final t = (level / 60.0).clamp(0.0, 1.0);
    return Container(
      height: 8,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: t,
          child: Container(
            color: _gradientColor(t),
          ),
        ),
      ),
    );
  }

  Color _gradientColor(double t) {
    if (t < 0.33) return Colors.green;
    if (t < 0.66) return Colors.orange;
    return Colors.red;
  }
}
