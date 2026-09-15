import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';

void main() {
  test('Vehicle.fromJson parses provenance and plate history', () {
    final vehicle = Vehicle.fromJson({
      'id': 1,
      'license_plate': 'ABC1D23',
      'current_plate': 'ABC1D23',
      'brand': 'VW',
      'model': 'Gol',
      'year': 2020,
      'chassis': '9BWZZZ377VT004251',
      'maintenances_count': 3,
      'verified_maintenances_count': 2,
      'provenance_strip': [
        {'maintenance_id': 10, 'date': '2024-01-01', 'is_verified': true},
      ],
      'plate_history': [
        {'plate': 'ABC1D23', 'started_at': '2024-01-01', 'source': 'api'},
      ],
    });

    expect(vehicle.chassis, '9BWZZZ377VT004251');
    expect(vehicle.maintenancesCount, 3);
    expect(vehicle.provenanceStrip?.length, 1);
    expect(vehicle.plateHistory?.first.plate, 'ABC1D23');
  });

  test('Vehicle.fromJson tolerates missing provenance fields', () {
    final vehicle = Vehicle.fromJson({
      'license_plate': 'XYZ9Z99',
      'brand': 'Fiat',
      'model': 'Uno',
      'year': 2010,
    });

    expect(vehicle.provenanceStrip, isNull);
    expect(vehicle.plateHistory, isNull);
  });

  test('Vehicle toJson round-trip core fields', () {
    final original = Vehicle(
      id: 5,
      licensePlate: 'QOS6H54',
      brand: 'Toyota',
      model: 'Corolla',
      year: 2022,
      chassis: 'CHASSIS12345678901',
      maintenancesCount: 1,
    );

    final restored = Vehicle.fromJson(original.toJson());
    expect(restored.licensePlate, original.licensePlate);
    expect(restored.chassis, original.chassis);
    expect(restored.maintenancesCount, 1);
  });
}
