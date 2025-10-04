// lib/features/journey/presentation/flights/flight_search_screen.dart

import 'package:flutter/material.dart';

class FlightSearchScreen extends StatelessWidget {
  const FlightSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flight Search')),
      body: const Center(child: Text('Flight Search Screen')),
    );
  }
}
