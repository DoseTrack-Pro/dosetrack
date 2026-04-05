import 'package:flutter/material.dart';

// ── Palette ────────────────────────────────────────────────────
abstract class AppColors {
  static const teal       = Color(0xFF1D9E75);
  static const tealLight  = Color(0xFFE1F5EE);
  static const tealMid    = Color(0xFF9FE1CB);
  static const tealDark   = Color(0xFF085041);
  static const tealDeep   = Color(0xFF0F6E56);

  static const amber      = Color(0xFFBA7517);
  static const amberLight = Color(0xFFFAEEDA);
  static const amberDark  = Color(0xFF854F0B);

  static const red        = Color(0xFFE24B4A);
  static const redLight   = Color(0xFFFCEBEB);
  static const redDark    = Color(0xFFA32D2D);

  static const purple     = Color(0xFF534AB7);
  static const purpleLight = Color(0xFFEEEDFE);
  static const purpleDark = Color(0xFF3C3489);

  static const blue       = Color(0xFF185FA5);
  static const blueLight  = Color(0xFFE6F1FB);
  static const blueMid    = Color(0xFFB5D4F4);
  static const blueDark   = Color(0xFF0C447C);

  static const background  = Color(0xFFF8F8F6);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0x1A000000);
  static const borderStrong = Color(0x33000000);

  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textTertiary  = Color(0xFF9E9E9E);
  static const textInverse   = Color(0xFFFFFFFF);
}

// ── Dose color helper ──────────────────────────────────────────
Color doseColor(int remaining, int total) {
  if (total == 0) return AppColors.teal;
  final pct = remaining / total;
  if (pct > 0.5) return AppColors.teal;
  if (pct > 0.2) return AppColors.amber;
  return AppColors.red;
}

Color doseBgColor(int remaining, int total) {
  if (total == 0) return AppColors.tealLight;
  final pct = remaining / total;
  if (pct > 0.5) return AppColors.tealLight;
  if (pct > 0.2) return AppColors.amberLight;
  return AppColors.redLight;
}

// ── Theme ──────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.border,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, letterSpacing: -0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.teal,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.textInverse,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.borderStrong, width: 0.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderStrong, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderStrong, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
      space: 0,
    ),
    fontFamily: 'SF Pro Display',
  );
}
