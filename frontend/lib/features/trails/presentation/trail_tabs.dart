// lib/features/trails/presentation/trail_tabs.dart
import 'package:flutter/material.dart';

class TrailsHomeTab extends StatelessWidget {
  const TrailsHomeTab({super.key});
  @override
  Widget build(BuildContext context) => const _Centered('Trails Home');
}

class TrailsSearchTab extends StatelessWidget {
  const TrailsSearchTab({super.key});
  @override
  Widget build(BuildContext context) => const _Centered('Search');
}

class TrailsCreateTab extends StatelessWidget {
  const TrailsCreateTab({super.key});
  @override
  Widget build(BuildContext context) => const _Centered('Create');
}

class TrailsReelsTab extends StatelessWidget {
  const TrailsReelsTab({super.key});
  @override
  Widget build(BuildContext context) => const _Centered('Reels');
}

class TrailsProfileTab extends StatelessWidget {
  const TrailsProfileTab({super.key});
  @override
  Widget build(BuildContext context) => const _Centered('Profile');
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
