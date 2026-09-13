import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF11152A);
  static const violet = Color(0xFF7957F2);
  static const violetDeep = Color(0xFF2F236E);
  static const coral = Color(0xFFFF735C);
  static const mint = Color(0xFF2CC7A0);
  static const gold = Color(0xFFFFC857);
  static const lightBackground = Color(0xFFF7F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF0D1020);
  static const darkSurface = Color(0xFF171B2D);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    scheme: ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.light).copyWith(
      primary: violet,
      onPrimary: Colors.white,
      secondary: coral,
      onSecondary: Colors.white,
      tertiary: mint,
      onTertiary: Colors.white,
      surface: lightSurface,
      background: lightBackground,
      onSurface: ink,
      surfaceVariant: const Color(0xFFF0EEF8),
      outline: const Color(0xFFD9D5E6),
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    scheme: ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFFB7A5FF),
      onPrimary: const Color(0xFF23145D),
      secondary: const Color(0xFFFF9A86),
      onSecondary: const Color(0xFF3B0F08),
      tertiary: const Color(0xFF73E2C3),
      onTertiary: const Color(0xFF063A2E),
      surface: darkSurface,
      background: darkBackground,
      onSurface: const Color(0xFFF4F1FF),
      surfaceVariant: const Color(0xFF252A40),
      outline: const Color(0xFF454B66),
    ),
  );

  static ThemeData _build({required Brightness brightness, required ColorScheme scheme}) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? darkSurface : lightSurface;
    final muted = dark ? const Color(0xFFB5B9CC) : const Color(0xFF68677A);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      fontFamily: 'sans',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(dark ? .25 : .08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: scheme.outline.withOpacity(dark ? .35 : .22))),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withOpacity(dark ? .42 : .55), thickness: 1, space: 1),
      textTheme: TextTheme(
        displaySmall: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -.8),
        headlineMedium: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -.6),
        headlineSmall: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: -.35),
        titleLarge: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: scheme.onSurface, height: 1.35),
        bodyMedium: TextStyle(color: scheme.onSurface, height: 1.3),
        bodySmall: TextStyle(color: muted, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1C2136) : const Color(0xFFFFFFFF),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.outline.withOpacity(.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.outline.withOpacity(.35))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.primary, width: 1.7)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.error, width: 1.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: scheme.outline), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44), tapTargetSize: MaterialTapTargetSize.padded)),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        disabledColor: scheme.surfaceVariant.withOpacity(.45),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(dark ? .28 : .13),
        labelTextStyle: MaterialStatePropertyAll(TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primary.withOpacity(.14), circularTrackColor: scheme.primary.withOpacity(.14)),
      dialogTheme: DialogTheme(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: dark ? const Color(0xFF2A3048) : const Color(0xFF242238), contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16)),
      tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: dark ? const Color(0xFF30364E) : ink, borderRadius: BorderRadius.circular(9)), textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}
