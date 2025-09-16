// lib/features/home/presentation/widgets/hero_section.dart

import 'package:flutter/material.dart';
import '../../../../ui/theme/app_themes.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Start with the base gradient BoxDecoration
    final baseDeco = AppThemes.naveekaGradient;

    // Extend it to include image and rounded corners
    final deco = baseDeco.copyWith(
      borderRadius: BorderRadius.circular(16),
      image: const DecorationImage(
        image: AssetImage('assets/images/hero_background.jpg'),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black26,
          BlendMode.darken,
        ),
      ),
    );

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: deco,
      child: Stack(
        children: [
          // Dark overlay for readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All-In-One Travel',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inspiration • Planning • Booking • Chat • AI Copilot',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger search focus or scroll action if needed
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search Destinations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    foregroundColor: AppThemes.naveekaBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
