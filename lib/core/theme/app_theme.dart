import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep ethereal dark background palette
  static const Color backgroundDark = Color(0xFF0F121C);
  static const Color surfaceDark = Color(0xFF192032);
  
  // Translucent glass colors
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassWhiteStrong = Color(0x28FFFFFF);

  // Modern cyan accents & minimal line-art doodle palette
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentPurple = Color(0xFF818CF8);
  static const Color doodleLine = Color(0xFFE2E8F0);
  static const Color subtleText = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentPurple,
        surface: surfaceDark,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: doodleLine,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: subtleText,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(
        color: doodleLine,
        size: 22,
      ),
    );
  }
}
