import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system when nothing is stored', () async {
    final controller = ThemeController();

    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('load reads a stored dark preference', () async {
    SharedPreferences.setMockInitialValues({
      ThemeController.storageKey: 'dark',
    });
    final controller = ThemeController();

    await controller.load();

    expect(controller.mode, ThemeMode.dark);
  });

  test('unknown stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      ThemeController.storageKey: 'sepia',
    });
    final controller = ThemeController();

    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('setMode persists the selected theme', () async {
    final controller = ThemeController();

    await controller.setMode(ThemeMode.light);

    expect(controller.mode, ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.storageKey), 'light');
  });
}
