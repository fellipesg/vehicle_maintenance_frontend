import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';

class _RecordingApiService extends ApiService {
  _RecordingApiService() : super(baseUrl: 'http://test');

  Map<String, dynamic>? lastUpdatePayload;

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
    lastUpdatePayload = data;

    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {'success': true, 'data': data},
      statusCode: 200,
    );
  }
}

Widget _wrap(Widget child, ApiService apiService) {
  return Provider<ApiService>.value(
    value: apiService,
    child: MaterialApp(home: child),
  );
}

Vehicle _vehicle({String? renavam = '12345678901'}) => Vehicle(
      id: 9,
      licensePlate: 'ABC1D23',
      renavam: renavam,
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      chassis: '9BWZZZ377VT004251',
      currentKilometers: 10000,
    );

Finder _renavamField() => find.ancestor(
      of: find.text('RENAVAM *'),
      matching: find.byType(TextFormField),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clearing RENAVAM blocks the submit instead of hitting a 422',
      (tester) async {
    final apiService = _RecordingApiService();

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: _vehicle()), apiService));
    await tester.pumpAndSettle();

    await tester.enterText(_renavamField(), '');
    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.text('RENAVAM é obrigatório'), findsOneWidget);
    expect(apiService.lastUpdatePayload, isNull);
  });

  testWidgets('editing keeps a legacy RENAVAM that is not 11 digits',
      (tester) async {
    final apiService = _RecordingApiService();

    await tester.pumpWidget(
      _wrap(VehicleFormPage(vehicle: _vehicle(renavam: '1234567890')), apiService),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.text('RENAVAM deve ter 11 dígitos'), findsNothing);
    expect(apiService.lastUpdatePayload?['renavam'], '1234567890');
  });

  testWidgets('never sends renavam as null on update', (tester) async {
    final apiService = _RecordingApiService();

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: _vehicle()), apiService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(apiService.lastUpdatePayload, isNotNull);
    expect(apiService.lastUpdatePayload!.containsKey('renavam'), isTrue);
    expect(apiService.lastUpdatePayload!['renavam'], '12345678901');
  });
}
