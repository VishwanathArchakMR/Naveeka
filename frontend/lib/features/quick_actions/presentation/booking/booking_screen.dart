// lib/features/quick_actions/presentation/booking/booking_screen.dart

import 'package:flutter/material.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    this.initialQuery = '',
    this.initialLocation,
    this.initialDateRange,
    this.initialGuests = 2,
    this.originLat,
    this.originLng,
    this.mapBuilder,
  });

  final String initialQuery;
  final dynamic initialLocation;
  final DateTimeRange? initialDateRange;
  final int initialGuests;
  final double? originLat;
  final double? originLng;
  final dynamic mapBuilder;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_online,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Booking',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Book your next adventure',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
