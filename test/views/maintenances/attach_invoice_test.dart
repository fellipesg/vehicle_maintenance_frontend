import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}

class _FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(ApiService api, this.userData)
      : super(
          api,
          tokenStorage: _FakeTokenStorage(),
          fcmService: _FakeFcmService(),
        );

  final Map<String, dynamic> userData;

  @override
  Map<String, dynamic>? get user => userData;
}

class _FakeApiService extends ApiService {
  _FakeApiService({required this.maintenance}) : super(baseUrl: 'http://test');

  final Map<String, dynamic> maintenance;

  int uploadCalls = 0;

  @override
  Future<Response> getMaintenance(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/maintenances/$id'),
      data: {'success': true, 'data': maintenance},
      statusCode: 200,
    );
  }

  @override
  Future<Response> getVehicle(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {
        'success': true,
        'data': {
          'id': 1,
          'license_plate': 'ABC1D23',
          'brand': 'VW',
          'model': 'Gol',
          'year': 2020,
        },
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> uploadInvoice({
    required int maintenanceId,
    required String filePath,
  }) async {
    uploadCalls++;

    return Response(
      requestOptions: RequestOptions(path: '/invoices/upload'),
      data: const {'success': true},
      statusCode: 201,
    );
  }
}

Map<String, dynamic> _maintenance({
  bool verified = false,
  int? workshopId,
  List<Map<String, dynamic>> invoices = const [],
}) {
  return {
    'id': 5,
    'vehicle_id': 1,
    'maintenance_type': 'Revisão',
    'maintenance_date': '2026-01-10',
    'kilometers': 50000,
    'service_category': 'mechanical',
    'is_verified': verified,
    if (workshopId != null) 'workshop_id': workshopId,
    'invoices': invoices,
  };
}

Widget _wrap(_FakeApiService api, _FakeAuthService auth) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      Provider<AuthService>.value(value: auth),
    ],
    child: const MaterialApp(
      home: MaintenanceDetailPage(maintenanceId: 5),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('owner can attach to a declared record', (tester) async {
    final api = _FakeApiService(maintenance: _maintenance());
    final auth = _FakeAuthService(api, {'user_type': 'user'});

    await tester.pumpWidget(_wrap(api, auth));
    await tester.pumpAndSettle();

    // O card aparece mesmo sem nota, senão não haveria onde anexar.
    expect(find.text('Nenhuma nota anexada.'), findsOneWidget);
    expect(find.byKey(const Key('attach_invoice_button')), findsOneWidget);
  });

  testWidgets('owner cannot attach to a workshop-sealed record',
      (tester) async {
    final api = _FakeApiService(
      maintenance: _maintenance(verified: true, workshopId: 9),
    );
    final auth = _FakeAuthService(api, {'user_type': 'user'});

    await tester.pumpWidget(_wrap(api, auth));
    await tester.pumpAndSettle();

    // MaintenancePolicy::canChange nega, então o botão não pode aparecer e
    // levar o usuário a um 403.
    expect(find.byKey(const Key('attach_invoice_button')), findsNothing);
  });

  testWidgets('workshop can attach to the record it sealed', (tester) async {
    final api = _FakeApiService(
      maintenance: _maintenance(verified: true, workshopId: 9),
    );
    final auth = _FakeAuthService(api, {
      'user_type': 'workshop',
      'workshop_id': 9,
    });

    await tester.pumpWidget(_wrap(api, auth));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attach_invoice_button')), findsOneWidget);
  });

  testWidgets('workshop cannot attach to another workshop record',
      (tester) async {
    final api = _FakeApiService(
      maintenance: _maintenance(verified: true, workshopId: 9),
    );
    final auth = _FakeAuthService(api, {
      'user_type': 'workshop',
      'workshop_id': 77,
    });

    await tester.pumpWidget(_wrap(api, auth));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attach_invoice_button')), findsNothing);
  });

  testWidgets('an existing invoice is listed with the attach button',
      (tester) async {
    final api = _FakeApiService(
      maintenance: _maintenance(invoices: [
        {
          'id': 3,
          'maintenance_id': 5,
          'file_name': 'nota.pdf',
          'invoice_type': 'general',
        },
      ]),
    );
    final auth = _FakeAuthService(api, {'user_type': 'user'});

    await tester.pumpWidget(_wrap(api, auth));
    await tester.pumpAndSettle();

    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('Nenhuma nota anexada.'), findsNothing);
    expect(find.byKey(const Key('attach_invoice_button')), findsOneWidget);
  });
}
