import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vehicle_maintenance/main.dart' as app;
import 'package:vehicle_maintenance/views/profile/settings_page.dart';

Future<void> captureScreenshot(WidgetTester tester, String name) async {
  await pumpFor(tester, const Duration(seconds: 2));
  await tester.runAsync(() async {
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // Pushed Cupertino routes keep the page underneath at full size, shifted
    // left. That boundary is larger or earlier in the tree, so picking by
    // area captures the previous screen with a black gap. The visible page
    // sits at the origin and is deeper in the tree.
    RenderRepaintBoundary? boundary;
    var bestScore = double.negativeInfinity;
    for (final element in tester.allElements) {
      final renderObject = element.renderObject;
      if (renderObject is! RenderRepaintBoundary ||
          !renderObject.hasSize ||
          renderObject.debugNeedsPaint) {
        continue;
      }
      if (renderObject.size.width < logicalWidth * 0.9 ||
          renderObject.size.height < logicalHeight * 0.75) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final distance = topLeft.dx.abs() + topLeft.dy.abs();
      if (distance > logicalWidth * 0.25) {
        continue;
      }
      final score = element.depth * 10000 - distance;
      if (score > bestScore) {
        bestScore = score;
        boundary = renderObject;
      }
    }

    if (boundary == null) {
      // ignore: avoid_print
      print('SCREENSHOT_MISS $name');
      return;
    }

    final image = await boundary!.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/theme-shots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE_PNG ${file.path}');
  });
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<bool> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) {
      return true;
    }
  }

  return false;
}

Future<void> loginIfNeeded(WidgetTester tester) async {
  final ready = await waitUntil(
    tester,
    () =>
        find
            .byKey(const Key('login_hub_portal_usuario'))
            .evaluate()
            .isNotEmpty ||
        find.text('Perfil').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 40),
  );
  expect(ready, isTrue, reason: 'App did not reach login or home');

  if (find.text('Perfil').evaluate().isNotEmpty) {
    return;
  }

  await tester.tap(find.byKey(const Key('login_hub_portal_usuario')));
  await pumpFor(tester, const Duration(seconds: 1));

  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), 'fgoncalves2008@gmail.com');
  await tester.enterText(fields.at(1), 'password123');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('login_submit_button')));

  final loggedIn = await waitUntil(
    tester,
    () => find.text('Perfil').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 40),
  );
  expect(loggedIn, isTrue, reason: 'Login did not reach the home screen');
}

Future<void> openSettings(WidgetTester tester) async {
  if (find.byKey(const Key('theme_mode_light')).evaluate().isNotEmpty) {
    return;
  }

  if (find.text('Configurações').evaluate().isEmpty) {
    await tester.tap(find.text('Perfil'));
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  await tester.tap(find.text('Configurações'));
  final opened = await waitUntil(
    tester,
    () => find.byKey(const Key('theme_mode_light')).evaluate().isNotEmpty,
  );
  expect(opened, isTrue, reason: 'Settings theme picker did not open');
}

Future<void> selectTheme(WidgetTester tester, String mode) async {
  await openSettings(tester);
  final key = Key('theme_mode_$mode');
  await tester.ensureVisible(find.byKey(key));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(key));
  await pumpFor(tester, const Duration(seconds: 1));

  if (find.byKey(key).evaluate().isEmpty) {
    await openSettings(tester);
  }
}

Future<void> captureSignedInSurfaces(
  WidgetTester tester,
  String prefix,
) async {
  final settingsScroll = find.descendant(
    of: find.byType(SettingsPage),
    matching: find.byType(Scrollable),
  );
  if (settingsScroll.evaluate().isNotEmpty) {
    await tester.drag(settingsScroll.first, const Offset(0, 800));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }
  await captureScreenshot(tester, '$prefix-settings');

  if (find.text('Veículos').evaluate().isEmpty) {
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  if (find.text('Meus Dados').evaluate().isNotEmpty) {
    await captureScreenshot(tester, '$prefix-profile');
  }

  expect(find.text('Veículos'), findsOneWidget);
  await tester.tap(find.text('Veículos'));
  await pumpFor(tester, const Duration(seconds: 3));
  await captureScreenshot(tester, '$prefix-vehicles');

  final vehicleTiles = find.byType(ListTile);
  if (vehicleTiles.evaluate().isEmpty) {
    return;
  }

  await tester.tap(vehicleTiles.first);
  final openedDetail = await waitUntil(
    tester,
    () => find.text('Linha do tempo').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
  );
  if (!openedDetail) {
    return;
  }

  await captureScreenshot(tester, '$prefix-vehicle-detail');
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -500));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await captureScreenshot(tester, '$prefix-vehicle-timeline');
  }

  await tester.pageBack();
  await pumpFor(tester, const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures light and dark theme screenshots', (tester) async {
    final prefix = Platform.isIOS ? 'ios' : 'android';

    app.main();
    await loginIfNeeded(tester);

    await selectTheme(tester, 'light');
    await captureSignedInSurfaces(tester, '$prefix-light');

    await selectTheme(tester, 'dark');
    await captureSignedInSurfaces(tester, '$prefix-dark');
  });
}
