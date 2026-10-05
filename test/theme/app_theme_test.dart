import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/theme/app_theme.dart';

void main() {
  test('light theme uses navy text on a light surface', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.surface, AppColors.lightSurface);
    expect(theme.colorScheme.onSurface, AppColors.navy);
    expect(theme.appBarTheme.backgroundColor, Colors.white);
    expect(theme.appBarTheme.foregroundColor, AppColors.navy);
    expect(
      ThemeData.estimateBrightnessForColor(theme.colorScheme.onSurface),
      Brightness.dark,
    );
  });

  test('dark theme uses light text on navy, never black on navy', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.navy);
    expect(theme.colorScheme.surface, AppColors.navy);
    expect(theme.colorScheme.onSurface, AppColors.darkInk);
    expect(theme.colorScheme.onSurface, isNot(Colors.black));
    expect(theme.appBarTheme.foregroundColor, Colors.white);
    expect(theme.cardTheme.color, AppColors.navyRaised);
    expect(
      ThemeData.estimateBrightnessForColor(theme.colorScheme.onSurface),
      Brightness.light,
    );
    expect(
      ThemeData.estimateBrightnessForColor(theme.colorScheme.onSurfaceVariant),
      Brightness.light,
    );
    expect(
      ThemeData.estimateBrightnessForColor(theme.scaffoldBackgroundColor),
      Brightness.dark,
    );
  });
}
