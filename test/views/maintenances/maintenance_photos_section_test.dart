import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_photo_viewer_page.dart';

import '../../support_photos.dart';

Future<FakePhotosApi> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> maintenance,
  Map<String, dynamic> user = const {
    'user_type': 'user',
    'features': photosFeatureOn
  },
  FakePicker? picker,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakePhotosApi(maintenance: maintenance);
  final auth = FakeAuth(api, user);

  await tester.pumpWidget(
    providers(
      api,
      auth,
      child: MaintenanceDetailPage(
        maintenanceId: 5,
        photoPicker: picker ?? FakePicker(const []),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return api;
}

Finder _inSection(Finder finder) => find.descendant(
    of: find.byKey(const Key('photos_section')), matching: finder);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os segmentos só dos momentos com foto (sem permissão)',
      (tester) async {
    // Selada por outra oficina: o proprietário só vê, não envia.
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [
          photoJson(id: 1, stage: 'before'),
          photoJson(id: 2, stage: 'after'),
        ],
      ),
    );

    expect(find.byKey(const Key('photos_section')), findsOneWidget);
    expect(find.text('Antes (1)'), findsOneWidget);
    expect(find.text('Depois (1)'), findsOneWidget);
    expect(find.textContaining('Durante'), findsNothing);
    expect(find.byKey(const Key('add_photos_button')), findsNothing);
  });

  testWidgets('agrupa por Veículo e por peça, com a proporção do item',
      (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        items: [itemJson(7, 'Filtro de óleo')],
        photos: [
          photoJson(id: 1, stage: 'before'),
          photoJson(id: 2, stage: 'before', subject: 'part', itemId: 7),
        ],
      ),
    );

    expect(_inSection(find.text('Veículo')), findsOneWidget);
    expect(_inSection(find.text('Filtro de óleo')), findsOneWidget);
    expect(find.byKey(const Key('photo_thumb_1')), findsOneWidget);
    expect(find.byKey(const Key('photo_thumb_2')), findsOneWidget);
  });

  testWidgets('antes e depois do veículo aparecem lado a lado', (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [
          photoJson(id: 1, stage: 'before'),
          photoJson(id: 2, stage: 'after'),
        ],
      ),
    );

    expect(find.byKey(const Key('photos_before_after')), findsOneWidget);
    expect(find.byKey(const Key('photo_compare_1')), findsOneWidget);
    expect(find.byKey(const Key('photo_compare_2')), findsOneWidget);
  });

  testWidgets('só antes: não há comparação', (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [photoJson(id: 1, stage: 'before')],
      ),
    );

    expect(find.byKey(const Key('photos_before_after')), findsNothing);
  });

  testWidgets('trocar o segmento mostra as fotos do outro momento',
      (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [
          photoJson(id: 1, stage: 'before'),
          photoJson(id: 2, stage: 'during'),
        ],
      ),
    );

    expect(find.byKey(const Key('photo_thumb_1')), findsOneWidget);
    expect(find.byKey(const Key('photo_thumb_2')), findsNothing);

    await tester.tap(find.text('Durante (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo_thumb_1')), findsNothing);
    expect(find.byKey(const Key('photo_thumb_2')), findsOneWidget);
  });

  testWidgets('bloqueada: cartão com a contagem e nenhuma imagem',
      (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photosLocked: true,
        photosCount: 3,
      ),
    );

    expect(find.byKey(const Key('photos_locked_card')), findsOneWidget);
    expect(
        find.text('Fotos aguardando aceite do proprietário'), findsOneWidget);
    expect(find.text('3 fotos'), findsOneWidget);
    expect(find.byKey(const Key('photos_stage_selector')), findsNothing);
    expect(find.byKey(const Key('add_photos_button')), findsNothing);
  });

  testWidgets('vazio com permissão oferece "Adicionar fotos"', (tester) async {
    await _pump(tester, maintenance: maintenanceJson());

    expect(find.byKey(const Key('photos_section')), findsOneWidget);
    expect(find.text('Nenhuma foto ainda.'), findsOneWidget);
    expect(find.text('Adicionar fotos'), findsOneWidget);
  });

  testWidgets('com permissão e fotos, mostra todos os momentos e o botão',
      (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(photos: [photoJson(id: 1)]),
    );

    expect(find.text('Antes (1)'), findsOneWidget);
    expect(find.text('Durante (0)'), findsOneWidget);
    expect(find.text('Depois (0)'), findsOneWidget);
    expect(find.byKey(const Key('add_photos_button')), findsOneWidget);
  });

  testWidgets('sem permissão e sem fotos a seção some', (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(verified: true, workshopId: 9),
    );

    expect(find.byKey(const Key('photos_section')), findsNothing);
  });

  testWidgets('oficina que selou a OS pode enviar', (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(verified: true, workshopId: 9),
      user: const {
        'user_type': 'workshop',
        'features': photosFeatureOn,
        'workshop_id': 9
      },
    );

    expect(find.byKey(const Key('add_photos_button')), findsOneWidget);
  });

  testWidgets('outra oficina não vê o botão', (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [photoJson(id: 1)],
      ),
      user: const {
        'user_type': 'workshop',
        'features': photosFeatureOn,
        'workshop_id': 77
      },
    );

    expect(find.byKey(const Key('photo_thumb_1')), findsOneWidget);
    expect(find.byKey(const Key('add_photos_button')), findsNothing);
  });

  testWidgets('tocar numa miniatura abre o visualizador na foto certa',
      (tester) async {
    await _pump(
      tester,
      maintenance: maintenanceJson(
        verified: true,
        workshopId: 9,
        photos: [
          photoJson(id: 1, sort: 1),
          photoJson(id: 2, sort: 2),
        ],
      ),
    );

    await scrollTo(tester, find.byKey(const Key('photo_thumb_2')));
    await tester.tap(find.byKey(const Key('photo_thumb_2')));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenancePhotoViewerPage), findsOneWidget);
    expect(find.text('Foto 2 de 2 — Antes · Veículo'), findsOneWidget);
    // Sem permissão: nada de excluir.
    expect(find.byKey(const Key('photo_viewer_delete')), findsNothing);
  });

  testWidgets('excluir pede confirmação e recarrega a seção', (tester) async {
    final api = await _pump(
      tester,
      maintenance: maintenanceJson(
        photos: [photoJson(id: 1), photoJson(id: 2, sort: 2)],
      ),
    );
    final callsBefore = api.getMaintenanceCalls;

    await scrollTo(tester, find.byKey(const Key('photo_thumb_1')));
    await tester.tap(find.byKey(const Key('photo_thumb_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('photo_viewer_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir foto'), findsOneWidget);

    // Cancelar não exclui.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.deletedPhotoIds, isEmpty);

    await tester.tap(find.byKey(const Key('photo_viewer_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo_delete_confirm')));
    await tester.pumpAndSettle();

    expect(api.deletedPhotoIds, [1]);
    expect(api.getMaintenanceCalls, greaterThan(callsBefore));
    // O visualizador segue aberto na foto que sobrou.
    expect(find.text('Foto 1 de 1 — Antes · Veículo'), findsOneWidget);
  });

  testWidgets('erro ao excluir mostra a mensagem e mantém a foto',
      (tester) async {
    final api = await _pump(
      tester,
      maintenance: maintenanceJson(photos: [photoJson(id: 1)]),
    );
    api.deleteError = dioError(403, {'message': 'Sem permissão.'});

    await scrollTo(tester, find.byKey(const Key('photo_thumb_1')));
    await tester.tap(find.byKey(const Key('photo_thumb_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo_viewer_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo_delete_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Sem permissão.'), findsOneWidget);
    expect(find.byType(MaintenancePhotoViewerPage), findsOneWidget);
  });

  group('recurso de fotos desligado', () {
    final cases = <String, Map<String, dynamic>>{
      'flag false': {
        'user_type': 'user',
        'features': {'maintenance_photos': false},
      },
      'features vazio': {'user_type': 'user', 'features': <String, dynamic>{}},
      'sem features': {'user_type': 'user'},
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key}: esconde a seção com fotos', (tester) async {
        await _pump(
          tester,
          user: entry.value,
          maintenance: maintenanceJson(photos: [photoJson(id: 1)]),
        );

        expect(find.byKey(const Key('photos_section')), findsNothing);
        expect(find.text('Fotos'), findsNothing);
      });

      testWidgets('${entry.key}: sem "Adicionar fotos" nem cartão bloqueado',
          (tester) async {
        await _pump(tester, user: entry.value, maintenance: maintenanceJson());

        expect(find.byKey(const Key('add_photos_button')), findsNothing);

        await _pump(
          tester,
          user: entry.value,
          maintenance: maintenanceJson(photosLocked: true, photosCount: 2),
        );

        expect(find.byKey(const Key('photos_locked_card')), findsNothing);
        expect(find.byKey(const Key('photos_section')), findsNothing);
      });
    }

    testWidgets('ligado: a seção aparece', (tester) async {
      await _pump(
        tester,
        maintenance: maintenanceJson(photos: [photoJson(id: 1)]),
      );

      expect(find.byKey(const Key('photos_section')), findsOneWidget);
    });
  });
}
