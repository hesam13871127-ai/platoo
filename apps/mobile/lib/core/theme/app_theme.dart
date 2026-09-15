import 'package:flutter/material.dart';

class AppTheme {
  // Brand palette. The original values are preserved on purpose — the game
  // boards are built on these exact hues and are not part of the redesign.
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

  // Extended accents for the premium identity: gradients, glows, avatars.
  static const fuchsia = Color(0xFFC44DFF);
  static const pink = Color(0xFFF064A0);
  static const sky = Color(0xFF4FB3FF);
  static const violetSoft = Color(0xFFB7A5FF);
  static const darkElevated = Color(0xFF20263F);

  static const primaryGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B5CF6), violet]);
  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [violetDeep, violet, fuchsia]);
  static const goldGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD57E), gold, Color(0xFFF59E0B)]);
  static const mintGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5FE3B8), mint, Color(0xFF189A7C)]);
  static const coralGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF9A86), coral, Color(0xFFE14E63)]);
  static const skyGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8FD6FF), sky, Color(0xFF2E7FE0)]);
  static const darkPageGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF151B36), darkBackground]);
  static const lightPageGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEDE9FF), lightBackground]);

  /// Deterministic gradient pair for initial-letter avatars.
  static LinearGradient avatarGradient(String seed) {
    const pairs = <List<Color>>[
      [violet, fuchsia],
      [coral, gold],
      [mint, sky],
      [pink, violet],
      [sky, mint],
      [gold, coral],
    ];
    final pair = pairs[seed.hashCode.abs() % pairs.length];
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pair[0], pair[1]]);
  }

  /// Soft colored glow used under gradient buttons, art tiles, and heroes.
  static List<BoxShadow> glow(Color color, {double strength = .32}) => [
        BoxShadow(color: color.withOpacity(strength), blurRadius: 22, offset: const Offset(0, 11)),
        BoxShadow(color: color.withOpacity(strength * .4), blurRadius: 46, offset: const Offset(0, 22)),
      ];

  /// Neutral card shadow: airy in light mode, deep in dark mode.
  static List<BoxShadow> softShadow({required bool dark}) => dark
      ? [const BoxShadow(color: Color(0x61000000), blurRadius: 26, offset: Offset(0, 14))]
      : [const BoxShadow(color: Color(0x1A3B2B9F), blurRadius: 24, offset: Offset(0, 12)), const BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))];

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
          primary: violetSoft,
          onPrimary: const Color(0xFF23145D),
          secondary: const Color(0xFFFF9A86),
          onSecondary: const Color(0xFF3B0F08),
          tertiary: const Color(0xFF73E2C3),
          onTertiary: const Color(0xFF063A2E),
          surface: darkSurface,
          background: darkBackground,
          onSurface: const Color(0xFFF4F1FF),
          onSurfaceVariant: const Color(0xFFB5B9CC),
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
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.4),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(dark ? .25 : .08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: scheme.outline.withOpacity(dark ? .35 : .2))),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withOpacity(dark ? .42 : .55), thickness: 1, space: 1),
      textTheme: TextTheme(
        displaySmall: TextStyle(color: scheme.onSurface, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -.8, height: 1.08),
        headlineMedium: TextStyle(color: scheme.onSurface, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.6, height: 1.12),
        headlineSmall: TextStyle(color: scheme.onSurface, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.4, height: 1.15),
        titleLarge: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.2),
        titleMedium: TextStyle(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.1),
        titleSmall: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: scheme.onSurface, fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(color: scheme.onSurface, fontSize: 14, height: 1.4),
        bodySmall: TextStyle(color: muted, fontSize: 13, height: 1.4),
        labelLarge: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w800),
        labelMedium: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .2),
        labelSmall: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1C2136) : const Color(0xFFF1EFF8),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.outline.withOpacity(.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.outline.withOpacity(.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.error, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(52, 54), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), elevation: 2, shadowColor: scheme.primary.withOpacity(.35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -.2))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(52, 54), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), side: BorderSide(color: scheme.outline, width: 1.4), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
      segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(textStyle: const MaterialStatePropertyAll(TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), side: MaterialStatePropertyAll(BorderSide(color: scheme.outline.withOpacity(.5))), shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), backgroundColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? scheme.primary : surface), foregroundColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? scheme.onPrimary : scheme.onSurfaceVariant))),
      switchTheme: SwitchThemeData(thumbColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? scheme.onPrimary : null), trackColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? scheme.primary : null)),
      listTileTheme: ListTileThemeData(iconColor: scheme.primary, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), titleTextStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15), subtitleTextStyle: TextStyle(color: muted, fontSize: 13)),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44), tapTargetSize: MaterialTapTargetSize.padded)),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        disabledColor: scheme.surfaceVariant.withOpacity(.45),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(dark ? .28 : .13),
        labelTextStyle: MaterialStatePropertyAll(TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: coral, textColor: Colors.white),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primary.withOpacity(.14), circularTrackColor: scheme.primary.withOpacity(.14)),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, elevation: 8, shadowColor: Colors.black.withOpacity(.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: dark ? const Color(0xFF2A3048) : const Color(0xFF242238), contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16)),
      tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: dark ? const Color(0xFF30364E) : ink, borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}
