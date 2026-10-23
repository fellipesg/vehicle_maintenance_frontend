import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';
import 'package:vehicle_maintenance/widgets/photos/maintenance_photo_image.dart';

import '../../support_photos.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
    );

void main() {
  final photo = MaintenancePhoto.fromJson(photoJson(id: 12));

  testWidgets('usa cacheKey por id e variante, e não manda Authorization',
      (tester) async {
    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: photo)));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.cacheKey, 'photo:12:thumb');
    expect(image.imageUrl, 'https://cdn.example/t/12?sig=a');
    // Bearer em URL pré-assinada de S3/R2 quebra a assinatura.
    expect(image.httpHeaders, isEmpty);
  });

  testWidgets('cada variante tem a própria URL e a própria chave',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        MaintenancePhotoImage(photo: photo, variant: PhotoVariant.master),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.cacheKey, 'photo:12:master');
    expect(image.imageUrl, 'https://cdn.example/m/12?sig=a');
  });

  testWidgets('a chave de cache não muda quando a assinatura muda',
      (tester) async {
    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: photo)));
    final first = tester
        .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .cacheKey;

    final renewed = MaintenancePhoto.fromJson(
      photoJson(id: 12)
        ..['variants'] = {'thumb': 'https://cdn.example/t/12?sig=NOVA'},
    );
    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: renewed)));

    final second = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(second.cacheKey, first);
    expect(second.imageUrl, contains('sig=NOVA'));
  });

  testWidgets('reserva o espaço pela proporção quando pedido', (tester) async {
    await tester.pumpWidget(
      _wrap(Center(
          child: MaintenancePhotoImage(photo: photo, useAspectRatio: true))),
    );

    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 2.0);
  });

  testWidgets('sem proporção conhecida não usa AspectRatio', (tester) async {
    final unknown = MaintenancePhoto.fromJson(
      photoJson(id: 3, width: null, height: null),
    );

    await tester.pumpWidget(
      _wrap(MaintenancePhotoImage(photo: unknown, useAspectRatio: true)),
    );

    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('placeholder usa a cor dominante', (tester) async {
    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: photo)));
    await tester.pump();

    final colors = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((box) => box.color);
    expect(colors, contains(const Color(0xFF5A6B7C)));
  });

  testWidgets('sem nenhuma URL mostra só o placeholder', (tester) async {
    final empty =
        MaintenancePhoto.fromJson(photoJson(id: 4)..['variants'] = {});

    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: empty)));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('imagem que falha pede URL nova uma única vez', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _wrap(
        MaintenancePhotoImage(
          photo: photo,
          refresher: (_) async {
            calls++;

            return MaintenancePhoto.fromJson(
              photoJson(id: 12)
                ..['variants'] = {'thumb': 'https://cdn.example/t/12?sig=b'},
            );
          },
        ),
      ),
    );

    // O download não roda no teste; chamamos o errorWidget como o
    // CachedNetworkImage faria com uma URL expirada (403).
    void fail() {
      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      final context = tester.element(find.byType(CachedNetworkImage));
      image.errorWidget!(context, image.imageUrl, Exception('403'));
    }

    fail();
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'https://cdn.example/t/12?sig=b',
    );

    // Segunda falha com a URL nova: não entra em laço.
    fail();
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('sem refresher a falha só mostra o placeholder', (tester) async {
    await tester.pumpWidget(_wrap(MaintenancePhotoImage(photo: photo)));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    final context = tester.element(find.byType(CachedNetworkImage));
    final widget = image.errorWidget!(context, image.imageUrl, Exception('x'));

    expect(widget, isA<ColoredBox>());
  });
}
