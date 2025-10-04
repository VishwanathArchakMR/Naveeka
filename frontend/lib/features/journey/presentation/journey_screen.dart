// lib/features/journey/presentation/journey_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/route_names.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.pushNamed(RouteNames.myBookings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildJourneyCard(
              context,
              icon: Icons.flight_takeoff,
              title: 'Flights',
              onTap: () => context.pushNamed(RouteNames.flightSearch),
            ),
            _buildJourneyCard(
              context,
              icon: Icons.train,
              title: 'Trains',
              onTap: () => context.pushNamed(RouteNames.trainSearch),
            ),
            _buildJourneyCard(
              context,
              icon: Icons.hotel,
              title: 'Hotels',
              onTap: () => context.pushNamed(RouteNames.hotelSearch),
            ),
            _buildJourneyCard(
              context,
              icon: Icons.restaurant,
              title: 'Restaurants',
              onTap: () => context.pushNamed(RouteNames.restaurantSearch),
            ),
            _buildJourneyCard(
              context,
              icon: Icons.local_activity,
              title: 'Activities',
              onTap: () => context.pushNamed(RouteNames.activitySearch),
            ),
            _buildJourneyCard(
              context,
              icon: Icons.receipt_long,
              title: 'My Bookings',
              onTap: () => context.pushNamed(RouteNames.myBookings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
