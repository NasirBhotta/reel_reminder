import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 6, sm = 10, md = 16, lg = 24, xl = 32;
}

abstract final class AppRadius {
  static const double sm = 12, md = 18, lg = 26, pill = 100;
}

abstract final class AppTheme {
  static const brand = Color(0xFF15805F);
  static const brandDark = Color(0xFF185E49);
  static const mint = Color(0xFF7CE4BC);
  static const paleMint = Color(0xFFDDF6EB);
  static const ink = Color(0xFF10241E);
  static const inkLight = Color(0xFF527065);

  // Reminder status pill badge colors (Image 2)
  static const reminderBgLight = Color(0xFFEEF4FF);
  static const reminderTextLight = Color(0xFF2563EB);
  static const reminderBgDark = Color(0xFF132247);
  static const reminderTextDark = Color(0xFF93C5FD);

  static const repeatBgLight = Color(0xFFE0F2FE);
  static const repeatTextLight = Color(0xFF0284C7);
  static const repeatBgDark = Color(0xFF0C2B42);
  static const repeatTextDark = Color(0xFF7DD3FC);

  static const snoozeBgLight = Color(0xFFFEF3C7);
  static const snoozeTextLight = Color(0xFFD97706);
  static const snoozeBgDark = Color(0xFF381F08);
  static const snoozeTextDark = Color(0xFFFDE68A);

  static const neutralBgLight = Color(0xFFF3F4F6);
  static const neutralTextLight = Color(0xFF6B7280);
  static const neutralBgDark = Color(0xFF1E2824);
  static const neutralTextDark = Color(0xFF9CA3AF);

  static ThemeData light() => _build(
    Brightness.light,
    const Color(0xFFF7FBF8),
    const Color(0xFFFFFFFF),
  );

  static ThemeData dark() =>
      _build(Brightness.dark, const Color(0xFF07120F), const Color(0xFF101D19));

  static ThemeData _build(
    Brightness brightness,
    Color background,
    Color surface,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      surface: surface,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
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
        elevation: dark ? 0 : 1.5,
        shadowColor: const Color(0x1F15805F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: dark ? const Color(0xFF263A33) : const Color(0xFFE1EEE8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF14241F) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF30483F) : const Color(0xFFD9E9E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF30483F) : const Color(0xFFD9E9E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: dark ? mint : brand, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(
            color: dark ? const Color(0xFF30483F) : const Color(0xFFD0DFD7),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF14241F) : Colors.white,
        selectedColor: dark ? const Color(0xFF185E49) : brand,
        disabledColor: dark ? const Color(0xFF101D19) : const Color(0xFFF0F4F2),
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFE5F7EF) : ink,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(
          color: dark ? const Color(0xFF30483F) : const Color(0xFFD9E9E1),
        ),
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dark ? mint : brand,
        foregroundColor: dark ? ink : Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      dividerColor: dark ? const Color(0xFF263A33) : const Color(0xFFE1EEE8),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 8,
        height: 72,
      ),
    );
  }
}
