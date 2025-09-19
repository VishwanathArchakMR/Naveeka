// lib/features/journey/presentation/places/place_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'place_results_screen.dart';
import '../cabs/widgets/location_picker.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    this.title = 'Search things to do',
    this.initialDestination,
    this.initialCategory = Category.attractions,
    this.currency = '₹',
  });

  final String title;
  final String? initialDestination;
  final Category initialCategory;
  final String currency;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

// Public enum to avoid exposing a private type in a public API. [web:6155]
enum Category { attractions, experiences, activities }

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  final _destCtrl = TextEditingController();

  // Optional date and center
  DateTime? _date;
  double? _centerLat;
  double? _centerLng;

  Category _cat = Category.attractions;

  @override
  void initState() {
    super.initState();
    _destCtrl.text = widget.initialDestination ?? '';
    _cat = widget.initialCategory;
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickCenterOnMap() async {
    final res = await LocationPicker.show(
      context,
      title: 'Choose map center',
      initialLat: _centerLat,
      initialLng: _centerLng,
    );
    if (res != null) {
      setState(() {
        _centerLat = (res['lat'] as double?) ?? _centerLat;
        _centerLng = (res['lng'] as double?) ?? _centerLng;
      });
    }
  }

  void _search() {
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) {
      _snack('Enter a destination');
      return;
    }

    final dateIso = _date != null ? _dfIso.format(_date!) : null;
    final category = switch (_cat) {
      Category.attractions => 'Attractions',
      Category.experiences => 'Experiences',
      Category.activities => 'Activities',
    };

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaceResultsScreen(
        destination: dest,
        dateIso: dateIso,
        category: category,
        currency: widget.currency,
        centerLat: _centerLat,
        centerLng: _centerLng,
        title: 'Things to do',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null ? 'Any date' : _dfLong.format(_date!);
    final centerBadge = (_centerLat != null && _centerLng != null)
        ? 'Lat ${_centerLat!.toStringAsFixed(3)}, Lng ${_centerLng!.toStringAsFixed(3)}'
        : 'Optional';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Destination
            TextFormField(
              controller: _destCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Destination (city/area)',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Pick center on map',
                  icon: const Icon(Icons.map_outlined),
                  onPressed: _pickCenterOnMap,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Category
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                SegmentedButton<Category>(
                  segments: const [
                    ButtonSegment(value: Category.attractions, label: Text('Attractions')),
                    ButtonSegment(value: Category.experiences, label: Text('Experiences')),
                    ButtonSegment(value: Category.activities, label: Text('Activities')),
                  ],
                  selected: {_cat},
                  onSelectionChanged: (s) => setState(() => _cat = s.first),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date
            ListTile(
              onTap: _pickDate,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Optional date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ),

            const SizedBox(height: 8),

            // Map center
            ListTile(
              onTap: _pickCenterOnMap,
              leading: const Icon(Icons.my_location),
              title: const Text('Map center'),
              subtitle: Text(centerBadge, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
