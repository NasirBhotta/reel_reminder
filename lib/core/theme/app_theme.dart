import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 6, sm = 10, md = 16, lg = 24, xl = 32;
}

abstract final class AppRadius {
  static const double sm = 12, md = 18, lg = 26;
}

abstract final class AppTheme {
  static const _brand = Color(0xFF6750D8);

  static ThemeData light() => _build(
    Brightness.light,
    const Color(0xFFF8F7FC),
    const Color(0xFFFFFFFF),
  );

  static ThemeData dark() =>
      _build(Brightness.dark, const Color(0xFF10101A), const Color(0xFF191927));

  static ThemeData _build(
    Brightness brightness,
    Color background,
    Color surface,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      surface: surface,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 2,
        shadowColor: const Color(0x246750D8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: dark ? const Color(0xFF2A2940) : const Color(0xFFECE9F5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF202033) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF32304B) : const Color(0xFFE9E5F5),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 8,
        height: 72,
      ),
    );
  }
}
