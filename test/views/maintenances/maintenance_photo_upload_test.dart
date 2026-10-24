import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/maintenance_photo_picker.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';

import '../../support_photos.dart';

Future<(FakePhotosApi, FakePicker)> _open(
  WidgetTester tester, {
  required Map<String, dynamic> maintenance,
  List<String> picked = const ['/tmp/a.jpg'],
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakePhotosApi(maintenance: maintenance);
  final auth =
      FakeAuth(api, const {'user_type': 'user', 'features': photosFeatureOn});
  final picker = FakePicker(picked);

  await tester.pumpWidget(
    providers(
      api,
      auth,
      child: MaintenanceDetailPage(maintenanceId: 5, photoPicker: picker),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_photos_button')));
  await tester.pumpAndSettle();

  return (api, picker);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pede assunto e momento, envia e atualiza a seção',
      (tester) async {
    final (api, picker) = await _open(tester, maintenance: maintenanceJson());

    expect(find.text('Adicionar fotos'), findsWidgets);
    expect(find.byKey(const Key('upload_subject')), findsOneWidget);
    expect(find.byKey(const Key('upload_stage')), findsOneWidget);

    // Depois disso o servidor passa a devolver a foto.
    api.uploadHandler = (path, _) async {
      api.maintenance = maintenanceJson(
        photos: [photoJson(id: 9, stage: 'after')],
      );
    };

    await tester.tap(find.descendant(
      of: find.byKey(const Key('upload_stage')),
      matching: find.text('Depois'),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(picker.requested, [PhotoSource.gallery]);
    expect(api.uploads.single['subject'], 'vehicle');
    expect(api.uploads.single['stage'], 'after');
    expect(api.uploads.single['item'], isNull);
    expect(find.text('Enviada'), findsOneWidget);

    final callsBefore = api.getMaintenanceCalls;
    await tester.tap(find.byKey(const Key('photo_upload_done')));
    await tester.pumpAndSettle();

    expect(api.getMaintenanceCalls, greaterThan(callsBefore));
    expect(find.byKey(const Key('photo_thumb_9')), findsOneWidget);
  });

  testWidgets('câmera abre o seletor de câmera', (tester) async {
    final (_, picker) = await _open(tester, maintenance: maintenanceJson());

    await tester.tap(find.byKey(const Key('upload_camera')));
    await tester.pumpAndSettle();

    expect(picker.requested, [PhotoSource.camera]);
  });

  testWidgets('peça com itens deixa escolher o item', (tester) async {
    final (api, _) = await _open(
      tester,
      maintenance: maintenanceJson(
        items: [itemJson(7, 'Filtro de óleo'), itemJson(8, 'Pastilha')],
      ),
    );

    expect(find.byKey(const Key('upload_item')), findsNothing);

    await tester.tap(find.descendant(
      of: find.byKey(const Key('upload_subject')),
      matching: find.text('Peça'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('upload_item')), findsOneWidget);

    await tester.tap(find.byKey(const Key('upload_item')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pastilha').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(api.uploads.single['subject'], 'part');
    expect(api.uploads.single['item'], 8);
  });

  testWidgets('grupo cheio: avisa antes de abrir o seletor', (tester) async {
    final (api, picker) = await _open(
      tester,
      maintenance: maintenanceJson(
        photos: [for (var i = 1; i <= 4; i++) photoJson(id: i, sort: i)],
      ),
    );

    expect(find.textContaining('Este grupo está cheio'), findsOneWidget);

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(picker.requested, isEmpty);
    expect(api.uploads, isEmpty);
    expect(find.byKey(const Key('upload_notice')), findsOneWidget);
    expect(find.textContaining('máximo'), findsWidgets);
  });

  testWidgets('escolher mais do que cabe envia só o que cabe', (tester) async {
    final (api, _) = await _open(
      tester,
      maintenance: maintenanceJson(
        photos: [for (var i = 1; i <= 3; i++) photoJson(id: i, sort: i)],
      ),
      picked: const ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'],
    );

    expect(find.textContaining('Cabem mais 1 foto(s)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(api.uploads.map((u) => u['path']), ['/tmp/a.jpg']);
    expect(find.textContaining('As demais foram ignoradas'), findsOneWidget);
  });

  testWidgets('o limite conta por momento: outro momento ainda tem vaga',
      (tester) async {
    final (api, _) = await _open(
      tester,
      maintenance: maintenanceJson(
        photos: [for (var i = 1; i <= 4; i++) photoJson(id: i, sort: i)],
      ),
    );

    await tester.tap(find.descendant(
      of: find.byKey(const Key('upload_stage')),
      matching: find.text('Durante'),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(api.uploads.single['stage'], 'during');
  });

  testWidgets('mostra o progresso do arquivo enquanto envia', (tester) async {
    final (api, _) = await _open(tester, maintenance: maintenanceJson());
    final gate = Completer<void>();
    api.uploadHandler = (path, onProgress) async {
      onProgress?.call(50, 100);
      await gate.future;
    };

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pump();
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('upload_progress_0')),
    );
    expect(bar.value, 0.5);
    expect(find.text('a.jpg'), findsOneWidget);
    // Em andamento não dá para fechar.
    expect(find.byKey(const Key('photo_upload_done')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo_upload_done')), findsOneWidget);
  });

  testWidgets('422 mostra a mensagem e a nova tentativa funciona',
      (tester) async {
    final (api, _) = await _open(tester, maintenance: maintenanceJson());
    api.uploadHandler = (path, _) async {
      throw dioError(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'photo': ['Limite de 4 fotos atingido para este grupo.'],
        },
      });
    };

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(find.text('Limite de 4 fotos atingido para este grupo.'),
        findsOneWidget);
    expect(find.byKey(const Key('photo_upload_retry')), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);

    api.uploadHandler = null;
    await tester.tap(find.byKey(const Key('photo_upload_retry')));
    await tester.pumpAndSettle();

    expect(api.uploads, hasLength(2));
    expect(find.text('Enviada'), findsOneWidget);
    expect(find.byKey(const Key('photo_upload_retry')), findsNothing);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('cancelar a escolha não envia nada', (tester) async {
    final (api, _) = await _open(
      tester,
      maintenance: maintenanceJson(),
      picked: const [],
    );

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(api.uploads, isEmpty);
    expect(find.byKey(const Key('upload_subject')), findsOneWidget);
  });

  testWidgets('403: avisa que fotos não estão habilitadas e relê o /me',
      (tester) async {
    final (api, _) = await _open(
      tester,
      maintenance: maintenanceJson(),
      picked: const ['/tmp/a.jpg', '/tmp/b.jpg'],
    );
    api.me = {
      'user_type': 'user',
      'features': {'maintenance_photos': false},
    };
    api.uploadHandler = (path, _) async {
      throw dioError(403, {'message': 'This action is unauthorized.'});
    };

    await tester.tap(find.byKey(const Key('upload_gallery')));
    await tester.pumpAndSettle();

    expect(find.text('Fotos não estão habilitadas para sua conta.'),
        findsOneWidget);
    // A fila para no primeiro 403 e a folha se fecha.
    expect(api.uploads, hasLength(1));
    expect(find.byKey(const Key('upload_subject')), findsNothing);
    expect(api.meCalls, 1);
    // Com o /me novo, a seção some.
    expect(find.byKey(const Key('photos_section')), findsNothing);
  });
}
