import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/widgets/workshop_records/customer_invite_card.dart';

import '../../support_workshop_records.dart';

Future<List<Uri>> pumpCard(WidgetTester tester, FakeWorkshopApi api) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Provider<ApiService>.value(
        value: api,
        child: Scaffold(
          body: SingleChildScrollView(
            child: CustomerInviteCard(
              maintenanceId: 1,
              openUrl: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  return opened;
}

void main() {
  testWidgets('WhatsApp invite opens the returned URL', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    final opened = await pumpCard(tester, api);

    await tester.enterText(
        find.byKey(const Key('invite_phone_field')), '(11) 99999-8888');
    await tester.tap(find.byKey(const Key('invite_whatsapp_button')));
    await tester.pumpAndSettle();

    expect(api.whatsappPhone, '11999998888');
    expect(opened.single.toString(), 'https://wa.me/5511999998888?text=oi');
    expect(find.textContaining('Enviado em'), findsOneWidget);
  });

  testWidgets('email invite shows sent timestamp', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpCard(tester, api);

    await tester.enterText(
        find.byKey(const Key('invite_email_field')), 'a@b.com');
    await tester.tap(find.byKey(const Key('invite_email_button')));
    await tester.pumpAndSettle();

    expect(api.emailSent, 'a@b.com');
    expect(find.textContaining('Enviado em'), findsOneWidget);
  });

  for (final entry in {
    409: 'Já enviamos um e-mail para esta OS.',
    429: 'Limite diário de e-mails atingido.',
    422: 'Não foi possível enviar para este e-mail.',
  }.entries) {
    testWidgets('email ${entry.key} shows server message', (tester) async {
      final api = FakeWorkshopApi()
        ..emailError = dioFailure(entry.key, {'message': entry.value});
      await pumpCard(tester, api);

      await tester.enterText(
          find.byKey(const Key('invite_email_field')), 'a@b.com');
      await tester.tap(find.byKey(const Key('invite_email_button')));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('invalid email is rejected locally', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpCard(tester, api);

    await tester.enterText(find.byKey(const Key('invite_email_field')), 'x');
    await tester.tap(find.byKey(const Key('invite_email_button')));
    await tester.pump();

    expect(api.emailSent, isNull);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
