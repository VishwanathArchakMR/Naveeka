// lib/features/journey/presentation/trains/train_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'widgets/train_card.dart';
import 'train_booking_screen.dart';
import '../../data/trains_api.dart';

class TrainResultsScreen extends StatefulWidget {
  const TrainResultsScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.dateIso, // YYYY-MM-DD
    this.initialClassCode, // e.g., '3A','SL','2S'
    this.initialQuota, // 'GN','TQ',...
    this.currency = '₹',
    this.title = 'Trains',
    this.pageSize = 20,
    this.sort = 'price_asc', // price_asc | duration_asc | dep_asc
  });

  final String fromCode;
  final String toCode;
  final String dateIso;

  final String? initialClassCode;
  final String? initialQuota;

  final String currency;
  final String title;
  final int pageSize;
  final String sort;

  @override
  State<TrainResultsScreen> createState() => _TrainResultsScreenState();
}

class _TrainResultsScreenState extends State<TrainResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  String? _sort;
  Map<String, dynamic> _filters = {}; // classCode, quota, departStartHour, departEndHour

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
    // seed initial filters
    _filters = {
      if (widget.initialClassCode != null) 'classCode': widget.initialClassCode,
      if (widget.initialQuota != null) 'quota': widget.initialQuota,
    };
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
    if (_loadMore || _loading || !_hasMore) return;
    final pos = _scrollCtrl.position;
    final trigger = pos.maxScrollExtent * 0.9;
    if (pos.pixels > trigger) {
      _fetch();
    }
  } // Infinite scrolling uses a ScrollController threshold (~90%) to load the next page efficiently. [21][10]

  Future<void> _refresh() async {
    await _fetch(reset: true);
  } // Pull-to-refresh wraps the list in RefreshIndicator with an async onRefresh callback. [1][4]

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TrainFiltersSheet(
        classCode: _filters['classCode'] as String?,
        quota: _filters['quota'] as String?,
        departStartHour: _filters['departStartHour'] as int? ?? 0,
        departEndHour: _filters['departEndHour'] as int? ?? 24,
      ),
    ); // showModalBottomSheet returns a result via Navigator.pop, making filters modular and easy to apply. [12][6]
    if (res != null) {
      setState(() => _filters = res);
      await _fetch(reset: true);
    }
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

    final api = TrainsApi();
    final res = await api.search(
      from: widget.fromCode,
      to: widget.toCode,
      date: widget.dateIso,
      sort: _sort,
      page: _page,
      limit: widget.pageSize,
      classCode: _filters['classCode'] as String?,
      quota: _filters['quota'] as String?,
      departStartHour: _filters['departStartHour'] as int?,
      departEndHour: _filters['departEndHour'] as int?,
    );

    res.fold(
      onSuccess: (data) {
        final list = _asList(data);
        final normalized = list.map(_normalize).toList(growable: false);
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load trains')),
        );
      },
    );
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    final results = payload['results'];
    if (results is List) return List<Map<String, dynamic>>.from(results);
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> m) {
    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null) return v as T?;
      }
      return null;
    }

    DateTime? dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    num? n(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    Map<String, bool> classesFrom(dynamic v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val == true));
      }
      if (v is List) {
        final out = <String, bool>{};
        for (final e in v) {
          if (e is String) out[e] = true;
          if (e is Map && e['code'] != null) out[e['code'].toString()] = e['available'] == true;
        }
        return out;
      }
      return const {};
    }

    return {
      'id': (pick(['id', 'trainId']) ?? '').toString(),
      'trainName': (pick(['trainName', 'name']) ?? '').toString(),
      'trainNumber': (pick(['trainNumber', 'number']) ?? '').toString(),
      'fromCode': (pick(['from', 'origin']) ?? widget.fromCode).toString(),
      'toCode': (pick(['to', 'destination']) ?? widget.toCode).toString(),
      'dep': dt(pick(['departureTime', 'dep'])),
      'arr': dt(pick(['arrivalTime', 'arr'])),
      'durationLabel': pick(['durationLabel', 'duration'])?.toString(),
      'classes': classesFrom(pick(['classes', 'coachAvailability'])),
      'fareFrom': n(pick(['fareFrom', 'price', 'amount'])),
      'badges': (m['badges'] is List) ? List<String>.from(m['badges']) : const <String>[],
    };
  }

  void _openBooking(Map<String, dynamic> t) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TrainBookingScreen(
        trainId: (t['id'] ?? '').toString(),
        trainName: (t['trainName'] ?? '').toString(),
        fromCode: (t['fromCode'] ?? widget.fromCode).toString(),
        toCode: (t['toCode'] ?? widget.toCode).toString(),
        departureIso: widget.dateIso,
        currency: widget.currency,
        initialClassCode: _filters['classCode'] as String?,
        initialQuota: _filters['quota'] as String?,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    final sub = '${widget.fromCode} → ${widget.toCode} • ${widget.dateIso} • ${df.format(DateTime.parse(widget.dateIso))}';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ), // Filters are presented via a modal bottom sheet for focused, contextual adjustments. [12][15]
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: _items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader();
              if (index == _items.length + 1) return _buildFooterLoader();
              final t = _items[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TrainCard(
                  id: (t['id'] ?? '').toString(),
                  trainName: (t['trainName'] ?? '').toString(),
                  trainNumber: t['trainNumber']?.toString(),
                  fromCode: (t['fromCode'] ?? '').toString(),
                  toCode: (t['toCode'] ?? '').toString(),
                  departureTime: t['dep'],
                  arrivalTime: t['arr'],
                  viaStations: const <String>[],
                  durationLabel: t['durationLabel']?.toString(),
                  classes: (t['classes'] as Map).cast<String, bool>(),
                  fareFrom: t['fareFrom'] as num?,
                  currency: widget.currency,
                  badges: (t['badges'] as List).cast<String>(),
                  onTap: () => _openBooking(t),
                  onBook: () => _openBooking(t),
                ),
              );
            },
          ),
        ), // RefreshIndicator.adaptive provides platform-appropriate pull-to-refresh UX across iOS/Android. [1][4]
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} trains',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _sort,
              isDense: true,
              icon: const Icon(Icons.sort),
              onChanged: (v) async {
                setState(() => _sort = v);
                await _fetch(reset: true);
              },
              items: const [
                DropdownMenuItem(value: 'price_asc', child: Text('Price (low to high)')),
                DropdownMenuItem(value: 'duration_asc', child: Text('Duration (shortest)')),
                DropdownMenuItem(value: 'dep_asc', child: Text('Departure (earliest)')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sort',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ); // A simple sort dropdown offers quick reordering without leaving the results screen. [21]
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
        child: Center(
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No more results')),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TrainFiltersSheet extends StatefulWidget {
  const _TrainFiltersSheet({
    required this.classCode,
    required this.quota,
    required this.departStartHour,
    required this.departEndHour,
  });

  final String? classCode;
  final String? quota;
  final int departStartHour;
  final int departEndHour;

  @override
  State<_TrainFiltersSheet> createState() => _TrainFiltersSheetState();
}

class _TrainFiltersSheetState extends State<_TrainFiltersSheet> {
  late String? _classCode;
  late String? _quota;
  late RangeValues _depart; // 0..24

  @override
  void initState() {
    super.initState();
    _classCode = widget.classCode;
    _quota = widget.quota ?? 'GN';
    _depart = RangeValues(
      (widget.departStartHour).clamp(0, 24).toDouble(),
      (widget.departEndHour).clamp(0, 24).toDouble(),
    );
  }

  void _apply() {
    Navigator.of(context).pop(<String, dynamic>{
      'classCode': _classCode,
      'quota': _quota,
      'departStartHour': _depart.start.round(),
      'departEndHour': _depart.end.round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    const classes = ['1A', '2A', '3A', '3E', 'SL', 'CC', '2S'];
    const quotas = ['GN', 'TQ', 'LD', 'PT', 'SS', 'HO'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton(onPressed: () {
                setState(() {
                  _classCode = null;
                  _quota = 'GN';
                  _depart = const RangeValues(0, 24);
                });
              }, child: const Text('Reset')),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),

          // Class
          Align(alignment: Alignment.centerLeft, child: Text('Class', style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: classes.map((c) {
              final sel = _classCode == c;
              return ChoiceChip(
                label: Text(c),
                selected: sel,
                onSelected: (_) => setState(() => _classCode = c),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Quota
          Align(alignment: Alignment.centerLeft, child: Text('Quota', style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quotas.map((q) {
              final sel = _quota == q;
              return ChoiceChip(
                label: Text(q),
                selected: sel,
                onSelected: (_) => setState(() => _quota = q),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Departure window
          Align(alignment: Alignment.centerLeft, child: Text('Departure window', style: Theme.of(context).textTheme.labelLarge)),
          RangeSlider(
            values: _depart,
            min: 0,
            max: 24,
            divisions: 24,
            labels: RangeLabels('${_depart.start.round()}:00', '${_depart.end.round()}:00'),
            onChanged: (v) => setState(() => _depart = v),
          ),

          const SizedBox(height: 16),
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
