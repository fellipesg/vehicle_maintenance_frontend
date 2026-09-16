import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';

class _FakeApiService extends ApiService {
  _FakeApiService(this.maintenanceResponse) : super(baseUrl: 'http://test');

  final Map<String, dynamic> maintenanceResponse;

  @override
  Future<Response> getMaintenance(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/maintenances/$id'),
      data: maintenanceResponse,
    );
  }

  @override
  Future<Response> getVehicle(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {
        'success': true,
        'data': {
          'id': 10,
          'brand': 'VW',
          'model': 'Gol',
        },
      },
    );
  }
}

void main() {
  testWidgets('detail shows general warranty chip and workshop logo',
      (tester) async {
    final api = _FakeApiService({
      'success': true,
      'data': {
        'id': 1,
        'vehicle_id': 10,
        'maintenance_type': 'Revisão',
        'maintenance_date': '2026-02-01',
        'general_warranty': {
          'name': 'Garantia OS',
          'label': 'Em garantia até 02/05/2026',
          'is_vigente': true,
          'ends_at': '2026-05-02',
        },
        'workshop': {
          'id': 2,
          'name': 'Oficina Demo',
          'phone': '11999999999',
          'cep': '01310100',
          'street': 'Av Paulista',
          'number': '1000',
          'neighborhood': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
          'logo_url': 'https://example.com/logo.png',
        },
        'items': [
          {
            'name': 'Pastilha',
            'quantity': 1,
            'unit_price': '100.00',
            'total_price': '100.00',
            'has_warranty': true,
            'is_under_warranty': true,
            'warranty': {
              'name': 'Garantia peça',
              'label': 'Em garantia até 01/08/2026',
              'is_vigente': true,
            },
          },
        ],
      },
    });

    final authService = AuthService(api);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            Provider<AuthService>.value(value: authService),
          ],
          child: const MaintenanceDetailPage(maintenanceId: 1),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Em garantia até 02/05/2026'), findsOneWidget);
    expect(find.text('Garantia peça'), findsOneWidget);
    expect(find.text('Em garantia'), findsOneWidget);
  });
}
