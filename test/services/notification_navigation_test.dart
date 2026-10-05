import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/notification_navigation.dart';

void main() {
  group('NotificationNavigation', () {
    test('extracts vehicle id from payload data', () {
      expect(
        NotificationNavigation.vehicleIdFromPayload({'vehicle_id': '42'}),
        42,
      );
      expect(
        NotificationNavigation.vehicleIdFromPayload({'vehicle_id': 7}),
        7,
      );
      expect(NotificationNavigation.vehicleIdFromPayload({}), isNull);
    });

    test('workshop review answer opens the maintenance', () {
      expect(
        NotificationNavigation.targetFor({
          'type': 'workshop-review-decided',
          'status': 'confirmed',
          'maintenance_id': '12',
          'vehicle_id': '3',
        }),
        NotificationTarget.maintenance,
      );
    });

    test('vehicle reminders open the vehicle', () {
      expect(
        NotificationNavigation.targetFor({'vehicle_id': '3'}),
        NotificationTarget.vehicle,
      );
    });

    test('maintenance id alone does not open the maintenance for other types',
        () {
      expect(
        NotificationNavigation.targetFor({
          'type': 'workshop-review-requested',
          'maintenance_id': '12',
        }),
        NotificationTarget.inbox,
      );
    });

    test('payload round-trips through the local notification', () {
      final data = {
        'type': 'workshop-review-decided',
        'maintenance_id': '12',
      };

      expect(
        NotificationNavigation.decodePayload(
          NotificationNavigation.encodePayload(data),
        ),
        data,
      );
    });

    test('accepts the legacy payload with only the vehicle id', () {
      expect(
        NotificationNavigation.decodePayload('42'),
        {'vehicle_id': 42},
      );
      expect(NotificationNavigation.decodePayload(''), isNull);
      expect(NotificationNavigation.decodePayload('not json'), isNull);
    });
  });
}
