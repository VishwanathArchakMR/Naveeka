// lib/features/quick_actions/presentation/planning/planning_screen.dart

import 'package:flutter/material.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planning')),
      body: const Center(child: Text('Planning Screen')),
    );
  }
}
