import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/maintenance_photos_feature.dart';

import '../support_photos.dart';

void main() {
  group('MaintenancePhotosFeature.isEnabledFor', () {
    test('true quando features.maintenance_photos é true', () {
      expect(
        MaintenancePhotosFeature.isEnabledFor(const {
          'features': {'maintenance_photos': true},
        }),
        isTrue,
      );
    });

    test('false quando a flag é false', () {
      expect(
        MaintenancePhotosFeature.isEnabledFor(const {
          'features': {'maintenance_photos': false},
        }),
        isFalse,
      );
    });

    test('false quando falta a flag, o features ou o usuário', () {
      expect(
        MaintenancePhotosFeature.isEnabledFor(const {'features': {}}),
        isFalse,
      );
      expect(
        MaintenancePhotosFeature.isEnabledFor(const {'features': null}),
        isFalse,
      );
      expect(
        MaintenancePhotosFeature.isEnabledFor(const {'name': 'Ana'}),
        isFalse,
      );
      expect(MaintenancePhotosFeature.isEnabledFor(null), isFalse);
    });

    test('só o booleano true liga (nada de "1" ou "true")', () {
      for (final raw in <Object?>[1, '1', 'true', null]) {
        expect(
          MaintenancePhotosFeature.isEnabledFor({
            'features': {'maintenance_photos': raw},
          }),
          isFalse,
          reason: '$raw',
        );
      }
    });
  });

  group('AuthService.hasMaintenancePhotos', () {
    test('acompanha o usuário em cache e muda quando o /me é relido', () async {
      final api = FakePhotosApi(me: {
        'user_type': 'user',
        'features': {'maintenance_photos': true},
      });
      final auth = FakeAuth(api as ApiService, const {'user_type': 'user'});

      expect(auth.hasMaintenancePhotos, isFalse);

      await auth.getCurrentUser();

      expect(auth.hasMaintenancePhotos, isTrue);

      api.me = {
        'user_type': 'user',
        'features': {'maintenance_photos': false},
      };
      await auth.getCurrentUser();

      expect(auth.hasMaintenancePhotos, isFalse);
    });
  });
}
