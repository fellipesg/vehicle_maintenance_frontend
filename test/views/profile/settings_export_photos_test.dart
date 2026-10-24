import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/theme/theme_controller.dart';
import 'package:vehicle_maintenance/views/profile/settings_page.dart';

import '../../support_photos.dart';

Future<FakePhotosApi> _pump(
  WidgetTester tester,
  Map<String, dynamic> user, {
  Map<String, dynamic>? me,
}) async {
  final api = FakePhotosApi(me: me);
  final auth = FakeAuth(api, user);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeController>.value(
      value: ThemeController(initialMode: ThemeMode.light),
      child: providers(api, auth, child: const SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();

  return api;
}

Finder get _switchTile => find.byKey(const Key('settings_export_photos'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mostra o valor atual e grava ao mudar', (tester) async {
    final api = await _pump(
      tester,
      {
        'user_type': 'user',
        'features': photosFeatureOn,
        'export_include_photos': false
      },
    );

    expect(find.text('Fotos no PDF do histórico'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_switchTile).value, isFalse);

    await tester.ensureVisible(_switchTile);
    await tester.tap(_switchTile);
    await tester.pumpAndSettle();

    expect(api.exportPreferenceWrites, [true]);
    expect(tester.widget<SwitchListTile>(_switchTile).value, isTrue);
  });

  testWidgets('nunca respondido aparece desligado', (tester) async {
    await _pump(tester, {
      'user_type': 'user',
      'features': photosFeatureOn,
      'export_include_photos': null
    });

    expect(tester.widget<SwitchListTile>(_switchTile).value, isFalse);
  });

  testWidgets('sem o campo em cache lê de GET /me', (tester) async {
    final api = await _pump(
      tester,
      {'user_type': 'user', 'features': photosFeatureOn},
      me: {'export_include_photos': true},
    );

    expect(api.meCalls, 1);
    expect(tester.widget<SwitchListTile>(_switchTile).value, isTrue);
  });

  testWidgets('falha ao salvar volta o interruptor e avisa', (tester) async {
    final api = await _pump(
      tester,
      {
        'user_type': 'user',
        'features': photosFeatureOn,
        'export_include_photos': false
      },
    );
    api.exportPreferenceError = dioError(500, {});

    await tester.ensureVisible(_switchTile);
    await tester.tap(_switchTile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(_switchTile).value, isFalse);
    expect(find.textContaining('O servidor falhou'), findsOneWidget);
  });

  testWidgets('oficina não vê o interruptor', (tester) async {
    await _pump(
      tester,
      {
        'user_type': 'workshop',
        'features': photosFeatureOn,
        'export_include_photos': null
      },
    );

    expect(_switchTile, findsNothing);
  });

  testWidgets('backend sem o campo: seção oculta', (tester) async {
    await _pump(tester, {'user_type': 'user', 'features': photosFeatureOn},
        me: {'name': 'Ana'});

    expect(_switchTile, findsNothing);
  });

  testWidgets('recurso de fotos desligado: sem interruptor', (tester) async {
    await _pump(
      tester,
      {
        'user_type': 'user',
        'features': {'maintenance_photos': false},
        'export_include_photos': false,
      },
    );

    expect(_switchTile, findsNothing);
    expect(find.text('Fotos no PDF do histórico'), findsNothing);
  });

  testWidgets('sem a chave features: sem interruptor', (tester) async {
    await _pump(tester, {'user_type': 'user', 'export_include_photos': false});

    expect(_switchTile, findsNothing);
  });
}
