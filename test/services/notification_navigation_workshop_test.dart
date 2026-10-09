import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/notification_navigation.dart';

void main() {
  test('workshop_records_pending opens the records list, not the vehicle', () {
    expect(
      NotificationNavigation.targetFor({
        'type': 'workshop_records_pending',
        'vehicle_id': '3',
        'count': '2',
      }),
      NotificationTarget.workshopRecords,
    );
  });
}
