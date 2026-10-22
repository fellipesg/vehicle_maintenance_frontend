import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_photo_viewer_page.dart';

import '../../support_photos.dart';

List<MaintenancePhoto> _photos() => [
      MaintenancePhoto.fromJson(photoJson(id: 1, stage: 'before')),
      MaintenancePhoto.fromJson(
        photoJson(id: 2, stage: 'after', subject: 'part', itemId: 7),
      ),
      MaintenancePhoto.fromJson(photoJson(id: 3, stage: 'after')),
    ];

Widget _app(Widget viewer) => MaterialApp(home: viewer);

void main() {
  test('legenda de uma foto do veículo e de uma peça', () {
    final photos = _photos();

    expect(
      photoCaption(photos[0], position: 2, total: 6),
      'Foto 2 de 6 — Antes · Veículo',
    );
    expect(
      photoCaption(photos[1], position: 1, total: 3, itemNames: {7: 'Filtro'}),
      'Foto 1 de 3 — Depois · Peça: Filtro',
    );
    expect(
      photoCaption(photos[1], position: 1, total: 3),
      'Foto 1 de 3 — Depois · Peça',
    );
  });

  testWidgets('abre na foto pedida com a legenda', (tester) async {
    await tester.pumpWidget(
      _app(MaintenancePhotoViewerPage(photos: _photos(), initialIndex: 1)),
    );
    await tester.pump();

    expect(find.text('Foto 2 de 3 — Depois · Peça'), findsOneWidget);
  });

  testWidgets('deslizar troca de foto e atualiza a legenda', (tester) async {
    await tester.pumpWidget(
      _app(MaintenancePhotoViewerPage(photos: _photos())),
    );
    await tester.pump();

    expect(find.text('Foto 1 de 3 — Antes · Veículo'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('photo_viewer_pages')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Foto 2 de 3 — Depois · Peça'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('photo_viewer_pages')),
      const Offset(500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Foto 1 de 3 — Antes · Veículo'), findsOneWidget);
  });

  testWidgets('usa a variante display e só carrega a master ao aproximar',
      (tester) async {
    await tester.pumpWidget(
      _app(MaintenancePhotoViewerPage(photos: _photos())),
    );
    await tester.pump();

    CachedNetworkImage image() =>
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

    expect(image().cacheKey, 'photo:1:display');
    expect(image().httpHeaders, isEmpty);
    expect(find.byKey(const Key('photo_viewer_master')), findsNothing);

    // Toque duplo aproxima (2,5x), e a master entra por cima.
    final center =
        tester.getCenter(find.byKey(const Key('photo_viewer_interactive')));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo_viewer_master')), findsOneWidget);
    final keys = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((i) => i.cacheKey);
    expect(keys, containsAll(['photo:1:display', 'photo:1:master']));
  });

  testWidgets('com zoom o arrasto não troca de foto', (tester) async {
    await tester.pumpWidget(
      _app(MaintenancePhotoViewerPage(photos: _photos())),
    );
    await tester.pump();

    final center =
        tester.getCenter(find.byKey(const Key('photo_viewer_interactive')));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    final pages =
        tester.widget<PageView>(find.byKey(const Key('photo_viewer_pages')));
    expect(pages.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('fechar devolve false quando nada foi excluído', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => MaintenancePhotoViewerPage(photos: _photos()),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fechar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_viewer_close')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('cada página tem rótulo acessível com a legenda', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(MaintenancePhotoViewerPage(photos: _photos())),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Foto 1 de 3 — Antes · Veículo'),
      findsWidgets,
    );
    handle.dispose();
  });
}
