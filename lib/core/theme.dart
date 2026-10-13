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
  // Status accents (tinted chips and the dashboard).
  static const blue = Color(0xFF2F6FD6);
  static const orange = Color(0xFFE8890C);
  static const amber = Color(0xFFF2B01E);
  static const softShadow = [BoxShadow(color: Color(0x0F2A1A0A), blurRadius: 14, offset: Offset(0, 4))];
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Brand.border.withValues(alpha: 0.6))),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Brand.tomato,
      unselectedLabelColor: Brand.muted,
      indicatorColor: Brand.tomato,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Brand.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.tomato : Brand.border),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.tomato, width: 1.5)),
    ),
    chipTheme: const ChipThemeData(side: BorderSide(color: Brand.border)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Brand.tomato.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? Brand.tomato : Brand.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, color: s.contains(WidgetState.selected) ? Brand.tomato : Brand.muted)),
    ),
  );
}
