// lib/ui/theme/app_text_styles.dart

import 'package:flutter/material.dart';

/// Centralized typography configuration for the app.
/// - Extends the Material 3 type scale (display/headline/title/body/label)
/// - Supports custom font families and weights
/// - Applies subtle letter/height tweaks and brand emphasis where needed
/// - Uses ColorScheme roles for on-surface colors and emphasis via withValues()
class AppTypography {
  const AppTypography._();

  /// Build a TextTheme derived from the given ColorScheme.
  /// Optionally override font families for sans/mono and set a stronger weight baseline.
  static TextTheme textTheme({
    required ColorScheme colors,
    String? fontSans, // e.g., 'Inter', 'Roboto', 'SF Pro'
    String? fontMono, // e.g., 'JetBrains Mono'
    bool boldTitles = true,
  }) {
    // Base M3 text theme as a starting point.
    final base = Typography.material2021(platform: TargetPlatform.android).black;

    // Helper to apply family and color to a style.
    TextStyle s(TextStyle? t, {bool title = false, bool label = false, double? ls, double? lh}) {
      final weight = title && boldTitles
          ? FontWeight.w700
          : (label ? FontWeight.w600 : (t?.fontWeight ?? FontWeight.w400));
      return (t ?? const TextStyle()).copyWith(
        fontFamily: fontSans,
        color: colors.onSurface,
        fontWeight: weight,
        letterSpacing: ls ?? t?.letterSpacing,
        height: lh ?? t?.height,
      );
    }

    // Secondary color style for "variant" text
    TextStyle variant(TextStyle? t, {bool label = false}) {
      return (t ?? const TextStyle()).copyWith(
        fontFamily: fontSans,
        color: colors.onSurfaceVariant,
        fontWeight: label ? FontWeight.w600 : (t?.fontWeight ?? FontWeight.w400),
        letterSpacing: t?.letterSpacing,
        height: t?.height,
      );
    }

    // Emphasis helpers
    TextStyle emph(TextStyle? t) => (t ?? const TextStyle()).copyWith(
          fontFamily: fontSans,
          color: colors.onSurface.withValues(alpha: 0.92),
          fontWeight: FontWeight.w800,
        );

    // Build the full set, nudging titles for brand emphasis and readability.
    return TextTheme(
      // Display — large hero text, keep default scale but ensure color/weight.
      displayLarge: s(base.displayLarge),
      displayMedium: s(base.displayMedium),
      displaySmall: s(base.displaySmall),

      // Headline — section and large content headers.
      headlineLarge: s(base.headlineLarge, title: true),
      headlineMedium: s(base.headlineMedium, title: true),
      headlineSmall: s(base.headlineSmall, title: true),

      // Title — app bars, cards, and list titles (strong emphasis).
      titleLarge: emph(base.titleLarge),
      titleMedium: s(base.titleMedium, title: true),
      titleSmall: s(base.titleSmall, title: true),

      // Body — paragraphs and supporting text (variant for secondary).
      bodyLarge: s(base.bodyLarge),
      bodyMedium: s(base.bodyMedium),
      bodySmall: variant(base.bodySmall),

      // Label — component text (buttons/chips/inputs).
      labelLarge: s(base.labelLarge, label: true),
      labelMedium: s(base.labelMedium, label: true),
      labelSmall: variant(base.labelSmall, label: true),
    ).apply(
      // Optional monospace for code fragments via theme extension if needed.
      // Use copyWith on specific widgets for mono when required.
      fontFamily: fontSans,
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
  }

  /// Optional monospace style for code and coordinates.
  static TextStyle mono({
    required ColorScheme colors,
    String? fontMono,
    double size = 13,
    double height = 1.35,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: fontMono,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: colors.onSurface,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Subtle caption style using onSurfaceVariant, useful for helper text.
  static TextStyle caption({
    required ColorScheme colors,
    double size = 12,
    double height = 1.25,
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: colors.onSurfaceVariant,
    );
  }

  /// Emphasized chip/tag style for small UI badges.
  static TextStyle tag({
    required ColorScheme colors,
    double size = 11,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: colors.onSurface,
      letterSpacing: 0.2,
    );
  }
}

/// Apply AppTypography text theme to ThemeData conveniently.
extension AppTextTheme on ThemeData {
  ThemeData withAppText({
    String? fontSans,
    String? fontMono,
    bool boldTitles = true,
  }) {
    final scheme = colorScheme;
    final tt = AppTypography.textTheme(
      colors: scheme,
      fontSans: fontSans,
      fontMono: fontMono,
      boldTitles: boldTitles,
    );
    return copyWith(
      textTheme: tt,
      primaryTextTheme: tt.copyWith(
        // Primary overlays often sit on tinted surfaces; keep stronger contrast.
        titleLarge: tt.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
        titleMedium: tt.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
        titleSmall: tt.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
        labelLarge: tt.labelLarge?.copyWith(color: scheme.onPrimary),
      ),
    );
  }
}
