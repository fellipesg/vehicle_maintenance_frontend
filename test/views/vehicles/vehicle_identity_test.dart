import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/widgets/vehicle_identity.dart';

void main() {
  testWidgets('highlights chassis and current plate chip', (tester) async {
    final vehicle = Vehicle(
      id: 1,
      licensePlate: 'ABC1D23',
      currentPlate: 'ABC1D23',
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      chassis: '9BWZZZ377VT004251',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body:
              VehicleIdentity(vehicle: vehicle, size: VehicleIdentitySize.hero),
        ),
      ),
    );

    expect(find.text('9BWZZZ377VT004251'), findsOneWidget);
    expect(find.text('Placa atual ABC1D23'), findsOneWidget);
    expect(find.text('CHASSI'), findsOneWidget);
  });

  testWidgets('null chassis shows amber chip', (tester) async {
    final vehicle = Vehicle(
      licensePlate: 'XYZ9Z99',
      brand: 'Fiat',
      model: 'Uno',
      year: 2010,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleIdentity(vehicle: vehicle),
        ),
      ),
    );

    expect(find.text('Chassi não informado'), findsOneWidget);
  });

  testWidgets('copy chassis shows snackbar', (tester) async {
    final vehicle = Vehicle(
      licensePlate: 'ABC1D23',
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      chassis: 'CHASSIS12345678901',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleIdentity(
            vehicle: vehicle,
            size: VehicleIdentitySize.hero,
            showCopy: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy_chassis_button')));
    await tester.pump();

    expect(find.text('Chassi copiado'), findsOneWidget);
  });
}
