import 'package:flutter/material.dart';

const ink = Color(0xFF203A35);
const forest = Color(0xFF287563);
const sage = Color(0xFFEAF2E9);
const canvas = Color(0xFFF7F8F5);
const muted = Color(0xFF7A8580);
const line = Color(0xFFE7EBE5);
const amber = Color(0xFFB87624);
const danger = Color(0xFFB95349);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: forest,
    primary: forest,
    surface: Colors.white,
    onSurface: ink,
    error: danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoArabic'],
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
      ),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, color: muted, height: 1.5),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9FAF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: forest, width: 1.5),
      ),
      hintStyle: const TextStyle(fontSize: 13, color: muted),
      labelStyle: const TextStyle(fontSize: 13, color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: ink,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: sage,
    ),
  );
}
