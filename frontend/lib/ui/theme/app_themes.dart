import 'package:flutter/material.dart';

class AppThemes {
  /// Font families
  static const String primaryFont = 'Inter';
  static const String secondaryFont = 'Poppins';

  /// Naveeka Brand Colors (Blue → Green → Purple gradient)
  static const Color naveekaBlue = Color(0xFF2fb5ff);
  static const Color naveekaGreen = Color(0xFF2bd18b);
  static const Color naveekaPurple = Color(0xFF7a5cf0);
  
  /// Emotion Colors
  static const Color peacefulColor = Color(0xFF4CAF50); // Green for peace
  static const Color spiritualColor = Color(0xFFFF9800); // Orange for spiritual
  static const Color adventureColor = Color(0xFFf44336); // Red for adventure
  static const Color heritageColor = Color(0xFF795548); // Brown for heritage

  /// Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: primaryFont,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: naveekaBlue,
        brightness: Brightness.light,
        primary: naveekaBlue,
        secondary: naveekaGreen,
        tertiary: naveekaPurple,
      ),
      
      scaffoldBackgroundColor: const Color(0xFFFAFBFC),
      
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1A1A),
        titleTextStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Color(0xFF1A1A1A),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: naveekaBlue,
        unselectedItemColor: Color(0xFF9E9E9E),
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      
      inputDecorationTheme: _inputTheme(brightness: Brightness.light),
      elevatedButtonTheme: _elevatedButtonTheme(brightness: Brightness.light),
      filledButtonTheme: _filledButtonTheme(brightness: Brightness.light),
      textButtonTheme: _textButtonTheme(brightness: Brightness.light),
      outlinedButtonTheme: _outlinedButtonTheme(brightness: Brightness.light),
      cardTheme: _cardTheme(brightness: Brightness.light),
      chipTheme: _chipTheme(brightness: Brightness.light),
      
      // Text Theme with Inter + Poppins
      textTheme: _textTheme(brightness: Brightness.light),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: primaryFont,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: naveekaBlue,
        brightness: Brightness.dark,
        primary: naveekaBlue,
        secondary: naveekaGreen,
        tertiary: naveekaPurple,
      ),
      
      scaffoldBackgroundColor: const Color(0xFF0A0A0B),
      
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      
      // Bottom Navigation Dark
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: naveekaBlue,
        unselectedItemColor: Color(0xFF6B6B6B),
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: primaryFont,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      
      inputDecorationTheme: _inputTheme(brightness: Brightness.dark),
      elevatedButtonTheme: _elevatedButtonTheme(brightness: Brightness.dark),
      filledButtonTheme: _filledButtonTheme(brightness: Brightness.dark),
      textButtonTheme: _textButtonTheme(brightness: Brightness.dark),
      outlinedButtonTheme: _outlinedButtonTheme(brightness: Brightness.dark),
      cardTheme: _cardTheme(brightness: Brightness.dark),
      chipTheme: _chipTheme(brightness: Brightness.dark),
      
      textTheme: _textTheme(brightness: Brightness.dark),
    );
  }

  /// Gradient Decorations for Naveeka Branding
  static BoxDecoration get naveekaGradient => const BoxDecoration(
    gradient: LinearGradient(
      colors: [naveekaBlue, naveekaGreen, naveekaPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static BoxDecoration get naveekaGradientCard => BoxDecoration(
    gradient: const LinearGradient(
      colors: [naveekaBlue, naveekaGreen, naveekaPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
  );

  /// Text Theme (Inter + Poppins)
  static TextTheme _textTheme({required Brightness brightness}) {
    final baseColor = brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = brightness == Brightness.dark ? Colors.white70 : const Color(0xFF6B6B6B);
    
    return TextTheme(
      // Display styles (Poppins for headers)
      displayLarge: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displayMedium: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      displaySmall: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      
      // Headline styles (Poppins)
      headlineLarge: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: secondaryFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      
      // Title styles (Inter)
      titleLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      
      // Body styles (Inter)
      bodyLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodySmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: subtitleColor,
      ),
      
      // Label styles (Inter)
      labelLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelMedium: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelSmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: subtitleColor,
      ),
    );
  }

  /// Input Decoration Theme
  static InputDecorationTheme _inputTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: naveekaBlue,
          width: 2,
        ),
      ),
      labelStyle: TextStyle(
        fontFamily: primaryFont,
        color: isDark ? Colors.white70 : const Color(0xFF6B6B6B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Elevated Button Theme
  static ElevatedButtonThemeData _elevatedButtonTheme({required Brightness brightness}) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: naveekaBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          fontFamily: primaryFont,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: brightness == Brightness.dark ? 0 : 2,
      ),
    );
  }

  /// Filled Button Theme (for gradient buttons)
  static FilledButtonThemeData _filledButtonTheme({required Brightness brightness}) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: naveekaGreen,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          fontFamily: primaryFont,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Text Button Theme
  static TextButtonThemeData _textButtonTheme({required Brightness brightness}) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: naveekaBlue,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: primaryFont,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Outlined Button Theme
  static OutlinedButtonThemeData _outlinedButtonTheme({required Brightness brightness}) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: naveekaBlue,
        side: const BorderSide(color: naveekaBlue, width: 1.5),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: primaryFont,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Card Theme
  static CardThemeData _cardTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return CardThemeData(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      surfaceTintColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: EdgeInsets.zero,
    );
  }

  /// Chip Theme (for category chips)
  static ChipThemeData _chipTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return ChipThemeData(
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      deleteIconColor: isDark ? Colors.white70 : Colors.black54,
      disabledColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
      selectedColor: naveekaBlue.withOpacity(0.2),
      secondarySelectedColor: naveekaGreen.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      brightness: brightness,
    );
  }
}
