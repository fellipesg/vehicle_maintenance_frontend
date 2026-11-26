import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/models/vehicle_lookup_result.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/meta_app_events.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_link_page.dart';

class _RecordingMetaEvents implements MetaAppEvents {
  int vehicleAdded = 0;

  @override
  Future<void> logVehicleAdded() async => vehicleAdded++;

  @override
  Future<void> logCompleteRegistration() async {}
}

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'http://test');

  VehicleLookupResult? searchResult;
  DioException? searchError;
  Object? linkError;

  String? searchedIdentifier;
  String? linkedId;
  String? sentPlate;
  String? sentRenavam;

  @override
  Future<VehicleLookupResult> searchVehicle(String identifier) async {
    searchedIdentifier = identifier;

    if (searchError != null) {
      throw searchError!;
    }

    return searchResult!;
  }

  @override
  Future<Response> linkVehicle(
    String id, {
    required String licensePlate,
    required String renavam,
    DateTime? purchaseDate,
  }) async {
    linkedId = id;
    sentPlate = licensePlate;
    sentRenavam = renavam;

    if (linkError != null) {
      throw linkError!;
    }

    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id/link'),
      data: {
        'success': true,
        'data': const {'id': 42}
      },
      statusCode: 200,
    );
  }

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

  /// O CRLV-e da compradora: o veículo já existe e o documento está no CPF dela.
  @override
  Future<Response<dynamic>> readCrlv(String filePath) async =>
      _ok('/vehicles/crlv', {
        'mode': 'claim',
        'ownership': 'owner',
        'crlv_verification_token': 'f00dcafe',
        'expires_in_minutes': 30,
        'vehicle': {
          'license_plate': 'ABC1D23',
          'renavam': '12345678901',
          'brand': 'VW',
          'model': 'Gol',
          'year': 2020,
          'chassis': '9BWZZZ377VT004251',
          'brand_matched': true,
          'model_matched': true,
        },
        'existing_vehicle': {
          'id': 42,
          'brand': 'VW',
          'model': 'Gol',
          'year': 2020,
          'maintenances_count': 7,
        },
      });

  @override
  Future<Response<dynamic>> claimVehicleWithCrlv(String token) async {
    claimedWith = token;
    return _ok('/vehicles/crlv/claim', {
      'vehicle': {'id': 42},
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
      data: const {'success': true, 'data': []},
      statusCode: 200,
    );
  }
}

DioException _dioError(int statusCode, Map<String, dynamic>? body) {
  final options = RequestOptions(path: '/vehicles/42/link');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

Vehicle _vehicle() => Vehicle(
      id: 42,
      licensePlate: 'ABC1D23',
      renavam: '12345678901',
      brand: 'VW',
      model: 'Gol',
      year: 2020,
      maintenancesCount: 7,
      verifiedMaintenancesCount: 3,
    );

Widget _wrap(
  ApiService apiService, {
  CrlvPdfPicker? pickCrlvPdf,
  MetaAppEvents metaAppEvents = const MetaAppEvents(),
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<VehicleRepository>(
        create: (_) => VehicleRepository(apiService),
      ),
    ],
    child: MaterialApp(
      home: VehicleLinkPage(
        pickCrlvPdf: pickCrlvPdf,
        metaAppEvents: metaAppEvents,
      ),
    ),
  );
}

/// A tela de vínculo aberta a partir de uma tela anterior, como no app, para
/// que o cadastro aberto por "Enviar CRLV-e" tenha para onde voltar.
Future<void> _pumpFromHome(
  WidgetTester tester,
  ApiService apiService, {
  required CrlvPdfPicker pickCrlvPdf,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<VehicleRepository>(
          create: (_) => VehicleRepository(apiService),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VehicleLinkPage(pickCrlvPdf: pickCrlvPdf),
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
}

Future<void> _searchAndLink(WidgetTester tester) async {
  await _fillDocument(tester);
  await tester.tap(find.byKey(const Key('link_search_button')));
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const Key('link_confirm_button')));
  await tester.tap(find.byKey(const Key('link_confirm_button')));
  await tester.pumpAndSettle();
}

Future<void> _fillDocument(
  WidgetTester tester, {
  String plate = 'ABC1D23',
  String renavam = '12345678901',
}) async {
  await tester.enterText(find.byKey(const Key('link_plate_field')), plate);
  await tester.enterText(find.byKey(const Key('link_renavam_field')), renavam);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('requires both document fields before searching', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(_wrap(api));

    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pump();

    expect(find.text('Informe a placa do documento'), findsOneWidget);
    expect(find.text('Informe o RENAVAM do documento'), findsOneWidget);
    expect(api.searchedIdentifier, isNull);
  });

  testWidgets('rejects a RENAVAM outside 9 to 11 digits', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(_wrap(api));

    await _fillDocument(tester, renavam: '123');
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pump();

    expect(find.text('RENAVAM deve ter de 9 a 11 dígitos'), findsOneWidget);
    expect(api.searchedIdentifier, isNull);
  });

  testWidgets('rejects RENAVAM of 8 digits and accepts 9, 10 and 11',
      (tester) async {
    for (final entry in {
      '12345678': false,
      '123456789': true,
      '1234567890': true,
      '12345678901': true,
    }.entries) {
      final api = _FakeApiService();
      await tester.pumpWidget(_wrap(api));

      await _fillDocument(tester, renavam: entry.key);
      await tester.tap(find.byKey(const Key('link_search_button')));
      await tester.pump();

      expect(
        find.text('RENAVAM deve ter de 9 a 11 dígitos'),
        entry.value ? findsNothing : findsOneWidget,
        reason: entry.key,
      );
    }
  });

  testWidgets('limits RENAVAM input to 11 digits', (tester) async {
    await tester.pumpWidget(_wrap(_FakeApiService()));

    await _fillDocument(tester, renavam: '123456789012');

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('link_renavam_field')),
    );
    expect(field.controller!.text, '12345678901');
  });

  testWidgets('shows the vehicle found, without echoing the proof fields',
      (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      );

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    expect(api.searchedIdentifier, 'ABC1D23');
    expect(find.byKey(const Key('link_found_card')), findsOneWidget);
    expect(find.text('VW Gol'), findsOneWidget);
    expect(find.text('7 manutenção(ões) · 3 verificada(s)'), findsOneWidget);

    // A ficha não repete o RENAVAM nem o chassi: mostrar o valor esperado
    // tornaria a conferência com o documento inútil. (O campo digitado pelo
    // usuário fica fora do card, por isso a busca é restrita a ele.)
    expect(
      find.descendant(
        of: find.byKey(const Key('link_found_card')),
        matching: find.textContaining('12345678901'),
      ),
      findsNothing,
    );
  });

  testWidgets('explains a plate that is not in the base', (tester) async {
    final api = _FakeApiService()..searchError = _dioError(404, null);

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum veículo encontrado'), findsOneWidget);
    expect(find.byKey(const Key('link_confirm_button')), findsNothing);
  });

  testWidgets('sends the typed plate and RENAVAM as the proof', (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      );

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('link_confirm_button')));
    await tester.pump();

    expect(api.linkedId, '42');
    expect(api.sentPlate, 'ABC1D23');
    expect(api.sentRenavam, '12345678901');
  });

  testWidgets('surfaces the backend message when the document does not match',
      (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(422, {
        'success': false,
        'message': 'The given data was invalid.',
        'errors': {
          'license_plate': [
            'A placa e o RENAVAM informados não conferem com o veículo.',
          ],
        },
      });

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('link_confirm_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('A placa e o RENAVAM informados não conferem com o veículo.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a vehicle that belongs to another account points to the CRLV-e '
      'instead of a bare 403', (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(403, {'success': false});

    await tester.pumpWidget(_wrap(api));
    await _searchAndLink(tester);

    expect(find.byKey(const Key('link_other_account_card')), findsOneWidget);
    expect(find.text('Este veículo está em outra conta'), findsOneWidget);
    expect(find.byKey(const Key('link_send_crlv_button')), findsOneWidget);
    expect(find.byKey(const Key('link_confirm_button')), findsNothing);
    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsNothing,
    );
  });

  testWidgets('editing the plate after a 403 starts over', (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(403, {'success': false});

    await tester.pumpWidget(_wrap(api));
    await _searchAndLink(tester);

    await tester.enterText(
      find.byKey(const Key('link_plate_field')),
      'XYZ9Z99',
    );
    await tester.pump();

    expect(find.byKey(const Key('link_other_account_card')), findsNothing);
    expect(find.byKey(const Key('link_search_button')), findsOneWidget);
  });

  testWidgets(
      'the buyer sends the CRLV-e from the 403 and the vehicle comes to '
      'her account', (tester) async {
    var pickerCalls = 0;
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(403, {'success': false});

    await _pumpFromHome(
      tester,
      api,
      pickCrlvPdf: () async {
        pickerCalls++;
        return '/tmp/CRLV-e.pdf';
      },
    );
    await _searchAndLink(tester);

    await tester.ensureVisible(find.byKey(const Key('link_send_crlv_button')));
    await tester.tap(find.byKey(const Key('link_send_crlv_button')));
    await tester.pumpAndSettle();

    // O cadastro abre já pedindo o CRLV-e, sem um segundo toque.
    expect(pickerCalls, 1);
    expect(find.byType(VehicleLinkPage), findsNothing);
    expect(find.text('Este veículo já está na RevisaLog'), findsOneWidget);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    expect(api.claimedWith, 'f00dcafe');
    expect(find.byType(VehicleFormPage), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
    expect(find.text('Veículo vinculado à sua conta.'), findsOneWidget);
  });

  testWidgets('editing the plate drops the result of the previous search',
      (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      );

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('link_found_card')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('link_plate_field')),
      'XYZ9Z99',
    );
    await tester.pump();

    expect(find.byKey(const Key('link_found_card')), findsNothing);
    expect(find.byKey(const Key('link_search_button')), findsOneWidget);
  });

  testWidgets('a successful link logs vehicle_added once', (tester) async {
    final meta = _RecordingMetaEvents();
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      );

    await tester.pumpWidget(_wrap(api, metaAppEvents: meta));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link_confirm_button')));
    await tester.pumpAndSettle();

    expect(meta.vehicleAdded, 1);
  });

  testWidgets('a failed link does not log vehicle_added', (tester) async {
    final meta = _RecordingMetaEvents();
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(403, {'success': false});

    await tester.pumpWidget(_wrap(api, metaAppEvents: meta));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link_confirm_button')));
    await tester.pumpAndSettle();

    expect(meta.vehicleAdded, 0);
  });
}
