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
  });
}
