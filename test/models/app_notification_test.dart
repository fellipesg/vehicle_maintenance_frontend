import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/app_notification.dart';

void main() {
  test('parses the API notification and builds navigation data', () {
    final notification = AppNotification.fromJson({
      'id': 'abc',
      'type': 'workshop-review-decided',
      'title': 'Dev Oficina confirmou o seu serviço',
      'body': 'Agora tem o Selo da oficina.',
      'vehicle_id': 3,
      'maintenance_id': 12,
      'data': {'status': 'confirmed'},
      'read_at': null,
      'created_at': '2026-10-03T12:00:00+00:00',
    });

    expect(notification.isUnread, isTrue);
    expect(notification.maintenanceId, 12);
    expect(notification.navigationData['type'], 'workshop-review-decided');
    expect(notification.navigationData['maintenance_id'], 12);
    expect(notification.navigationData['status'], 'confirmed');
    expect(notification.markedAsRead().isUnread, isFalse);
  });

  test('falls back when fields are missing', () {
    final notification = AppNotification.fromJson({'id': 1});

    expect(notification.title, 'Notificação');
    expect(notification.body, '');
    expect(notification.data, isEmpty);
    expect(notification.createdAt, isNull);
  });
}
