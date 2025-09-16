// lib/features/quick_actions/presentation/messages/widgets/location_share.dart

import 'package:flutter/material.dart';

class LocationShare extends StatefulWidget {
  const LocationShare({
    super.key,
    required this.onLocationShared,
    this.initialLocation,
  });

  final Function(double lat, double lng, String? address) onLocationShared;
  final Map<String, double>? initialLocation;

  @override
  State<LocationShare> createState() => _LocationShareState();
}

class _LocationShareState extends State<LocationShare> {
  final TextEditingController _addressController = TextEditingController();
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _latitude = widget.initialLocation!['lat'];
      _longitude = widget.initialLocation!['lng'];
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _shareLocation() {
    if (_latitude != null && _longitude != null) {
      widget.onLocationShared(
        _latitude!,
        _longitude!,
        _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_latitude != null && _longitude != null)
            Text(
              'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _shareLocation,
                child: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}