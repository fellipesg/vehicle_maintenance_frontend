import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colors shared by the light and dark themes.
abstract final class AppColors {
  static const Color navy = Color(0xFF0B1C2C);
  static const Color navyRaised = Color(0xFF132536);
  static const Color teal = Color(0xFF2EC4B6);

  /// Darker teal so labels and icons stay readable on light surfaces.
  static const Color tealInk = Color(0xFF0F766E);

  static const Color lightSurface = Color(0xFFF4F7FA);
  static const Color inkMuted = Color(0xFF526275);

  static const Color darkInk = Color(0xFFE7EEF4);
  static const Color darkInkMuted = Color(0xFFB7C5D3);

  static const Color positiveInk = Color(0xFF166534);
  static const Color positiveInkOnDark = Color(0xFF86EFAC);
  static const Color warningInk = Color(0xFF9A3412);
  static const Color warningInkOnDark = Color(0xFFFDBA74);

  static Color positive(Brightness brightness) {
    return brightness == Brightness.dark ? positiveInkOnDark : positiveInk;
  }

  static Color warning(Brightness brightness) {
    return brightness == Brightness.dark ? warningInkOnDark : warningInk;
  }
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.teal : AppColors.tealInk,
      onPrimary: isDark ? AppColors.navy : Colors.white,
      secondary: AppColors.teal,
      onSecondary: AppColors.navy,
      surface: isDark ? AppColors.navy : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkInk : AppColors.navy,
      onSurfaceVariant: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
      surfaceContainerLowest: isDark ? AppColors.navy : Colors.white,
      surfaceContainerLow: isDark ? AppColors.navyRaised : Colors.white,
      surfaceContainer: isDark ? AppColors.navyRaised : Colors.white,
      surfaceContainerHigh:
          isDark ? const Color(0xFF1A3348) : const Color(0xFFE7EEF3),
      surfaceContainerHighest:
          isDark ? const Color(0xFF1E3A52) : const Color(0xFFDCE5EC),
      outline: isDark ? const Color(0xFF3D5670) : const Color(0xFFD5DEE6),
      outlineVariant:
          isDark ? const Color(0xFF2A4258) : const Color(0xFFE2E8EE),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    final cardColor = isDark ? AppColors.navyRaised : Colors.white;
    final barBackground = isDark ? AppColors.navy : Colors.white;
    final barForeground = isDark ? Colors.white : AppColors.navy;

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      appBarTheme: AppBarThemeData(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: barBackground,
        foregroundColor: barForeground,
        iconTheme: IconThemeData(color: barForeground),
        actionsIconTheme: IconThemeData(color: barForeground),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: barForeground,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 0.5,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navy : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: isDark ? 0 : 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.navyRaised : AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}
