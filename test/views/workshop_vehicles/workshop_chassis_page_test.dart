import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/workshop_vehicles/workshop_chassis_page.dart';

import '../../support_workshop_records.dart';

const _vin = '9BD123456789ABCDE';

Future<void> pumpPage(WidgetTester tester, FakeWorkshopApi api) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthService(api);
  await auth.saveUser({'user_type': 'workshop', 'workshop_id': 3});

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        Provider<AuthService>.value(value: auth),
      ],
      child: const MaterialApp(home: WorkshopChassisPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String chassis) async {
  await tester.enterText(
      find.byKey(const Key('workshop_chassis_field')), chassis);
  await tester.tap(find.byKey(const Key('workshop_chassis_search')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rejects a chassis that is not 17 valid characters',
      (tester) async {
    tall(tester);
    await pumpPage(tester, FakeWorkshopApi());
    await search(tester, 'ABC');

    expect(find.text('O chassi deve ter 17 caracteres'), findsOneWidget);
  });

  testWidgets('found with owner shows the plate-flow message', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()
      ..lookupBody = {
        'success': true,
        'data': {
          'found': true,
          'vehicle': {'id': 4, 'has_owner': true},
        },
      };
    await pumpPage(tester, api);
    await search(tester, _vin);

    expect(find.textContaining('já está no RevisaLog'), findsOneWidget);
    expect(find.byKey(const Key('workshop_chassis_use')), findsNothing);
    expect(find.byKey(const Key('workshop_create_vehicle')), findsNothing);
  });

  testWidgets('found ownerless offers to register the OS', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()
      ..lookupBody = {
        'success': true,
        'data': {
          'found': true,
          'vehicle': {
            'id': 5,
            'brand': 'Fiat',
            'model': 'Uno',
            'year': 2012,
            'has_owner': false,
          },
        },
      };
    await pumpPage(tester, api);
    await search(tester, _vin);

    expect(
        find.byKey(const Key('workshop_chassis_found_card')), findsOneWidget);
    expect(find.byKey(const Key('workshop_chassis_use')), findsOneWidget);
  });

  testWidgets('not found shows the create form and posts brand/model/year',
      (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpPage(tester, api);
    await search(tester, _vin);

    expect(find.byKey(const Key('workshop_chassis_not_found')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('workshop_brand_field')), 'Fiat');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('workshop_model_field')), 'Uno');
    await tester.enterText(
        find.byKey(const Key('workshop_year_field')), '2012');
    await tester.tap(find.byKey(const Key('workshop_create_vehicle')));
    await tester.pumpAndSettle();

    expect(api.createdPayload, {
      'chassis': _vin,
      'brand': 'Fiat',
      'model': 'Uno',
      'year': 2012,
    });
    // Segue para a OS do carro recém-criado, com o aviso de anexos pendentes.
    expect(
        find.byKey(const Key('ownerless_attachments_notice')), findsOneWidget);
    expect(find.text(kNoPersonalDataHelper), findsOneWidget);
  });

  testWidgets('after saving the OS it opens that OS to notify the customer',
      (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpPage(tester, api);
    await search(tester, _vin);

    await tester.enterText(
        find.byKey(const Key('workshop_brand_field')), 'Fiat');
    await tester.enterText(
        find.byKey(const Key('workshop_model_field')), 'Uno');
    await tester.enterText(
        find.byKey(const Key('workshop_year_field')), '2012');
    await tester.tap(find.byKey(const Key('workshop_create_vehicle')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quilometragem *'), '41000');
    await tester.tap(find.text('Categoria de Serviço').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mecânica').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(api.requestedMaintenanceId, '501');
  });
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
