import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';
import 'package:vehicle_maintenance/widgets/photos/timeline_photo_strip.dart';
import 'package:vehicle_maintenance/widgets/vehicle_maintenance_timeline.dart';

import '../../support_photos.dart';

Map<String, dynamic> _timeline(Map<String, dynamic> maintenanceEvent) => {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 1,
        'total_spent': 0,
      },
      'vehicle': {'brand': 'VW', 'model': 'Gol'},
      'events': [
        {
          'type': 'maintenance',
          'id': 5,
          'label': 'Revisão',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': false,
          ...maintenanceEvent,
        },
      ],
    };

Widget _app(FakePhotosApi api, Map<String, dynamic> timeline) {
  return Provider<ApiService>.value(
    value: api,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VehicleMaintenanceTimeline(timeline: timeline),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('par antes -> depois com seta e sem "+N"', (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(
      _app(
        api,
        _timeline({
          'photos_count': 2,
          'photos_locked': false,
          'photo_preview': [
            photoJson(id: 1, stage: 'before'),
            photoJson(id: 2, stage: 'after'),
          ],
        }),
      ),
    );

    expect(find.byKey(const Key('timeline_photo_strip')), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_1')), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_2')), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_arrow')), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_more')), findsNothing);
  });

  testWidgets('mostra "+N" quando há mais fotos que a prévia', (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(
      _app(
        api,
        _timeline({
          'photos_count': 6,
          'photo_preview': [
            photoJson(id: 1, stage: 'before'),
            photoJson(id: 2, stage: 'after'),
          ],
        }),
      ),
    );

    expect(find.text('+4'), findsOneWidget);
  });

  testWidgets('prévia que não é par não leva seta', (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(
      _app(
        api,
        _timeline({
          'photos_count': 1,
          'photo_preview': [photoJson(id: 1, stage: 'during')],
        }),
      ),
    );

    expect(find.byKey(const Key('timeline_photo_1')), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_arrow')), findsNothing);
    expect(find.byKey(const Key('timeline_photo_more')), findsNothing);
  });

  testWidgets('bloqueada: cadeado e texto, sem imagens', (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(
      _app(
        api,
        _timeline({
          'photos_count': 3,
          'photos_locked': true,
          'photo_preview': <Map<String, dynamic>>[],
        }),
      ),
    );

    expect(find.byKey(const Key('timeline_photos_locked')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
        find.text('3 fotos aguardando aceite do proprietário'), findsOneWidget);
    expect(find.byKey(const Key('timeline_photo_strip')), findsNothing);
  });

  testWidgets('sem fotos não ocupa espaço', (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(
      _app(api, _timeline({'photos_count': 0, 'photo_preview': []})),
    );

    expect(find.byKey(const Key('timeline_photo_strip')), findsNothing);
    expect(find.byKey(const Key('timeline_photos_locked')), findsNothing);
  });

  testWidgets('evento de backend antigo (sem campos) continua igual',
      (tester) async {
    final api = FakePhotosApi();
    await tester.pumpWidget(_app(api, _timeline({})));

    expect(TimelinePhotoStrip.fromEvent({'id': 5}), isNull);
    expect(find.textContaining('Revisão'), findsOneWidget);
  });

  testWidgets('tocar no card abre o detalhe da manutenção', (tester) async {
    final api = FakePhotosApi(
      maintenance: maintenanceJson(photos: [photoJson(id: 1)]),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          Provider<AuthService>.value(
            value: FakeAuth(api, const {'user_type': 'user'}),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VehicleMaintenanceTimeline(
                timeline: _timeline({
                  'photos_count': 1,
                  'photo_preview': [photoJson(id: 1)],
                }),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceDetailPage), findsOneWidget);
  });
}
