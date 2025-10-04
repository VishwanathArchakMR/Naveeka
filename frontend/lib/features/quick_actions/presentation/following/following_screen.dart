// lib/features/quick_actions/presentation/following/following_screen.dart

import 'package:flutter/material.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: const Center(child: Text('Following Screen')),
    );
  }
}
