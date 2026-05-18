import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.hcmusBlue,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.hcmusBlue,
        brightness: Brightness.light,
        primary: AppColors.hcmusBlue,
        secondary: AppColors.hcmusTeal,
        error: AppColors.error,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.greyDark,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: AppColors.greyDark),
        displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: AppColors.greyDark),
        bodyLarge: TextStyle(fontFamily: 'Poppins', color: AppColors.greyDark),
        bodyMedium: TextStyle(fontFamily: 'Poppins', color: AppColors.greyDark),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.greyDark,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hcmusBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.hcmusBlue,
          side: const BorderSide(color: AppColors.hcmusBlue, width: 2),
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E1F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E1F3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.hcmusBlue, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.hcmusBlue,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.hcmusBlue,
        brightness: Brightness.dark,
        primary: AppColors.hcmusBlue,
        secondary: AppColors.hcmusTeal,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
        onSurface: Colors.white,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
        bodyMedium: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hcmusBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.hcmusBlue,
          side: const BorderSide(color: AppColors.hcmusBlue, width: 2),
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF23262B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3A3F47)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3A3F47)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.hcmusBlue, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
