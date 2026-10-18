import 'package:flutter/material.dart';

class AppTheme {
  static const Color teal = Color(0xFF1CC29F);
  static const Color tealDark = Color(0xFF148E74);
  static const Color tealLight = Color(0xFFE8F8F5);
  static const Color charcoal = Color(0xFF2C3236);
  static const Color textDark = Color(0xFF333333);
  static const Color textMuted = Color(0xFF757575);
  static const Color positiveGreen = Color(0xFF27AE60);
  static const Color negativeOrange = Color(0xFFFF652F);
  static const Color background = Color(0xFFF6F7F9);
  static const Color cardBg = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: teal,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        secondary: tealDark,
        surface: cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: charcoal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0.8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
    );
  }
}
