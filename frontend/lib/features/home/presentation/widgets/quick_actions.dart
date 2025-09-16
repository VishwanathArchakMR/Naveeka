// lib/features/home/presentation/widgets/quick_actions.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:naveeka/navigation/route_names.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          _QuickActionButton(
            icon: Icons.calendar_today_rounded,
            label: 'Booking',
            routeName: RouteNames.booking,
          ),
          _QuickActionButton(
            icon: Icons.history_rounded,
            label: 'History',
            routeName: RouteNames.history,
          ),
          _QuickActionButton(
            icon: Icons.favorite_border_rounded,
            label: 'Favorites',
            routeName: RouteNames.favorites,
          ),
          _QuickActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Following',
            routeName: RouteNames.following,
          ),
          _QuickActionButton(
            icon: Icons.event_note_rounded,
            label: 'Planning',
            routeName: RouteNames.planning,
          ),
          _QuickActionButton(
            icon: Icons.message_outlined,
            label: 'Messages',
            routeName: RouteNames.messages,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.routeName,
  });

  final IconData icon;
  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => context.goNamed(routeName),
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
