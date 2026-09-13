import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF11152A);
  static const violet = Color(0xFF7957F2);
  static const coral = Color(0xFFFF735C);
  static const mint = Color(0xFF2CC7A0);
  static const gold = Color(0xFFFFC857);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F7FB),
      fontFamily: 'sans',
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Colors.transparent),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      inputDecorationTheme: _inputTheme(false),
      navigationBarTheme: NavigationBarThemeData(height: 72, backgroundColor: Colors.white, indicatorColor: violet.withOpacity(.14), labelTextStyle: const MaterialStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1020),
      fontFamily: 'sans',
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Colors.transparent),
      cardTheme: CardTheme(color: const Color(0xFF171B2D), elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      inputDecorationTheme: _inputTheme(true),
      navigationBarTheme: NavigationBarThemeData(height: 72, backgroundColor: const Color(0xFF111528), indicatorColor: violet.withOpacity(.28), labelTextStyle: const MaterialStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
    );
  }

  static InputDecorationTheme _inputTheme(bool dark) => InputDecorationTheme(
    filled: true,
    fillColor: dark ? const Color(0xFF171B2D) : Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: violet, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}
