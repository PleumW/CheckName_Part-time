import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Soft Pastel Coffee & Cat Colors
  static const Color latte = Color(0xFFF3ECE4); // Soft creamy oat latte / milk foam
  static const Color mocha = Color(0xFF967259); // Soft warm milk coffee / mocha
  static const Color milk = Color(0xFFFAF7F2);  // Gentle warm milk background
  static const Color accentPink = Color(0xFFFFB7B2);
  static const Color matcha = Color(0xFF5B8E92); // Soft matcha green
  static const Color textDark = Color(0xFF4A3B32); // Deep espresso text
  static const Color catGray = Color(0xFF9E9E9E);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: mocha,
      scaffoldBackgroundColor: milk,
      colorScheme: const ColorScheme.light(
        primary: mocha,
        secondary: accentPink,
        surface: latte,
        onPrimary: Colors.white,
        onSecondary: textDark,
        onSurface: textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: mocha,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.kanit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: GoogleFonts.kanitTextTheme().copyWith(
        bodyLarge: GoogleFonts.kanit(color: textDark),
        bodyMedium: GoogleFonts.kanit(color: textDark),
        displayLarge: GoogleFonts.kanit(color: textDark, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.kanit(color: textDark, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mocha,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.kanit(fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        color: latte,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
