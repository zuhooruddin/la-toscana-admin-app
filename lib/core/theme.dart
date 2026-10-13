import 'package:flutter/material.dart';

/// Brand colours from project-docs/design-tokens/tokens.v1.json (white on tomato meets WCAG AA).
class Brand {
  static const tomato = Color(0xFFD8372F);
  static const tomatoDark = Color(0xFFB02A23);
  static const basil = Color(0xFF2F8F4E);
  static const cream = Color(0xFFFAF6EF);
  static const charcoal = Color(0xFF1E1B18);
  static const muted = Color(0xFF5E564F);
  static const border = Color(0xFFECE2D3);
  static const green = Color(0xFF133A2A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.tomato, primary: Brand.tomato, secondary: Brand.basil, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.cream,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Brand.charcoal, elevation: 0, scrolledUnderElevation: 1, centerTitle: false),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Brand.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.tomato,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.tomatoDark,
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: Brand.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Brand.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Brand.border)),
    ),
    chipTheme: const ChipThemeData(side: BorderSide(color: Brand.border)),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Brand.tomato.withValues(alpha: 0.12)),
  );
}
