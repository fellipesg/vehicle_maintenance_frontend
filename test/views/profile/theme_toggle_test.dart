import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/theme/app_theme.dart';
import 'package:vehicle_maintenance/theme/theme_controller.dart';
import 'package:vehicle_maintenance/views/profile/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings theme picker switches the app between light and dark',
      (tester) async {
    final controller = ThemeController(initialMode: ThemeMode.light);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: Consumer<ThemeController>(
          builder: (context, theme, _) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: theme.mode,
              home: const SettingsPage(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(_brightness(tester), Brightness.light);
    expect(_headerColor(tester), AppColors.inkMuted);

    await tester.tap(find.byKey(const Key('theme_mode_dark')));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.dark);
    expect(_brightness(tester), Brightness.dark);
    expect(_headerColor(tester), AppColors.darkInkMuted);
    expect(
      Theme.of(tester.element(find.byType(SettingsPage)))
          .scaffoldBackgroundColor,
      AppColors.navy,
    );

    await tester.tap(find.byKey(const Key('theme_mode_light')));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.light);
    expect(_brightness(tester), Brightness.light);
  });
}

Brightness _brightness(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(SettingsPage))).brightness;
}

Color? _headerColor(WidgetTester tester) {
  return tester.widget<Text>(find.text('Aparência')).style?.color;
}
