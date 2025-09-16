// lib/features/navee_ai/presentation/widgets/ai_settings.dart

import 'package:flutter/material.dart';

class AiSettings {
  const AiSettings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.temperature,
    this.maxTokens,
    this.jsonOnly = true,
    this.stripFences = true,
    this.useModeration = false,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int? maxTokens;
  final bool jsonOnly;
  final bool stripFences;
  final bool useModeration;

  Map<String, dynamic> toMap() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'jsonOnly': jsonOnly,
        'stripFences': stripFences,
        'useModeration': useModeration,
      };

  AiSettings copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? jsonOnly,
    bool? stripFences,
    bool? useModeration,
  }) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      jsonOnly: jsonOnly ?? this.jsonOnly,
      stripFences: stripFences ?? this.stripFences,
      useModeration: useModeration ?? this.useModeration,
    );
  }
}

class AiSettingsSheet extends StatefulWidget {
  const AiSettingsSheet({
    super.key,
    required this.initial,
    this.availableModels = const ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
    this.title = 'AI settings',
  });

  final AiSettings initial;
  final List<String> availableModels;
  final String title;

  /// Convenience presenter that returns an AiSettings on save.
  static Future<AiSettings?> show(
    BuildContext context, {
    required AiSettings initial,
    List<String> availableModels = const ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
    String title = 'AI settings',
  }) {
    return showModalBottomSheet<AiSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AiSettingsSheet(
          initial: initial,
          availableModels: availableModels,
          title: title,
        ),
      ),
    );
  }

  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _baseUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _customModelCtrl;
  late TextEditingController _maxTokensCtrl;

  late String _model;
  late double _temperature;
  late bool _jsonOnly;
  late bool _stripFences;
  late bool _useModeration;

  bool _showApiKey = false;
  bool _useCustomModel = false;

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl = TextEditingController(text: widget.initial.baseUrl);
    _apiKeyCtrl = TextEditingController(text: widget.initial.apiKey);
    _customModelCtrl = TextEditingController();
    _maxTokensCtrl = TextEditingController(
      text: widget.initial.maxTokens != null ? widget.initial.maxTokens.toString() : '',
    );

    _model = widget.initial.model;
    _useCustomModel = !widget.availableModels.contains(_model);
    if (_useCustomModel) {
      _customModelCtrl.text = _model;
    }

    _temperature = widget.initial.temperature;
    _jsonOnly = widget.initial.jsonOnly;
    _stripFences = widget.initial.stripFences;
    _useModeration = widget.initial.useModeration;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _customModelCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  void _resetDefaults() {
    setState(() {
      _baseUrlCtrl.text = 'https://api.openai.com/v1';
      _model = 'gpt-4o-mini';
      _useCustomModel = false;
      _customModelCtrl.clear();
      _temperature = 0.6;
      _maxTokensCtrl.clear();
      _jsonOnly = true;
      _stripFences = true;
      _useModeration = false;
    });
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final model = _useCustomModel ? _customModelCtrl.text.trim() : _model;
    final maxTok = int.tryParse(_maxTokensCtrl.text.trim());
    final out = AiSettings(
      baseUrl: _baseUrlCtrl.text.trim().replaceAll(RegExp(r'/*$'), ''), // strip trailing '/'
      apiKey: _apiKeyCtrl.text.trim(),
      model: model,
      temperature: _temperature,
      maxTokens: maxTok,
      jsonOnly: _jsonOnly,
      stripFences: _stripFences,
      useModeration: _useModeration,
    );
    Navigator.of(context).maybePop(out);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    TextButton(onPressed: _resetDefaults, child: const Text('Reset')),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                // Base URL
                TextFormField(
                  controller: _baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter base URL';
                    if (!s.startsWith('http')) return 'URL must start with http/https';
                    return null;
                  },
                ), // Base URL is required and validated using a TextFormField validator inside a Form per Flutter cookbook patterns [10][13]

                const SizedBox(height: 12),

                // API key
                TextFormField(
                  controller: _apiKeyCtrl,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      tooltip: _showApiKey ? 'Hide' : 'Show',
                      icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                  obscureText: !_showApiKey,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter API key';
                    return null;
                  },
                ), // The API key field supports show/hide and validation using TextFormField + validator in a Form [10][13]

                const SizedBox(height: 12),

                // Model selection
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _useCustomModel ? null : _model,
                        items: widget.availableModels
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(growable: false),
                        onChanged: (v) {
                          setState(() {
                            _useCustomModel = false;
                            _model = v ?? _model;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.smart_toy_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _useCustomModel = !_useCustomModel),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(_useCustomModel ? 'Built‑in' : 'Custom'),
                    ),
                  ],
                ),

                if (_useCustomModel) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _customModelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Custom model ID',
                      hintText: 'e.g., my-org/navee-model',
                      prefixIcon: Icon(Icons.label_important_outline),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter model ID';
                      return null;
                    },
                  ),
                ], // DropdownButtonFormField for built‑in models and a TextFormField for a custom model are validated in the same Form [10][13]

                const SizedBox(height: 12),

                // Temperature slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.thermostat_outlined, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
                      ],
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (v) => setState(() => _temperature = v),
                    ),
                  ],
                ), // Temperature selection uses the Material Slider widget with a 0..1 range and divisions for precision control [9][6]

                const SizedBox(height: 4),

                // Max tokens
                TextFormField(
                  controller: _maxTokensCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max tokens (optional)',
                    prefixIcon: Icon(Icons.format_align_left),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    final n = int.tryParse(s);
                    if (n == null || n <= 0) return 'Enter a positive number';
                    return null;
                  },
                ), // Numeric validation is handled inside the TextFormField validator per standard Form practices [10][13]

                const SizedBox(height: 12),

                // Response switches
                SwitchListTile(
                  value: _jsonOnly,
                  onChanged: (v) => setState(() => _jsonOnly = v),
                  title: const Text('Expect JSON only'),
                  subtitle: const Text('Ask the model to reply strictly with JSON'),
                ),
                SwitchListTile(
                  value: _stripFences,
                  onChanged: (v) => setState(() => _stripFences = v),
                  title: const Text('Strip ```
                  subtitle: const Text('Remove Markdown code fences before JSON parsing'),
                ),
                SwitchListTile(
                  value: _useModeration,
                  onChanged: (v) => setState(() => _useModeration = v),
                  title: const Text('Use moderation'),
                  subtitle: const Text('Send inputs to moderation before chat'),
                ), // SwitchListTile provides compact boolean controls for response shaping and safety flags within the sheet[3]

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ), // Save validates via the enclosing Form and returns settings with Navigator.pop for a clean bottom sheet flow ,[2][1]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
