// lib/features/atlas/presentation/widgets/universal_search.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/place.dart';
import '../../../../services/location_service.dart';
import '../../../../navigation/route_names.dart';
import 'map_list_toggle.dart';

final universalSearchProvider = FutureProvider.family<List<Place>, String>((ref, query) async {
  if (query.isEmpty) return [];
  // Fetch all places from atlas provider
  final atlasData = await ref.read(atlasDataProvider.future);
  final allPlaces = (atlasData['places'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>()
      .map((json) => Place.fromJson(json))
      .toList();
  // Filter by name or tags
  return allPlaces.where((place) {
    final q = query.toLowerCase();
    return place.name.toLowerCase().contains(q)
        || place.tags.any((tag) => tag.toLowerCase().contains(q));
  }).toList();
});

class UniversalSearch extends ConsumerStatefulWidget {
  final void Function(String) onSearch;
  const UniversalSearch({super.key, required this.onSearch});

  @override
  ConsumerState<UniversalSearch> createState() => _UniversalSearchState();
}

class _UniversalSearchState extends ConsumerState<UniversalSearch> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value.trim());
    widget.onSearch(_query);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(universalSearchProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search places, tags, regions...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          resultsAsync.when(
            data: (places) {
              if (places.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matches found'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: places.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return ListTile(
                    title: Text(place.name),
                    subtitle: Text(place.categoryLabel),
                    leading: place.images.isNotEmpty
                        ? Image.asset(place.images.first, width: 40, height: 40, fit: BoxFit.cover)
                        : const Icon(Icons.place_outlined),
                    onTap: () {
                      _controller.clear();
                      setState(() => _query = '');
                      widget.onSearch(place.name);
                      context.pushNamed(
                        RouteNames.placeDetail,
                        pathParameters: {'id': place.id},
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error fetching results'),
            ),
          ),
      ],
    );
  }
}
