import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';
import 'package:vehicle_maintenance/services/maintenance_photo_uploader.dart';

import '../support_photos.dart';

MaintenancePhotoUploader _uploader(FakePhotosApi api, List<String> paths) {
  return MaintenancePhotoUploader(
    api: api,
    maintenanceId: 5,
    subject: PhotoSubject.part,
    stage: PhotoStage.after,
    maintenanceItemId: 7,
    paths: paths,
  );
}

void main() {
  test('remainingSlots respeita o máximo de 4 por grupo', () {
    expect(MaintenancePhotoUploader.remainingSlots(0), 4);
    expect(MaintenancePhotoUploader.remainingSlots(3), 1);
    expect(MaintenancePhotoUploader.remainingSlots(4), 0);
    expect(MaintenancePhotoUploader.remainingSlots(9), 0);
  });

  test('envia em ordem com assunto, momento e item', () async {
    final api = FakePhotosApi();
    final uploader = _uploader(api, ['/tmp/a.jpg', '/tmp/b.jpg']);

    await uploader.start();

    expect(api.uploads, [
      {
        'maintenance_id': 5,
        'path': '/tmp/a.jpg',
        'subject': 'part',
        'stage': 'after',
        'item': 7,
      },
      {
        'maintenance_id': 5,
        'path': '/tmp/b.jpg',
        'subject': 'part',
        'stage': 'after',
        'item': 7,
      },
    ]);
    expect(uploader.items.every((i) => i.status == PhotoUploadStatus.done),
        isTrue);
    expect(uploader.isFinished, isTrue);
    expect(uploader.hasFailures, isFalse);
    expect(uploader.items.first.name, 'a.jpg');
  });

  test('reporta o progresso de cada arquivo', () async {
    final api = FakePhotosApi();
    final seen = <double>[];
    api.uploadHandler = (path, onProgress) async {
      onProgress?.call(25, 100);
      onProgress?.call(100, 100);
    };
    final uploader = _uploader(api, ['/tmp/a.jpg']);
    uploader.addListener(() => seen.add(uploader.items.first.progress));

    await uploader.start();

    expect(seen, containsAllInOrder([0.25, 1.0]));
  });

  test('falha de um arquivo não derruba os outros e mostra a mensagem',
      () async {
    final api = FakePhotosApi();
    api.uploadHandler = (path, _) async {
      if (path.endsWith('b.jpg')) {
        throw dioError(422, {
          'message': 'The given data was invalid.',
          'errors': {
            'photo': ['Limite de 4 fotos atingido para este grupo.'],
          },
        });
      }
    };
    final uploader = _uploader(api, ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg']);

    await uploader.start();

    expect(uploader.items.map((i) => i.status), [
      PhotoUploadStatus.done,
      PhotoUploadStatus.failed,
      PhotoUploadStatus.done,
    ]);
    expect(
        uploader.items[1].error, 'Limite de 4 fotos atingido para este grupo.');
    expect(uploader.hasFailures, isTrue);
    expect(uploader.hasUploaded, isTrue);
  });

  test('retryFailed reenvia só o que falhou', () async {
    final api = FakePhotosApi();
    var failB = true;
    api.uploadHandler = (path, _) async {
      if (path.endsWith('b.jpg') && failB) {
        throw dioError(500, {});
      }
    };
    final uploader = _uploader(api, ['/tmp/a.jpg', '/tmp/b.jpg']);

    await uploader.start();
    expect(uploader.hasFailures, isTrue);
    expect(api.uploads, hasLength(2));

    failB = false;
    await uploader.retryFailed();

    expect(uploader.hasFailures, isFalse);
    expect(api.uploads.map((u) => u['path']), [
      '/tmp/a.jpg',
      '/tmp/b.jpg',
      '/tmp/b.jpg',
    ]);
  });
}
