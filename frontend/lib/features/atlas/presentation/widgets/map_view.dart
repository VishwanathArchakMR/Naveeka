// lib/features/atlas/presentation/widgets/map_view.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../../services/location_service.dart';

class AtlasMapView extends StatefulWidget {
  final List<Place> places;
  final Function(Place) onPlaceTap;

  const AtlasMapView({
    super.key,
    required this.places,
    required this.onPlaceTap,
  });

  @override
  State<AtlasMapView> createState() => _AtlasMapViewState();
}

class _AtlasMapViewState extends State<AtlasMapView> {
  Place? _selectedPlace;
  UserLocation? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      final location = await LocationService.instance.getCurrentLocation();
      if (mounted) {
        setState(() => _userLocation = location);
      }
    } catch (e) {
      debugPrint('Error loading user location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.places.isEmpty) {
      return _buildEmptyMapState();
    }

    return Stack(
      children: [
        // Map container (placeholder for actual map implementation)
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Stack(
            children: [
              // Map background pattern
              _buildMapPattern(),
              
              // Place markers
              ...widget.places.asMap().entries.map((entry) {
                final index = entry.key;
                final place = entry.value;
                return _buildPlaceMarker(place, index);
              }),

              // User location marker
              if (_userLocation != null)
                _buildUserLocationMarker(),

              // Map controls
              _buildMapControls(),
            ],
          ),
        ),

        // Selected place bottom sheet
        if (_selectedPlace != null)
          _buildPlaceBottomSheet(),
      ],
    );
  }

  Widget _buildMapPattern() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPainter(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildPlaceMarker(Place place, int index) {
    final isSelected = _selectedPlace?.id == place.id;
    
    // Calculate position based on coordinates (simplified positioning)
    final left = (place.location.coordinates.longitude + 180) * 2; // Simplified
    final top = (90 - place.location.coordinates.latitude) * 4; // Simplified
    
    return Positioned(
      left: left.clamp(20.0, MediaQuery.of(context).size.width - 60),
      top: top.clamp(80.0, MediaQuery.of(context).size.height - 160),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPlace = isSelected ? null : place;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scale(isSelected ? 1.2 : 1.0),
          child: Container(
            width: 40,
            height: 50,
            child: Stack(
              children: [
                // Pin shadow
                Positioned(
                  bottom: 0,
                  left: 15,
                  child: Container(
                    width: 10,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Pin body
                Positioned(
                  top: 0,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getPlaceCategoryColor(place.category),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: place.emotions.isNotEmpty
                          ? Text(
                              place.emotions.first.emoji,
                              style: const TextStyle(fontSize: 12),
                            )
                          : Icon(
                              _getPlaceCategoryIcon(place.category),
                              size: 12,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Positioned(
      left: MediaQuery.of(context).size.width / 2 - 15,
      top: MediaQuery.of(context).size.height / 2 - 15,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.my_location_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          // Zoom in
          _MapControlButton(
            icon: Icons.add_rounded,
            onTap: () {
              // Implement zoom in
            },
          ),
          const SizedBox(height: 8),
          // Zoom out
          _MapControlButton(
            icon: Icons.remove_rounded,
            onTap: () {
              // Implement zoom out
            },
          ),
          const SizedBox(height: 16),
          // My location
          _MapControlButton(
            icon: Icons.my_location_rounded,
            onTap: () async {
              await _loadUserLocation();
              // Center map on user location
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedPlace!.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedPlace = null),
                  icon: const Icon(Icons.close_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedPlace!.categoryLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_selectedPlace!.emotions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    _selectedPlace!.emotionEmojis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const Spacer(),
                if (_selectedPlace!.rating > 0) ...[
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Colors.amber[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedPlace!.formattedRating,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onPlaceTap(_selectedPlace!),
                    icon: const Icon(Icons.info_outlined, size: 18),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Open directions
                  },
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMapState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No places to display',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters to find places',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlaceCategoryColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.temple:
        return Colors.orange[600]!;
      case PlaceCategory.monument:
        return Colors.brown[600]!;
      case PlaceCategory.museum:
        return Colors.purple[600]!;
      case PlaceCategory.park:
        return Colors.green[600]!;
      case PlaceCategory.beach:
        return Colors.blue[600]!;
      case PlaceCategory.mountain:
        return Colors.grey[600]!;
      case PlaceCategory.lake:
        return Colors.cyan[600]!;
      case PlaceCategory.hotel:
        return Colors.indigo[600]!;
      case PlaceCategory.restaurant:
        return Colors.red[600]!;
      case PlaceCategory.cafe:
        return Colors.amber[600]!;
      case PlaceCategory.activity:
        return Colors.pink[600]!;
      case PlaceCategory.tour:
        return Colors.teal[600]!;
      case PlaceCategory.transport:
        return Colors.lightBlue[600]!;
      case PlaceCategory.shopping:
        return Colors.deepPurple[600]!;
      case PlaceCategory.entertainment:
        return Colors.lime[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getPlaceCategoryIcon(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.temple:
        return Icons.temple_buddhist_outlined;
      case PlaceCategory.monument:
        return Icons.account_balance_outlined;
      case PlaceCategory.museum:
        return Icons.museum_outlined;
      case PlaceCategory.park:
        return Icons.park_outlined;
      case PlaceCategory.beach:
        return Icons.beach_access_outlined;
      case PlaceCategory.mountain:
        return Icons.terrain_outlined;
      case PlaceCategory.lake:
        return Icons.water_outlined;
      case PlaceCategory.hotel:
        return Icons.hotel_outlined;
      case PlaceCategory.restaurant:
        return Icons.restaurant_outlined;
      case PlaceCategory.cafe:
        return Icons.local_cafe_outlined;
      case PlaceCategory.activity:
        return Icons.local_activity_outlined;
      case PlaceCategory.tour:
        return Icons.tour_outlined;
      case PlaceCategory.transport:
        return Icons.directions_bus_outlined;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
      case PlaceCategory.entertainment:
        return Icons.local_movies_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final Color color;

  _MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Draw grid lines
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
