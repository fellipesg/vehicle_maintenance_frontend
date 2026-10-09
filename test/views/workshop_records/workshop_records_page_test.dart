import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/workshop_records_inbox.dart';
import 'package:vehicle_maintenance/views/workshop_records/workshop_records_page.dart';
import 'package:vehicle_maintenance/widgets/workshop_records/pending_workshop_records_card.dart';

import '../../support_workshop_records.dart';

Widget app(FakeWorkshopApi api, WorkshopRecordsInbox inbox, Widget home) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider<WorkshopRecordsInbox>.value(value: inbox),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('lists pending records and removes one after deciding',
      (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()..records = [recordJson()];
    final inbox = WorkshopRecordsInbox(api);

    await tester.pumpWidget(app(api, inbox, const WorkshopRecordsPage()));
    await tester.pumpAndSettle();

    expect(api.requestedStatus, 'pending');
    expect(find.text('Oficina Central'), findsOneWidget);
    expect(inbox.pendingCount, 1);

    await tester.tap(find.text('Oficina Central'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decision_link_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decision_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Oficina Central'), findsNothing);
    expect(find.byKey(const Key('records_empty')), findsOneWidget);
  });

  testWidgets('"Todos" filter requests status=all', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()
      ..records = [recordJson(ownerStatus: 'linked', hidden: true)];

    await tester.pumpWidget(
      app(api, WorkshopRecordsInbox(api), const WorkshopRecordsPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('records_filter_all')));
    await tester.pumpAndSettle();

    expect(api.requestedStatus, 'all');
    expect(find.text('Oculto do público'), findsOneWidget);
  });

  testWidgets('home card shows the count and hides at zero', (tester) async {
    tall(tester);
    final api = FakeWorkshopApi()..meCount = 3;
    final inbox = WorkshopRecordsInbox(api);

    await tester.pumpWidget(
      app(api, inbox, const Scaffold(body: PendingWorkshopRecordsCard())),
    );
    expect(
        find.byKey(const Key('pending_workshop_records_card')), findsNothing);

    await inbox.refresh();
    await tester.pump();
    expect(find.text('Registros de oficinas para revisar (3)'), findsOneWidget);

    inbox.setCount(0);
    await tester.pump();
    expect(
        find.byKey(const Key('pending_workshop_records_card')), findsNothing);
  });
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
