import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/models/crlv_reading.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/meta_app_events.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';

const _token = 'f00dcafe';

Map<String, dynamic> _reading({
  String mode = 'new',
  String ownership = 'owner',
}) {
  return {
    'mode': mode,
    'ownership': ownership,
    'crlv_verification_token': _token,
    'expires_in_minutes': 30,
    'vehicle': {
      'license_plate': 'ABC1D23',
      'renavam': '12345678901',
      'crv_number': '246813579024',
      'brand': 'Volkswagen',
      'model': 'Gol',
      'year': 2020,
      'color': 'Prata',
      'chassis': '9BWZZZ377VT004251',
      'engine': null,
      'brand_matched': true,
      'model_matched': true,
    },
    'existing_vehicle': mode == 'claim'
        ? {
            'id': 7,
            'brand': 'Volkswagen',
            'model': 'Gol',
            'year': 2020,
            'maintenances_count': 3,
          }
        : null,
  };
}

class _RecordingMetaEvents implements MetaAppEvents {
  int vehicleAdded = 0;

  @override
  Future<void> logVehicleAdded() async => vehicleAdded++;

  @override
  Future<void> logCompleteRegistration() async {}
}

class _FakeApiService extends ApiService {
  _FakeApiService(this.readingData) : super(baseUrl: 'http://test');

  final Map<String, dynamic> readingData;
  Map<String, dynamic>? createdWith;
  String? claimedWith;

  Response<dynamic> _ok(String path, Object? data) => Response(
        requestOptions: RequestOptions(path: path),
        data: {'success': true, 'data': data},
        statusCode: 200,
      );

  @override
  Future<Response<dynamic>> getTermsOfUse() async =>
      _ok('/legal/terms-of-use', {'content': 'Termos de teste'});

  @override
  Future<List<String>> getCatalogBrands() async => const [];

  @override
  Future<List<String>> getCatalogModels(String brand) async => const [];

  @override
  Future<Response<dynamic>> readCrlv(String filePath) async =>
      _ok('/vehicles/crlv', readingData);

  @override
  Future<Response<dynamic>> createVehicle(Map<String, dynamic> data) async {
    createdWith = data;
    return _ok('/vehicles', {'id': 11});
  }

  @override
  Future<Response<dynamic>> claimVehicleWithCrlv(String token) async {
    claimedWith = token;
    return _ok('/vehicles/crlv/claim', {
      'vehicle': {'id': 7},
      'pending_workshop_records_count': 0,
    });
  }

  @override
  Future<Response<dynamic>> getMyVehicles({
    int page = 1,
    int perPage = 15,
    String? ifNoneMatch,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: '/my-vehicles'),
      data: {
        'success': true,
        'data': <dynamic>[],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
      },
      statusCode: 200,
    );
  }
}

Future<_FakeApiService> _pumpForm(
  WidgetTester tester,
  Map<String, dynamic> reading, {
  bool startWithCrlv = false,
  MetaAppEvents metaAppEvents = const MetaAppEvents(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = _FakeApiService(reading);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider(create: (_) => VehicleRepository(api)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleFormPage(
                      pickCrlvPdf: () async => '/tmp/CRLV-e.pdf',
                      startWithCrlv: startWithCrlv,
                      metaAppEvents: metaAppEvents,
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();

  return api;
}

TextField _field(WidgetTester tester, String label) {
  return tester.widget<TextField>(
    find.descendant(
      of: find.widgetWithText(TextFormField, label),
      matching: find.byType(TextField),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new vehicle CRLV-e fills the form and locks plate and RENAVAM',
      (tester) async {
    await _pumpForm(tester, _reading());

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();

    expect(find.text('Dados lidos do CRLV-e'), findsOneWidget);
    expect(_field(tester, 'Placa *').controller!.text, 'ABC1D23');
    expect(_field(tester, 'Placa *').readOnly, isTrue);
    expect(_field(tester, 'RENAVAM *').readOnly, isTrue);
    expect(_field(tester, 'Chassi *').controller!.text, '9BWZZZ377VT004251');
    expect(_field(tester, 'Ano *').controller!.text, '2020');

    await tester.tap(find.byKey(const Key('vehicle_crlv_clear')));
    await tester.pumpAndSettle();

    expect(find.text('Cadastre com o CRLV-e'), findsOneWidget);
    expect(_field(tester, 'Placa *').readOnly, isFalse);
  });

  testWidgets('saving after the CRLV-e sends the verification token',
      (tester) async {
    final api = await _pumpForm(tester, _reading());

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quilometragem atual *'),
      '42000',
    );
    final checkbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(api.createdWith?['crlv_verification_token'], _token);
    expect(api.createdWith?['license_plate'], 'ABC1D23');
    expect(api.createdWith?['current_kilometers'], 42000);
  });

  testWidgets('creating a vehicle logs vehicle_added once', (tester) async {
    final meta = _RecordingMetaEvents();
    await _pumpForm(tester, _reading(), metaAppEvents: meta);

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quilometragem atual *'),
      '42000',
    );
    final checkbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(meta.vehicleAdded, 1);
  });

  testWidgets('claiming a vehicle by CRLV-e logs vehicle_added', (
    tester,
  ) async {
    final meta = _RecordingMetaEvents();
    await _pumpForm(tester, _reading(mode: 'claim'), metaAppEvents: meta);

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(meta.vehicleAdded, 1);
  });

  testWidgets('a registered vehicle is claimed after confirming', (
    tester,
  ) async {
    final api = await _pumpForm(tester, _reading(mode: 'claim'));

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();

    expect(find.text('Este veículo já está na RevisaLog'), findsOneWidget);
    expect(find.textContaining('3 manutenções registradas'), findsOneWidget);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(api.claimedWith, _token);
    expect(find.byType(VehicleFormPage), findsNothing);
    expect(find.text('Veículo vinculado à sua conta.'), findsOneWidget);
  });

  testWidgets('startWithCrlv reads the CRLV-e as soon as the form opens',
      (tester) async {
    await _pumpForm(tester, _reading(mode: 'claim'), startWithCrlv: true);

    expect(find.text('Este veículo já está na RevisaLog'), findsOneWidget);
  });

  testWidgets('without startWithCrlv the form waits for the button',
      (tester) async {
    await _pumpForm(tester, _reading(mode: 'claim'));

    expect(find.text('Este veículo já está na RevisaLog'), findsNothing);
    expect(find.text('Cadastre com o CRLV-e'), findsOneWidget);
  });

  testWidgets('a CRLV-e that needs a power of attorney points to the site',
      (tester) async {
    final api = await _pumpForm(
        tester, _reading(mode: 'claim', ownership: 'consignment'));

    await tester.tap(find.byKey(const Key('vehicle_crlv_pick')));
    await tester.pumpAndSettle();

    expect(find.text('Termine pelo site'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(api.claimedWith, isNull);
    expect(find.text('Cadastre com o CRLV-e'), findsOneWidget);
  });

  test('CrlvReading parses the API payload', () {
    final reading = CrlvReading.fromJson(_reading(mode: 'linked'));

    expect(reading.mode, CrlvReadingMode.linked);
    expect(reading.needsPowerOfAttorney, isFalse);
    expect(reading.verificationToken, _token);
    expect(reading.engine, isNull);
    expect(reading.year, 2020);
  });
}
