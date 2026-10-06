import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/models/vehicle_lookup_result.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_link_page.dart';

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
      data: {'success': true, 'data': const {'id': 42}},
      statusCode: 200,
    );
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

Widget _wrap(ApiService apiService) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<VehicleRepository>(
        create: (_) => VehicleRepository(apiService),
      ),
    ],
    child: const MaterialApp(home: VehicleLinkPage()),
  );
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

  testWidgets('rejects a RENAVAM that is not 11 digits', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(_wrap(api));

    await _fillDocument(tester, renavam: '123');
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pump();

    expect(find.text('RENAVAM deve ter 11 dígitos'), findsOneWidget);
    expect(api.searchedIdentifier, isNull);
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

  testWidgets('explains a vehicle that belongs to another account',
      (tester) async {
    final api = _FakeApiService()
      ..searchResult = VehicleLookupResult(
        vehicle: _vehicle(),
        matchedBy: VehicleLookupResult.matchCurrentPlate,
      )
      ..linkError = _dioError(403, {'success': false});

    await tester.pumpWidget(_wrap(api));
    await _fillDocument(tester);
    await tester.tap(find.byKey(const Key('link_search_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('link_confirm_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsOneWidget,
    );
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
}
