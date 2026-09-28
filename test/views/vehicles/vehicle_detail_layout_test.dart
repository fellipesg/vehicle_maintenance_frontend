import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/provenance_segment.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_detail_page.dart';
import 'package:vehicle_maintenance/widgets/vehicle_identity.dart';

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'http://test');

  @override
  Future<Response<dynamic>> getVehicle(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {
        'success': true,
        'data': {
          'id': 1,
          'license_plate': 'BRA2E19',
          'brand': 'Mercedes-Benz',
          'model': 'C 180',
          'year': 2018,
          'color': 'BRANCA',
          'chassis': '9BWZZZ377VT004251',
          'renavam': '00123456789',
          'engine': 'DEMO156CV',
          'current_kilometers': 110000,
          'maintenances_count': 8,
          'verified_maintenances_count': 7,
          'provenance_strip': List.generate(
            8,
            (i) => {
              'maintenance_id': i + 1,
              'date': '2024-01-${(i + 1).toString().padLeft(2, '0')}',
              'is_verified': i < 7,
            },
          ),
        },
      },
    );
  }

  @override
  Future<Response<dynamic>> getVehicleTimeline(String vehicleId) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$vehicleId/timeline'),
      data: {
        'success': true,
        'data': {
          'summary': {
            'last_kilometers': 110000,
            'maintenance_count': 2,
            'total_spent': 500,
            'approximate_annual_kilometers': 12880,
          },
          'vehicle': {'brand': 'Mercedes-Benz', 'model': 'C 180'},
          'events': [
            {
              'type': 'registration',
              'label': 'Cadastro',
              'date': '2018-01-01',
              'kilometers': 0,
            },
            {
              'type': 'maintenance',
              'id': 1,
              'label': 'Revisão',
              'date': '2024-06-01',
              'kilometers': 100000,
              'is_verified': true,
              'workshop_name': 'Oficina Demo',
            },
            {
              'type': 'maintenance',
              'id': 2,
              'label': 'Troca de óleo',
              'date': '2025-01-01',
              'kilometers': 110000,
              'is_verified': false,
              'is_current': true,
            },
          ],
        },
      },
    );
  }
}

void main() {
  testWidgets('shows provenance filter, timeline and manutenções card',
      (tester) async {
    final api = _FakeApiService();
    final auth = AuthService(api);

    final initialVehicle = Vehicle(
      id: 1,
      licensePlate: 'BRA2E19',
      brand: 'Mercedes-Benz',
      model: 'C 180',
      year: 2018,
      maintenancesCount: 8,
      verifiedMaintenancesCount: 7,
      provenanceStrip: List.generate(
        8,
        (i) => ProvenanceSegment(
          maintenanceId: i + 1,
          date: DateTime(2024, 1, i + 1),
          isVerified: i < 7,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            Provider<AuthService>.value(value: auth),
            ChangeNotifierProvider<VehicleRepository>(
              create: (_) => VehicleRepository(api),
            ),
          ],
          child: VehicleDetailPage(
            vehicleId: 1,
            initialVehicle: initialVehicle,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Linha do tempo'), findsOneWidget);
    expect(find.text('Manutenções'), findsOneWidget);
    expect(find.byKey(const Key('provenance_filter_all')), findsOneWidget);
    expect(find.textContaining('com selo'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('provenance_strip_segment_0')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('provenance_strip_segment_0')), findsOneWidget);

    final identityTop = tester.getTopLeft(find.byType(VehicleIdentity));
    final segmentTop = tester.getTopLeft(
      find.byKey(const Key('provenance_strip_segment_0')),
    );
    final timelineTop = tester.getTopLeft(find.text('Linha do tempo'));
    final filterTop = tester.getTopLeft(
      find.byKey(const Key('provenance_filter_all')),
    );
    expect(segmentTop.dy, greaterThan(identityTop.dy));
    expect(segmentTop.dy, greaterThan(timelineTop.dy));
    expect(segmentTop.dy, lessThan(filterTop.dy));
  });

  testWidgets('declared filter hides verified maintenance on timeline',
      (tester) async {
    final api = _FakeApiService();
    final auth = AuthService(api);

    final initialVehicle = Vehicle(
      id: 1,
      licensePlate: 'BRA2E19',
      brand: 'Mercedes-Benz',
      model: 'C 180',
      year: 2018,
      maintenancesCount: 8,
      verifiedMaintenancesCount: 7,
      provenanceStrip: List.generate(
        8,
        (i) => ProvenanceSegment(
          maintenanceId: i + 1,
          date: DateTime(2024, 1, i + 1),
          isVerified: i < 7,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
            Provider<AuthService>.value(value: auth),
            ChangeNotifierProvider<VehicleRepository>(
              create: (_) => VehicleRepository(api),
            ),
          ],
          child: VehicleDetailPage(
            vehicleId: 1,
            initialVehicle: initialVehicle,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('Revisão'), findsOneWidget);
    expect(find.textContaining('Troca de óleo'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('provenance_filter_declared')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('provenance_filter_declared')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Revisão'), findsNothing);
    expect(find.textContaining('Troca de óleo'), findsWidgets);
  });
}
