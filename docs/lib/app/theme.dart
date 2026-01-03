import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FledgeTheme {
  // Phantom Circuit palette
  static const Color phantom = Color(0xFF0A0A0F); // Background
  static const Color primaryColor = Color(0xFF7B2CBF); // Circuit Purple
  static const Color secondaryColor = Color(0xFF5B21B6); // Deep Purple
  static const Color purpleLight = Color(0xFF9D4EDD); // Lilac Purple
  static const Color accentColor = Color(0xFFFFD700); // Signal Gold
  static const Color lilac = Color(0xFFE0AAFF); // Soft Lilac

  // Surface colors for dark theme
  static const Color surfaceDark = Color(0xFF121218); // Elevated surface
  static const Color surfaceDark2 = Color(0xFF1A1A24); // Cards, panels

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      textTheme: _buildTextTheme(base.textTheme, Colors.black87),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: phantom,
      ),
      textTheme: _buildTextTheme(base.textTheme, Colors.white),
      scaffoldBackgroundColor: phantom,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceDark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: secondaryColor.withValues(alpha: 0.3)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: secondaryColor.withValues(alpha: 0.3),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purpleLight,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.7,
        color: color.withValues(alpha: 0.87),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: color.withValues(alpha: 0.87),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  // Code block styling
  static TextStyle get codeStyle => GoogleFonts.firaCode(
        fontSize: 14,
        height: 1.5,
      );
}
