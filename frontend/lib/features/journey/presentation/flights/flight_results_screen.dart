// lib/features/journey/presentation/flights/flight_results_screen.dart

import 'package:flutter/material.dart';

class FlightResultsScreen extends StatelessWidget {
  const FlightResultsScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.date,
  });

  final String fromCode;
  final String toCode;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flight Results')),
      body: Center(child: Text('Flights from $fromCode to $toCode on $date')),
    );
  }
}