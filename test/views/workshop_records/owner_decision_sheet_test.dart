import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/workshop_record.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/widgets/workshop_records/owner_decision_sheet.dart';

import '../../support_workshop_records.dart';

Future<void> pumpSheet(
  WidgetTester tester,
  FakeWorkshopApi api,
  Map<String, dynamic> json,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Provider<ApiService>.value(
        value: api,
        child: Scaffold(
          body: OwnerDecisionSheet(record: WorkshopRecord.fromJson(json)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('attach switch is disabled with unverified ownership',
      (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpSheet(tester, api, recordJson(canAccept: false));

    expect(find.textContaining('CRLV-e'), findsOneWidget);

    await tester.tap(find.byKey(const Key('decision_link_switch')));
    await tester.pump();

    final attach = tester.widget<SwitchListTile>(
      find.byKey(const Key('decision_attach_switch')),
    );
    expect(attach.onChanged, isNull);
  });

  testWidgets('sends link, attach and hide choices', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpSheet(tester, api, recordJson());

    expect(find.text('Anexar notas fiscais e fotos (3)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('decision_link_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_attach_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_hide_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_submit')));
    await tester.pumpAndSettle();

    expect(api.sentDecision, {
      'link': true,
      'attach_files': true,
      'hide_from_public': true,
    });
  });

  testWidgets('shows the server 422 message', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()
      ..decisionError = dioFailure(422, {
        'message': 'Verifique a posse com o CRLV-e para anexar arquivos.',
      });
    await pumpSheet(tester, api, recordJson());

    await tester.tap(find.byKey(const Key('decision_link_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Verifique a posse com o CRLV-e para anexar arquivos.'),
      findsOneWidget,
    );
  });

  testWidgets('accepted attachments can be revoked', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi();
    await pumpSheet(
      tester,
      api,
      recordJson(
        ownerStatus: 'linked',
        attachmentsStatus: 'accepted',
        canAccept: false,
      ),
    );

    await tester.tap(find.byKey(const Key('decision_attach_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_submit')));
    await tester.pumpAndSettle();

    expect(api.sentDecision?['link'], isTrue);
    expect(api.sentDecision?['attach_files'], isFalse);
  });
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
