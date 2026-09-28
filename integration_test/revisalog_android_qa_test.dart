import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vehicle_maintenance/main.dart' as app;

Future<void> captureScreenshot(WidgetTester tester, String name) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures Android QA screenshots for posts', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 20));

    if (find.text('Allow').evaluate().isNotEmpty) {
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
    }

    if (find.byKey(const Key('login_hub_portal_usuario')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('login_hub_portal_usuario')));
      await tester.pumpAndSettle();
    }

    final fields = find.byType(TextFormField);
    if (fields.evaluate().length >= 2) {
      await tester.tap(fields.at(0));
      await tester.enterText(fields.at(0), 'fgoncalves2008@gmail.com');
      await tester.tap(fields.at(1));
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(seconds: 2));
        if (find.textContaining('Mercedes').evaluate().isNotEmpty ||
            find.text('Meus veículos').evaluate().isNotEmpty) {
          break;
        }
      }
    }

    if (find.text('Veículos').evaluate().isNotEmpty) {
      await tester.tap(find.text('Veículos'));
      await tester.pumpAndSettle(const Duration(seconds: 15));
    }

    await captureScreenshot(tester, 'android-debug-after-login');

    expect(find.textContaining('Mercedes'), findsWidgets);
    await captureScreenshot(tester, 'android-vehicles');

    await tester.tap(find.textContaining('Mercedes'));
    await tester.pumpAndSettle(const Duration(seconds: 25));

    expect(find.text('Linha do tempo'), findsOneWidget);
    expect(find.text('Manutenções'), findsOneWidget);

    await captureScreenshot(tester, 'android-vehicle-detail');

    await tester.tap(find.text('Manutenções'));
    await tester.pumpAndSettle(const Duration(seconds: 20));
    await captureScreenshot(tester, 'android-maintenances');

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await captureScreenshot(tester, 'android-vehicles-return');
  });
}
