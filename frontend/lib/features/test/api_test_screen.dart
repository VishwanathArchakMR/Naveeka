// lib/features/test/api_test_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../main.dart';

class ApiTestScreen extends ConsumerStatefulWidget {
  const ApiTestScreen({super.key});

  @override
  ConsumerState<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends ConsumerState<ApiTestScreen> {
  String _status = 'Ready to test';
  List<dynamic> _activities = [];
  List<dynamic> _places = [];
  List<dynamic> _regions = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final apiClient = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Connection Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Backend URL: ${apiClient.baseUrl}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _testHealth(apiClient),
                  child: const Text('Test Health'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _testActivities(apiClient),
                  child: const Text('Test Activities'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _testPlaces(apiClient),
                  child: const Text('Test Places'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _testRegions(apiClient),
                  child: const Text('Test Regions'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activities.isNotEmpty) ...[
                      const Text(
                        'Activities:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._activities.map((activity) => Card(
                        child: ListTile(
                          title: Text(activity['name'] ?? 'Unknown'),
                          subtitle: Text(activity['description'] ?? ''),
                          trailing: Text('₹${activity['price']?['amount'] ?? 0}'),
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (_places.isNotEmpty) ...[
                      const Text(
                        'Places:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._places.map((place) => Card(
                        child: ListTile(
                          title: Text(place['name'] ?? 'Unknown'),
                          subtitle: Text(place['description'] ?? ''),
                          trailing: Text(place['category'] ?? ''),
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (_regions.isNotEmpty) ...[
                      const Text(
                        'Regions:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._regions.map((region) => Card(
                        child: ListTile(
                          title: Text(region['name'] ?? 'Unknown'),
                          subtitle: Text(region['description'] ?? ''),
                          trailing: Text(region['type'] ?? ''),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testHealth(ApiClient apiClient) async {
    setState(() {
      _isLoading = true;
      _status = 'Testing health...';
    });

    try {
      final health = await apiClient.getHealth();
      setState(() {
        _status = 'Health check passed: ${health['status']}';
      });
    } catch (e) {
      setState(() {
        _status = 'Health check failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testActivities(ApiClient apiClient) async {
    setState(() {
      _isLoading = true;
      _status = 'Testing activities...';
    });

    try {
      final activities = await apiClient.getActivities();
      setState(() {
        _activities = activities;
        _status = 'Activities loaded: ${activities.length} items';
      });
    } catch (e) {
      setState(() {
        _status = 'Activities failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPlaces(ApiClient apiClient) async {
    setState(() {
      _isLoading = true;
      _status = 'Testing places...';
    });

    try {
      final places = await apiClient.getPlaces();
      setState(() {
        _places = places;
        _status = 'Places loaded: ${places.length} items';
      });
    } catch (e) {
      setState(() {
        _status = 'Places failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegions(ApiClient apiClient) async {
    setState(() {
      _isLoading = true;
      _status = 'Testing regions...';
    });

    try {
      final regions = await apiClient.getRegions();
      setState(() {
        _regions = regions;
        _status = 'Regions loaded: ${regions.length} items';
      });
    } catch (e) {
      setState(() {
        _status = 'Regions failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
