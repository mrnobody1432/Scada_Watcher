import 'package:flutter/material.dart';

class AppTheme {
  // Industrial severity colors - High contrast for both modes
  static const Color criticalColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFED6C02);
  static const Color infoColor = Color(0xFF0288D1);
  static const Color normalColor = Color(0xFF2E7D32);

  // Surface colors - Refined for better contrast
  static const Color backgroundLight = Color(0xFFF0F2F5); // Soft blue-gray
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFDDE1E6); // Defined border
  static const Color shadowLight = Color(0x0D000000); // Very subtle shadow

  static const Color backgroundDark = Color(0xFF0A0A0A); // Deeper black
  static const Color surfaceDark = Color(0xFF161616); // Solid dark gray
  static const Color borderDark = Color(0xFF262626); // Dark border

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: infoColor,
        brightness: Brightness.light,
        surface: surfaceLight,
        onSurface: const Color(0xFF1A1C1E),
        outline: borderLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A1C1E),
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1C1E)),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
      textTheme: _buildTextTheme(const Color(0xFF1A1C1E)),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: infoColor,
        brightness: Brightness.dark,
        surface: surfaceDark,
        onSurface: Colors.white,
        outline: borderDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
      textTheme: _buildTextTheme(Colors.white),
    );
  }

  static TextTheme _buildTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: baseColor),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: baseColor, letterSpacing: -0.5),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: baseColor),
      bodyLarge: TextStyle(fontSize: 16, color: baseColor),
      bodyMedium: TextStyle(fontSize: 14, color: baseColor.withOpacity(0.85)),
      bodySmall: TextStyle(fontSize: 12, color: baseColor.withOpacity(0.65)),
      labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: baseColor),
    );
  }

  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return criticalColor;
      case 'warning': return warningColor;
      case 'info': return infoColor;
      default: return normalColor;
    }
  }

  static IconData getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return Icons.error_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'info': return Icons.info_rounded;
      default: return Icons.check_circle_rounded;
    }
  }
}
