import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Theme Colors - ChromePulse Utility Design System
  static const Color primary = Color(0xFFB80049); // Magenta
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFE2165F);

  static const Color secondary = Color(0xFF006D37); // Emerald
  static const Color secondaryContainer = Color(0xFF6BFE9C);

  static const Color tertiary = Color(0xFF835100); // Amber
  static const Color tertiaryContainer = Color(0xFFA46700);

  static const Color error = Color(0xFFBA1A1A);
  static const Color background = Color(0xFFFFF8F8);
  static const Color surface = Color(0xFFFFF8F8);
  static const Color surfaceContainer = Color(0xFFFFE8F0);
  static const Color surfaceContainerHigh = Color(0xFFFAE2EA);

  // Editorial Gradient for Backgrounds
  static const LinearGradient editorialGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF8F8), // Soft pink start
      Color(0xFFFFE8F0), // Medium pink end
    ],
  );

  // Status Colors
  static const Color _active = secondary;
  static const Color _paused = tertiary;
  static const Color _error = error;

  // Tracker State Colors
  static TrackerStateColors active = TrackerStateColors(
    primary: _active,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [secondary, Color(0xFF005228)],
    ),
    text: Colors.white,
    border: secondary.withOpacity(0.2),
    shadow: secondary.withOpacity(0.1),
    background: secondary.withOpacity(0.05),
  );

  static TrackerStateColors paused = TrackerStateColors(
    primary: _paused,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [tertiary, Color(0xFF663E00)],
    ),
    text: Colors.white,
    border: tertiary.withOpacity(0.2),
    shadow: tertiary.withOpacity(0.1),
    background: tertiary.withOpacity(0.05),
  );

  static TrackerStateColors errorState = TrackerStateColors(
    primary: _error,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [error, Color(0xFF93000A)],
    ),
    text: Colors.white,
    border: error.withOpacity(0.2),
    shadow: error.withOpacity(0.1),
    background: error.withOpacity(0.05),
  );

  // Glassmorphism Card Style
  static BoxDecoration glassDecoration({
    double borderRadius = 24,
    bool elevated = true,
    Color? color,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(0.8),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: const Color(0xFF25181E).withOpacity(0.04),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static ThemeData compactTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: tertiary,
        error: error,
        surface: surface,
        background: background,
      ),

      // Typography - Space Grotesk for Headlines, Inter for Body
      textTheme:
          GoogleFonts.interTextTheme(Theme.of(context).textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
            fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        displayMedium: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        displaySmall:
            GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold),
        headlineMedium:
            GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold),
        titleLarge:
            GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
        bodyMedium:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(fontSize: 11, color: primary.withOpacity(0.7)),
        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),

      // Buttons - Rounded Full (Capsule)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          shape: const StadiumBorder(),
          elevation: 2,
        ),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: primary, size: 20),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
      ),
    );
  }
}

class TrackerStateColors {
  final Color primary;
  final LinearGradient gradient;
  final Color text;
  final Color border;
  final Color shadow;
  final Color background;

  TrackerStateColors({
    required this.primary,
    required this.gradient,
    required this.text,
    required this.border,
    required this.shadow,
    required this.background,
  });
}

class StatsCardTheme {
  final Color color;
  final IconData icon;
  final LinearGradient gradient;

  StatsCardTheme({
    required this.color,
    required this.icon,
    required this.gradient,
  });
}
