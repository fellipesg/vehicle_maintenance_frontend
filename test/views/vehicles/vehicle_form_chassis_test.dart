import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'http://test');

  @override
  Future<Response<dynamic>> getTermsOfUse() async {
    return Response(
      requestOptions: RequestOptions(path: '/legal/terms-of-use'),
      data: {
        'success': true,
        'data': {'content': 'Termos de teste'},
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> updateVehicle(
    String id,
    Map<String, dynamic> data,
  ) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {'data': data},
      statusCode: 200,
    );
  }
}

Widget _wrap(Widget child) {
  return Provider<ApiService>.value(
    value: _FakeApiService(),
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty chassis shows validation error', (tester) async {
    final vehicle = Vehicle(
      id: 9,
      licensePlate: 'ABC1D23',
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      currentKilometers: 10000,
    );

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: vehicle)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pump();

    expect(find.text('Informe o chassi'), findsOneWidget);
  });

  testWidgets('chassis field uppercases input', (tester) async {
    await tester.pumpWidget(_wrap(const VehicleFormPage()));
    await tester.pumpAndSettle();

    final chassisField = find.byKey(const Key('vehicle_chassis_field'));
    await tester.enterText(chassisField, 'abc12xyz');
    await tester.pump();

    expect(find.text('ABC12XYZ'), findsOneWidget);
  });

  testWidgets('chassis field appears before plate field', (tester) async {
    await tester.pumpWidget(_wrap(const VehicleFormPage()));
    await tester.pumpAndSettle();

    final chassisY =
        tester.getTopLeft(find.byKey(const Key('vehicle_chassis_field'))).dy;
    final plateLabel = find.text('Placa *');
    final plateField = find.ancestor(
      of: plateLabel,
      matching: find.byType(TextFormField),
    );
    final plateY = tester.getTopLeft(plateField).dy;

    expect(chassisY, lessThan(plateY));
  });

  testWidgets('editing plate shows register change dialog', (tester) async {
    final vehicle = Vehicle(
      id: 9,
      licensePlate: 'ABC1D23',
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      chassis: '9BWZZZ377VT004251',
      currentKilometers: 10000,
    );

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: vehicle)));
    await tester.pumpAndSettle();

    final plateField = find.ancestor(
      of: find.text('Placa *'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(plateField, 'XYZ9Z99');
    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar troca de placa?'), findsOneWidget);
  });
}
