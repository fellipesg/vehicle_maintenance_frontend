import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/vehicle_lookup_result.dart';

void main() {
  test('VehicleLookupResult.fromApi parses matched_by', () {
    final result = VehicleLookupResult.fromApi({
      'data': {
        'license_plate': 'OLD1A23',
        'current_plate': 'NEW2B34',
        'brand': 'VW',
        'model': 'Gol',
        'year': 2018,
        'matched_by': VehicleLookupResult.matchPreviousPlate,
        'previous_plate_ended_at': '2023-06-01',
      },
    });

    expect(result.matchedBy, VehicleLookupResult.matchPreviousPlate);
    expect(result.vehicle.displayPlate, 'NEW2B34');
    expect(result.previousPlateEndedAt, isNotNull);
  });
}
