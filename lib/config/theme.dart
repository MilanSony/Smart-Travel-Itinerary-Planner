import 'package:flutter/material.dart';

class AppTheme {
  // --- Light Theme Colors ---
  static final Color lightPrimaryColor = Colors.deepPurple.shade600;
  static const Color lightBackgroundColor = Colors.transparent;
  static const Color lightTextColor = Color(0xFF333333);
  static const Color lightSubtleTextColor = Color(0xFF757575);

  // --- Dark Theme Colors ---
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