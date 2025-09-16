// lib/features/journey/presentation/activities/activity_results_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/activities_api.dart';
import 'widgets/activity_card.dart';
import 'widgets/activity_map_view.dart';

class ActivityResultsScreen extends StatefulWidget {
  const ActivityResultsScreen({
    super.key,
    // Optional geo/text filters (mirrors ActivitiesApi.listActivities signature)
    this.city,
    this.region,
    this.lat,
    this.lng,
    this.radiusKm,
    this.q,
    this.category,
    this.emotion,
    this.tags,
    this.minPrice,
    this.maxPrice,
    this.minDurationMinutes,
    this.maxDurationMinutes,
    this.sort = 'popular',
    this.title = 'Activities',
    this.initialView = ResultsView.list,
    this.pageSize = 20,
  });

  final String? city;
  final String? region;
  final double? lat;
  final double? lng;
  final double? radiusKm;

  final String? q;
  final String? category;
  final String? emotion;
  final List<String>? tags;

  final double? minPrice;
  final double? maxPrice;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;

  final String? sort;
  final String title;
  final ResultsView initialView;
  final int pageSize;

  @override
  State<ActivityResultsScreen> createState() => _ActivityResultsScreenState();
}

enum ResultsView { list, map }

class _ActivityResultsScreenState extends State<ActivityResultsScreen> {
  final _scrollCtrl = ScrollController();

  ResultsView _view = ResultsView.list;
  String? _sort;
  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _sort = widget.sort;
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_view != ResultsView.list) return;
    if (_loadMore || _loading || !_hasMore) return;
    final pos = _scrollCtrl.position;
    final trigger = pos.maxScrollExtent * 0.9;
    if (pos.pixels > trigger) {
      _fetch();
    }
  }

  Future<void> _refresh() async {
    await _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadMore = false;
        _hasMore = true;
        _page = 1;
        _items.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loadMore = true);
    }

    final api = ActivitiesApi();
    final res = await api.listActivities(
      page: _page,
      limit: widget.pageSize,
      q: widget.q,
      category: widget.category,
      emotion: widget.emotion,
      tags: widget.tags,
      minPrice: widget.minPrice,
      maxPrice: widget.maxPrice,
      minDurationMinutes: widget.minDurationMinutes,
      maxDurationMinutes: widget.maxDurationMinutes,
      region: widget.region,
      // placeId omitted; region/city/lat/lng/radius are supported
      lat: widget.lat,
      lng: widget.lng,
      radiusKm: widget.radiusKm,
      sort: _sort,
    );

    res.fold(
      onSuccess: (data) {
        final list = _asList(data);
        final normalized = list.map(_normalizeActivity).toList();
        setState(() {
          _items.addAll(normalized);
          _hasMore = list.length >= widget.pageSize;
          if (_hasMore) _page += 1;
          _loading = false;
          _loadMore = false;
        });
      },
      onError: (err) {
        setState(() {
          _loading = false;
          _loadMore = false;
          _hasMore = false;
        });
        _snack(err.safeMessage ?? 'Failed to load activities');
      },
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    // fallback: support {results:[...]}
    final results = payload['results'];
    if (results is List) {
      return List<Map<String, dynamic>>.from(results);
    }
    return const <Map<String, dynamic>>[];
  }

  // Normalize heterogenous API maps to a unified card/map format.
  Map<String, dynamic> _normalizeActivity(Map<String, dynamic> a) {
    String? firstOf(List keys) {
      for (final k in keys) {
        final v = a[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    double? toDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    num? toNum(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    return <String, dynamic>{
      'id': firstOf(['id', '_id', 'uuid']) ?? '',
      'title': firstOf(['title', 'name']) ?? 'Activity',
      'imageUrl': firstOf(['imageUrl', 'thumbnail', 'image', 'cover']),
      'rating': toDouble(a['rating'] ?? a['avgRating']),
      'ratingCount': toInt(a['ratingCount'] ?? a['reviews']),
      'priceFrom': toNum(a['priceFrom'] ?? a['fromPrice'] ?? a['price']),
      'currency': firstOf(['currency', 'currencyCode']) ?? '₹',
      'durationLabel': firstOf(['durationLabel', 'duration']),
      'locationLabel': firstOf(['locationLabel', 'city', 'region']),
      'lat': toDouble(a['lat'] ?? a['latitude']),
      'lng': toDouble(a['lng'] ?? a['longitude']),
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // View toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<ResultsView>(
              segments: const [
                ButtonSegment(value: ResultsView.list, icon: Icon(Icons.view_agenda), label: Text('List')),
                ButtonSegment(value: ResultsView.map, icon: Icon(Icons.map_outlined), label: Text('Map')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _view == ResultsView.list ? _buildList() : _buildMap(),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }
          final i = index - 1;
          if (i >= _items.length) {
            return _buildFooterLoader();
          }
          final a = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ActivityCard(
              id: (a['id'] ?? '').toString(),
              title: (a['title'] ?? '').toString(),
              imageUrl: a['imageUrl'] as String?,
              rating: (a['rating'] as num?)?.toDouble(),
              ratingCount: a['ratingCount'] as int?,
              priceFrom: a['priceFrom'] as num?,
              currency: (a['currency'] ?? '₹').toString(),
              durationLabel: a['durationLabel'] as String?,
              locationLabel: a['locationLabel'] as String?,
              lat: (a['lat'] as num?)?.toDouble(),
              lng: (a['lng'] as num?)?.toDouble(),
              onTap: () {
                // Navigate to details screen when wired
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} results',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: _sort,
              icon: const Icon(Icons.sort),
              onChanged: (v) async {
                setState(() => _sort = v);
                await _fetch(reset: true);
              },
              items: const [
                DropdownMenuItem(value: 'popular', child: Text('Popular')),
                DropdownMenuItem(value: 'rating_desc', child: Text('Rating')),
                DropdownMenuItem(value: 'price_asc', child: Text('Price (low to high)')),
                DropdownMenuItem(value: 'new', child: Text('Newest')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sort by',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLoader() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (!_hasMore) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  Widget _buildMap() {
    final center = _resolveCenter();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          if (_items.isEmpty && _loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const Expanded(
              child: Center(child: Text('No activities to show')),
            )
          else
            Expanded(
              child: ActivityMapView(
                activities: _items,
                initialCenter: center,
                initialZoom: 12,
              ),
            ),
        ],
      ),
    );
  }

  LatLng? _resolveCenter() {
    if (widget.lat != null && widget.lng != null) {
      return LatLng(widget.lat!, widget.lng!);
    }
    for (final a in _items) {
      final lat = (a['lat'] as num?)?.toDouble();
      final lng = (a['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }
}
