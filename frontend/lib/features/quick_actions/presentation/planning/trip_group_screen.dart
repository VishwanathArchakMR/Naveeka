// lib/features/quick_actions/presentation/planning/trip_group_screen.dart

import 'package:flutter/material.dart';

class TripGroupScreen extends StatelessWidget {
  const TripGroupScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
  });

  final String groupId;
  final String groupTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(groupTitle)),
      body: Center(child: Text('Trip Group: $groupId')),
    );
  }
}
