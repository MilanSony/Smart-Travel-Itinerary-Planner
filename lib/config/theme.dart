import 'package:flutter/material.dart';

class AppTheme {
  // --- Modern Professional Theme Colors ---
  // Primary: Dark Navy Blue
  static const Color primaryNavy = Color(0xFF1E3A5F);
  static const Color primaryNavyLight = Color(0xFF2C4F7C);
  static const Color primaryNavyDark = Color(0xFF152A47);

  // Accent: Vibrant Orange
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentOrangeLight = Color(0xFFFF8C42);
  static const Color accentPurple = Color(0xFF6C5CE7);
  static const Color accentBlue = Color(0xFF4A90E2);

  // Background Colors
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightBackgroundAlt = Color(0xFFE8ECF1);
  static const Color cardBackground = Colors.white;
  static const Color cardShadow = Color(0x0D000000);

  // Text Colors
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextTertiary = Color(0xFF718096);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkCardBackground = Color(0xFF1A1F2E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFA0AEC0);

  // --- Light Theme Colors (Legacy) ---
  static final Color lightPrimaryColor = Colors.deepPurple.shade600;
  static const Color lightBackgroundColor = Colors.transparent;
  static const Color lightTextColor = Color(0xFF333333);
  static const Color lightSubtleTextColor = Color(0xFF757575);

  // --- Dark Theme Colors (Legacy) ---
  static final Color darkPrimaryColor = Colors.deepPurple.shade300;
  static const Color darkBackgroundColor = Colors.transparent;
  static const Color darkTextColor = Colors.white;
  static const Color darkSubtleTextColor = Colors.white70;

  // --- Light Theme Definition ---
  static final ThemeData lightTheme = ThemeData(
    primaryColor: lightPrimaryColor,
    scaffoldBackgroundColor: lightBackgroundColor,
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    cardColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF2C1D57),
      elevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightTextColor),
      bodyMedium: TextStyle(color: lightTextColor),
      bodySmall: TextStyle(color: lightSubtleTextColor),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightPrimaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: lightSubtleTextColor),
      prefixIconColor: lightSubtleTextColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // --- Dark Theme Definition ---
  static final ThemeData darkTheme = ThemeData(
    primaryColor: darkPrimaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    cardColor: const Color(0xFF2C1D57),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1F123D),
      elevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkTextColor),
      bodyMedium: TextStyle(color: darkTextColor),
      bodySmall: TextStyle(color: darkSubtleTextColor),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C1D57),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: darkPrimaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: darkSubtleTextColor),
      prefixIconColor: darkSubtleTextColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
        foregroundColor: const Color(0xFF1F123D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}