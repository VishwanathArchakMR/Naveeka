// lib/ui/theme/theme.dart

import 'package:flutter/material.dart';

/// Enum for all emotions in the app.
/// Backend-compatible with the `emotion` field in `/api/places`.
enum EmotionKind {
  peaceful,
  adventure,
  spiritual,
  nature,
  heritage,
  stay,
}

/// Holds theme values (colors, gradients, glows) for an EmotionKind.
/// - accent: brand accent for the emotion
/// - glow: soft halo derived from accent using Color.withValues(alpha: ...)
/// - chipBg: translucent background derived from accent using Color.withValues
/// Note: glow/chipBg are computed with wide-gamut safe withValues (no withOpacity).
class EmotionTheme {
  final EmotionKind kind;
  final Gradient gradient;
  final Color accent;
  final Color glow;
  final Color chipBg;

  const EmotionTheme({
    required this.kind,
    required this.gradient,
    required this.accent,
    required this.glow,
    required this.chipBg,
  });

  /// Returns the EmotionTheme for the given kind.
  /// Colors are derived using withValues for alpha precision (wide-gamut safe).
  static EmotionTheme of(EmotionKind kind) {
    // Define emotion accents and gradients (const-friendly).
    switch (kind) {
      case EmotionKind.peaceful: {
        const accent = Color(0xFF74EBD5);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFF74EBD5), Color(0xFFACB6E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
      case EmotionKind.adventure: {
        const accent = Color(0xFFFF512F);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFF09819)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
      case EmotionKind.spiritual: {
        const accent = Color(0xFF9B51E0);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
      case EmotionKind.nature: {
        const accent = Color(0xFF56AB2F);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
      case EmotionKind.heritage: {
        const accent = Color(0xFFC29062);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFFC79081), Color(0xFFDEA579)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
      case EmotionKind.stay: {
        const accent = Color(0xFF00C6FF);
        final glow = accent.withValues(alpha: 0.50);
        final chip = accent.withValues(alpha: 0.20);
        return EmotionTheme(
          kind: kind,
          gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accent: accent,
          glow: glow,
          chipBg: chip,
        );
      }
    }
  }
}

/* Example Usage:

final theme = EmotionTheme.of(EmotionKind.adventure);

Container(
  decoration: BoxDecoration(gradient: theme.gradient),
);

Text(
  "Adventure",
  style: TextStyle(color: EmotionTheme.of(EmotionKind.adventure).accent),
);

*/
