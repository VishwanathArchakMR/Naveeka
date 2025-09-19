// lib/features/navee_ai/presentation/widgets/explore_mode.dart

import 'dart:convert';
import 'package:flutter/material.dart';

import '../../data/navee_ai_api.dart';
import 'ai_response_cards.dart';

class ExploreMode extends StatefulWidget {
  const ExploreMode({
    super.key,
    required this.api,
    this.title = 'Explore ideas',
    this.initialDestination,
    this.currency = '₹',
  });

  final NaveeAiApi api;
  final String title;
  final String? initialDestination;
  final String currency;

  @override
  State<ExploreMode> createState() => _ExploreModeState();
}

class _ExploreModeState extends State<ExploreMode> {
  final _destCtrl = TextEditingController();
  int _days = 3;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = const <Map<String, dynamic>>[];

  // Prompt presets
  final List<_Prompt> _prompts = const [
    _Prompt('City weekend', 'Plan a weekend in {city}', icon: Icons.weekend_outlined),
    _Prompt('Food crawl', 'Find best eats in {city}', icon: Icons.restaurant_menu_outlined),
    _Prompt('Family fun', 'Family-friendly {days} days in {city}', icon: Icons.family_restroom_outlined),
    _Prompt('Romantic', 'Romantic {days}-day in {city}', icon: Icons.favorite_border),
    _Prompt('Budget trip', 'Budget {days}-day itinerary in {city}', icon: Icons.attach_money_outlined),
    _Prompt('Adventure', 'Outdoor & adventure in {city}', icon: Icons.hiking_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _destCtrl.text = widget.initialDestination ?? '';
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _refine() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RefineSheet(
        destination: _destCtrl.text.trim(),
        days: _days,
      ),
    );
    if (res != null) {
      setState(() {
        _destCtrl.text = (res['destination'] ?? _destCtrl.text).toString();
        _days = (res['days'] as int?) ?? _days;
      });
      await _fetch();
    }
  } // showModalBottomSheet returns a Future with the value passed to Navigator.pop, enabling simple state handoff [web:5748][web:5764]

  Future<void> _fetch() async {
    final city = _destCtrl.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a destination')));
      return;
    }
    setState(() {
      _loading = true;
      _suggestions = const <Map<String, dynamic>>[];
    });

    final r = await widget.api.suggestItineraries(
      destination: '$city (${_days}d)',
      maxSuggestions: 6,
    );
    r.fold(
      onSuccess: (list) {
        setState(() {
          _suggestions = list;
          _loading = false;
        });
      },
      onError: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.safeMessage)));
      },
    );
  }

  Future<void> _onRefresh() async {
    await _fetch();
  }

  void _usePrompt(_Prompt p) {
    final city = _destCtrl.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a destination')));
      return;
    }
    setState(() => _loading = true);
    final text = p.render(city: city, days: _days);
    widget.api
        .chat(
      messages: [
        {'role': 'system', 'content': 'You are Navee, output STRICT JSON arrays of ideas only.'},
        {'role': 'user', 'content': 'Suggest itinerary ideas for: $text\nReturn JSON array [{"title":"","days":3,"highlights":["",""],"budgetFrom":null}] only.'},
      ],
      temperature: 0.8,
      maxTokens: 800,
    )
        .then((res) {
      res.fold(
        onSuccess: (data) {
          final content = _firstMessage(data) ?? '[]';
          final list = _tryDecodeList(content) ?? const <dynamic>[];
          setState(() {
            _suggestions = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
            _loading = false;
          });
        },
        onError: (e) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.safeMessage)));
        },
      );
    });
  }

  String? _firstMessage(Map<String, dynamic> data) {
    try {
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final msg = (choices.first as Map)['message'] as Map?;
      return msg?['content']?.toString();
    } catch (_) {
      return null;
    }
  }

  // Robustly extract a JSON array from plain text or fenced `````` blocks and decode it.
  List<dynamic>? _tryDecodeList(String s) {
    try {
      final t = s.trim();
      // If fenced, extract inner content; supports `````` or ``````
      final fence = RegExp(r'^``````$', multiLine: true);
      final m = fence.firstMatch(t);
      final body = m != null ? m.group(1)!.trim() : t;
      final jsonStr = body.startsWith('[') ? body : '[]';
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  } // Strips triple‑backtick code fences before jsonDecode to avoid syntax errors with fenced content [web:5759][web:5765]

  @override
  Widget build(BuildContext context) {
    final list = _suggestions;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refine',
            onPressed: _refine,
            icon: const Icon(Icons.tune),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Destination city',
                      prefixIcon: Icon(Icons.place_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _fetch(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<int>(
                    initialValue: _days,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Days',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 4, child: Text('4')),
                      DropdownMenuItem(value: 5, child: Text('5')),
                    ],
                    onChanged: (v) => setState(() => _days = v ?? _days),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Prompt chips grid
              Text('Try a prompt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prompts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.4,
                ),
                itemBuilder: (context, i) {
                  final p = _prompts[i];
                  final city = _destCtrl.text.trim();
                  final label = p.render(city: city.isEmpty ? '{city}' : city, days: _days);
                  return Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _loading ? null : () => _usePrompt(p),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Icon(p.icon, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Suggestions
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No suggestions yet. Enter a destination or tap a prompt.'),
                )
              else
                AiResponseCards(items: [list], currency: widget.currency),
            ],
          ),
        ),
      ),
    );
  }
}

class _Prompt {
  final String title;
  final String tmpl;
  final IconData icon;
  const _Prompt(this.title, this.tmpl, {required this.icon});

  String render({required String city, required int days}) {
    return tmpl.replaceAll('{city}', city).replaceAll('{days}', days.toString());
  }
}

class _RefineSheet extends StatefulWidget {
  const _RefineSheet({required this.destination, required this.days});
  final String destination;
  final int days;

  @override
  State<_RefineSheet> createState() => _RefineSheetState();
}

class _RefineSheetState extends State<_RefineSheet> {
  late TextEditingController _destCtrl;
  late int _days;

  @override
  void initState() {
    super.initState();
    _destCtrl = TextEditingController(text: widget.destination);
    _days = widget.days;
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).maybePop({'destination': _destCtrl.text.trim(), 'days': _days});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Refine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _destCtrl,
            decoration: const InputDecoration(
              labelText: 'Destination',
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _days,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Days',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                    DropdownMenuItem(value: 5, child: Text('5')),
                  ],
                  onChanged: (v) => setState(() => _days = v ?? _days),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
