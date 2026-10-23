import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';

import '../support_photos.dart';

void main() {
  group('MaintenancePhoto.fromJson', () {
    test('lê todos os campos do resource', () {
      final photo = MaintenancePhoto.fromJson(
        photoJson(id: 12, stage: 'after', subject: 'part', itemId: 7),
      );

      expect(photo.id, 12);
      expect(photo.maintenanceId, 5);
      expect(photo.maintenanceItemId, 7);
      expect(photo.subject, PhotoSubject.part);
      expect(photo.stage, PhotoStage.after);
      expect(photo.originalName, 'foto-12.jpg');
      expect(photo.createdBy, 3);
      expect(photo.createdAt, DateTime.utc(2026, 10, 1, 10));
      expect(photo.expiresAt, DateTime.utc(2026, 10, 1, 10, 10));
      expect(photo.processed, isTrue);
      expect(photo.dominantColor, const Color(0xFF5A6B7C));
      expect(photo.aspectRatio, 2.0);
      expect(photo.thumbUrl, 'https://cdn.example/t/12?sig=a');
      expect(photo.displayUrl, 'https://cdn.example/d/12?sig=a');
      expect(photo.masterUrl, 'https://cdn.example/m/12?sig=a');
      expect(photo.legacyUrl, 'http://test/api/v1/maintenance-photos/12');
    });

    test('aceita campos nulos (ainda sem processar)', () {
      final photo = MaintenancePhoto.fromJson(
        photoJson(width: null, height: null, color: null)
          ..['processed'] = false
          ..['variants'] = {'master': 'https://cdn.example/m/1'},
      );

      expect(photo.aspectRatio, isNull);
      expect(photo.dominantColor, isNull);
      expect(photo.processed, isFalse);
      // Sem thumb/display, cai na variante que existir.
      expect(photo.thumbUrl, 'https://cdn.example/m/1');
      expect(photo.displayUrl, 'https://cdn.example/m/1');
    });

    test('ignora cor inválida e variantes vazias', () {
      final photo = MaintenancePhoto.fromJson(
        photoJson(color: 'azul')..['variants'] = {'thumb': ''},
      );

      expect(photo.dominantColor, isNull);
      expect(photo.thumbUrl, isNull);
    });

    test('cacheKey usa id e variante, nunca a URL assinada', () {
      final photo = MaintenancePhoto.fromJson(photoJson(id: 12));

      expect(photo.cacheKey(PhotoVariant.thumb), 'photo:12:thumb');
      expect(photo.cacheKey(PhotoVariant.display), 'photo:12:display');
      expect(photo.cacheKey(PhotoVariant.master), 'photo:12:master');
    });

    test('o limite de 4 conta por assunto e momento', () {
      final photo = MaintenancePhoto.fromJson(
        photoJson(subject: 'part', stage: 'during', itemId: 3),
      );

      expect(photo.sameGroupAs(PhotoSubject.part, PhotoStage.during), isTrue);
      expect(
          photo.sameGroupAs(PhotoSubject.vehicle, PhotoStage.during), isFalse);
      expect(photo.sameGroupAs(PhotoSubject.part, PhotoStage.after), isFalse);
    });
  });

  group('Maintenance.fromJson com fotos', () {
    test('lê photos, photos_count e photos_locked', () {
      final maintenance = Maintenance.fromJson(
        maintenanceJson(photos: [photoJson(id: 1), photoJson(id: 2)]),
      );

      expect(maintenance.photos.map((p) => p.id), [1, 2]);
      expect(maintenance.photosCount, 2);
      expect(maintenance.photosLocked, isFalse);
    });

    test('bloqueada: contagem vem sem as fotos', () {
      final maintenance = Maintenance.fromJson(
        maintenanceJson(photosLocked: true, photosCount: 3),
      );

      expect(maintenance.photos, isEmpty);
      expect(maintenance.photosCount, 3);
      expect(maintenance.photosLocked, isTrue);
    });

    test('backend antigo (sem os campos) não quebra', () {
      final maintenance = Maintenance.fromJson({
        'id': 1,
        'vehicle_id': 1,
        'maintenance_type': 'Revisão',
        'maintenance_date': '2026-01-01',
      });

      expect(maintenance.photos, isEmpty);
      expect(maintenance.photosCount, 0);
      expect(maintenance.photosLocked, isFalse);
    });
  });
}
