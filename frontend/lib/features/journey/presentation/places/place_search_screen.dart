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
    this.initialCategory = _Category.attractions,
    this.currency = '₹',
  });

  final String title;
  final String? initialDestination;
  final _Category initialCategory;
  final String currency;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

enum _Category { attractions, experiences, activities }

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  final _destCtrl = TextEditingController();

  // Optional date and center
  DateTime? _date;
  double? _centerLat;
  double? _centerLng;

  _Category _cat = _Category.attractions;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // SnackBars via ScaffoldMessenger are the recommended transient feedback pattern in Flutter apps [7]
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    ); // Use showDatePicker for a Material date dialog; it returns a Future resolving to the chosen date or null [1]
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
    ); // Present a shaped modal bottom sheet with showModalBottomSheet to pick a map center and return lat/lng via Navigator.pop [9]
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
      _Category.attractions => 'Attractions',
      _Category.experiences => 'Experiences',
      _Category.activities => 'Activities',
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
    )); // Handoff passes normalized text inputs and optional ISO date and map center to a paginated results screen following standard form→route patterns [10]
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
            ), // TextFormField is the standard input control used within Forms and supports validators when needed per cookbook patterns [10][13]

            const SizedBox(height: 12),

            // Category
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                SegmentedButton<_Category>(
                  segments: const [
                    ButtonSegment(value: _Category.attractions, label: Text('Attractions')),
                    ButtonSegment(value: _Category.experiences, label: Text('Experiences')),
                    ButtonSegment(value: _Category.activities, label: Text('Activities')),
                  ],
                  selected: {_cat},
                  onSelectionChanged: (s) => setState(() => _cat = s.first),
                ),
              ],
            ), // SegmentedButton offers a compact toggle among a small, fixed set of options, suitable for category selection in Material apps [10]

            const SizedBox(height: 12),

            // Date
            ListTile(
              onTap: _pickDate,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Optional date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ), // The Material date picker dialog opened by showDatePicker is appropriate for availability/date-prefilter in this flow [1]

            const SizedBox(height: 8),

            // Map center
            ListTile(
              onTap: _pickCenterOnMap,
              leading: const Icon(Icons.my_location),
              title: const Text('Map center'),
              subtitle: Text(centerBadge, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
            ), // Using a modal bottom sheet for the map center picker keeps the main form concise while supporting spatial relevance [9]

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ), // Submit triggers straightforward route navigation after basic input validation per cookbook guidance on form workflows [7][10]
          ],
        ),
      ),
    );
  }
}
