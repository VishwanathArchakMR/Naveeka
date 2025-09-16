// lib/ui/theme/app_colors.dart

import 'package:flutter/material.dart';

/// Brand color tokens (const-safe).
class AppBrand {
  const AppBrand._();

  // Primary brand seeds (kept to match existing gradient usage).
  static const Color brandBlue = Color(0xFF2FB5FF);
  static const Color brandGreen = Color(0xFF2BD18B);

  // Default seed for ColorScheme generation.
  static const Color seed = brandBlue;

  // Common gradient used in GradientTopBar, etc.
  static const List<Color> gradient = <Color>[brandBlue, brandGreen];
}

/// Factory for ColorSchemes using Material 3 seed generation.
class AppColorSchemes {
  const AppColorSchemes._();

  /// Light scheme from a seed color (Material 3 tonal palettes).
  static ColorScheme light({Color seed = AppBrand.seed}) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
  }

  /// Dark scheme from a seed color (Material 3 tonal palettes).
  static ColorScheme dark({Color seed = AppBrand.seed}) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
  }
}

/// Theme builders that respect M3 and the app’s color tokens.
class AppThemes {
  const AppThemes._();

  static ThemeData light({Color seed = AppBrand.seed}) {
    final scheme = AppColorSchemes.light(seed: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData dark({Color seed = AppBrand.seed}) {
    final scheme = AppColorSchemes.dark(seed: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Convenience helpers for common alpha/surface tokens used across UI.
/// Uses Color.withValues to comply with wide-gamut color changes.
extension AppColorTokens on ColorScheme {
  /// Neutral container for cards/chips/background blocks (modern M3 surface).
  Color get containerNeutral => surfaceContainerHighest;

  /// Subtle border for elevated surfaces.
  Color get containerStroke => outlineVariant;

  /// Soft overlay chip background used in overlays and fabs.
  Color get overlayChipBg => surfaceContainerHighest.withValues(alpha: 0.92);

  /// Skeleton block color (shimmer base).
  Color get skeletonBlock => onSurfaceVariant.withValues(alpha: 0.08);

  /// Skeleton block soft (shimmer secondary).
  Color get skeletonBlockSoft => onSurfaceVariant.withValues(alpha: 0.06);

  /// Scrim used in modal barriers (wide-gamut alpha).
  Color get scrimStrong => surface.withValues(alpha: 0.65);

  /// Primary tinted “halo” used in map/user markers.
  Color get haloPrimary => primary.withValues(alpha: 0.16);

  /// Success/tertiary tinted chip background.
  Color get haloTertiary => tertiary.withValues(alpha: 0.16);

  /// Error tinted chip background.
  Color get haloError => error.withValues(alpha: 0.16);
}

/// Small blending helpers to derive emphasized colors without opacity API.
extension AppBlend on Color {
  /// Linear blend with another color by factor t in [0, 1].
  Color blend(Color other, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final r = (red + (other.red - red) * clamped).round();
    final g = (green + (other.green - green) * clamped).round();
    final b = (blue + (other.blue - blue) * clamped).round();
    final a = (alpha + (other.alpha - alpha) * clamped).round();
    return Color.fromARGB(a, r, g, b);
  }

  /// Set only alpha using wide-gamut safe values.
  Color withAlphaValue(double alpha) => withValues(alpha: alpha.clamp(0.0, 1.0));
}
