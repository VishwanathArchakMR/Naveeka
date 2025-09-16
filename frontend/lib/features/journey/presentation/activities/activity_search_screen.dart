// lib/features/journey/presentation/activities/activity_search_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'activity_results_screen.dart';
import '../../../../../core/storage/location_cache.dart';

class ActivitySearchScreen extends StatefulWidget {
  const ActivitySearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory,
    this.initialEmotion,
    this.initialTags = const <String>[],
    this.initialRegion,
    this.initialLat,
    this.initialLng,
    this.initialRadiusKm = 10.0,
  });

  final String initialQuery;
  final String? initialCategory;
  final String? initialEmotion;
  final List<String> initialTags;
  final String? initialRegion;
  final double? initialLat;
  final double? initialLng;
  final double initialRadiusKm;

  @override
  State<ActivitySearchScreen> createState() => _ActivitySearchScreenState();
}

class _ActivitySearchScreenState extends State<ActivitySearchScreen> {
  final _searchController = SearchController();
  final _regionCtrl = TextEditingController();

  // Quick filters
  final List<String> _categories = const ['adventure', 'culture', 'wellness', 'nature', 'spiritual'];
  final List<String> _emotions = const ['thrill', 'calm', 'joy', 'awe'];
  final List<String> _popularTags = const ['sunrise', 'trek', 'camp', 'temple', 'waterfall', 'cycling'];

  String _query = '';
  String? _category;
  String? _emotion;
  final Set<String> _tags = <String>{};

  // Geo
  double? _lat;
  double? _lng;
  double _radiusKm = 10.0;

  // Debounce
  Timer? _debounce;
  final _debounceDuration = const Duration(milliseconds: 350);

  // Suggestions
  final List<String> _recent = <String>['sunrise trek', 'ayurveda massage', 'cycling tour'];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _category = widget.initialCategory;
    _emotion = widget.initialEmotion;
    _tags.addAll(widget.initialTags);
    _regionCtrl.text = widget.initialRegion ?? '';
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _regionCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      setState(() => _query = q.trim());
    });
  }

  Future<void> _useCurrentLocation() async {
    final snap = await LocationCache.instance.getLast(maxAge: const Duration(minutes: 10));
    if (!mounted) return;
    if (snap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet')),
      );
      return;
    }
    setState(() {
      _lat = snap.latitude;
      _lng = snap.longitude;
    });
  }

  void _pushResults() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ActivityResultsScreen(
        q: _query.isEmpty ? null : _query,
        category: _category,
        emotion: _emotion,
        tags: _tags.isEmpty ? null : _tags.toList(growable: false),
        region: _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        radiusKm: _lat != null && _lng != null ? _radiusKm : null,
        sort: 'popular',
        title: 'Activities',
        initialView: ResultsView.list,
        pageSize: 20,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chipsSpacing = 8.0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: SearchAnchor.bar(
          searchController: _searchController,
          barLeading: const Icon(Icons.search),
          isFullScreen: true,
          barHintText: 'Search activities',
          barTrailing: <Widget>[
            if (_query.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.text = '';
                  setState(() => _query = '');
                },
              ),
          ],
          suggestionsBuilder: (context, controller) {
            final q = controller.text.trim().toLowerCase();
            final base = <String>{..._recent, ..._popularTags};
            final results = q.isEmpty
                ? base.take(8).toList()
                : base.where((s) => s.toLowerCase().contains(q)).take(8).toList();
            return results.map((s) {
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(s),
                onTap: () {
                  controller.closeView(s);
                  _onQueryChanged(s);
                },
              );
            });
          },
          viewHintText: 'Type a keyword (e.g., trek, temple, cycling)',
          onSubmitted: (value) {
            // Workaround: SearchAnchor doesn't have a built-in onSubmitted in older versions; handle here.
            _onQueryChanged(value);
            _pushResults();
          },
          onChanged: _onQueryChanged,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Category
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: chipsSpacing,
              runSpacing: chipsSpacing,
              children: _categories.map((c) {
                final selected = _category == c;
                return FilterChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (v) => setState(() => _category = v ? c : null),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),

            // Emotion
            Text('Emotion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: chipsSpacing,
              runSpacing: chipsSpacing,
              children: _emotions.map((e) {
                final selected = _emotion == e;
                return ChoiceChip(
                  label: Text(e),
                  selected: selected,
                  onSelected: (v) => setState(() => _emotion = v ? e : null),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),

            // Tags
            Text('Tags', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: chipsSpacing,
              runSpacing: chipsSpacing,
              children: _popularTags.map((t) {
                final selected = _tags.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _tags.add(t);
                      } else {
                        _tags.remove(t);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 20),

            // Region / Location
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                labelText: 'Region or city (optional)',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(_lat == null ? 'Use current location' : 'Using current location'),
                  ),
                ),
                const SizedBox(width: 8),
                if (_lat != null && _lng != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('Radius'),
                        Expanded(
                          child: Slider(
                            value: _radiusKm,
                            min: 1,
                            max: 50,
                            divisions: 49,
                            label: '${_radiusKm.round()} km',
                            onChanged: (v) => setState(() => _radiusKm = v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pushResults,
                icon: const Icon(Icons.search),
                label: const Text('Show results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
