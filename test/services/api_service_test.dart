import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/api_service.dart';

/// Responde no nível do adapter para que o fluxo real do Dio rode — é ele que
/// transforma o 401 em `DioException` e dispara os interceptors de erro.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('expired session handling', () {
    late ApiService apiService;
    late FakeHttpAdapter adapter;
    late int unauthorizedCalls;

    setUp(() {
      unauthorizedCalls = 0;
      adapter = FakeHttpAdapter(
        (_) => jsonBody(401, {'success': false, 'message': 'Unauthenticated.'}),
      );
      apiService = ApiService(baseUrl: 'http://test/api/v1');
      apiService.dio.httpClientAdapter = adapter;
      apiService.onUnauthorized = () async => unauthorizedCalls++;
    });

    test('401 on an authenticated route ends the session', () async {
      apiService.setAuthToken('expired-token');

      await expectLater(
        apiService.getMyVehicles(),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCalls, 1);
    });

    test('401 without a token is not an expired session', () async {
      await expectLater(
        apiService.getMyVehicles(),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCalls, 0);
    });

    test('401 on /login is wrong credentials, not an expired session',
        () async {
      apiService.setAuthToken('some-token');

      await expectLater(
        apiService.dio.post('/login', data: const {'email': 'a@b.c'}),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCalls, 0);
    });

    test('401 on /logout does not re-enter the logout flow', () async {
      apiService.setAuthToken('expired-token');

      await expectLater(
        apiService.dio.post('/logout'),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCalls, 0);
    });

    test('parallel 401s end the session only once', () async {
      apiService.setAuthToken('expired-token');
      // Encerrar a sessão limpa o header, como o AuthService faz.
      apiService.onUnauthorized = () async {
        unauthorizedCalls++;
        apiService.setAuthToken(null);
      };

      final results = await Future.wait([
        apiService.getMyVehicles().then((_) => null).catchError((_) => null),
        apiService.getVehicle('1').then((_) => null).catchError((_) => null),
        apiService.getMaintenances().then((_) => null).catchError((_) => null),
      ]);

      expect(results, hasLength(3));
      expect(unauthorizedCalls, 1);
    });

    test('a successful response leaves the session alone', () async {
      adapter = FakeHttpAdapter(
        (_) => jsonBody(200, {'success': true, 'data': const []}),
      );
      apiService.dio.httpClientAdapter = adapter;
      apiService.setAuthToken('good-token');

      final response = await apiService.getMyVehicles();

      expect(response.statusCode, 200);
      expect(unauthorizedCalls, 0);
    });
  });

  group('updateWorkshop multipart', () {
    test('spoofs PUT over POST so PHP parses the body', () async {
      final adapter = FakeHttpAdapter(
        (_) => jsonBody(200, {'success': true, 'data': const {'id': 7}}),
      );
      final apiService = ApiService(baseUrl: 'http://test/api/v1');
      apiService.dio.httpClientAdapter = adapter;

      final formData = FormData.fromMap({'name': 'Oficina do Zé'});

      await apiService.updateWorkshop('7', formData);

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/workshops/7');
      expect(
        formData.fields,
        contains(const MapEntry('_method', 'PUT')),
      );
    });

    test('does not add _method twice', () async {
      final adapter = FakeHttpAdapter(
        (_) => jsonBody(200, {'success': true, 'data': const {'id': 7}}),
      );
      final apiService = ApiService(baseUrl: 'http://test/api/v1');
      apiService.dio.httpClientAdapter = adapter;

      final formData = FormData.fromMap({'name': 'Oficina do Zé'});
      formData.fields.add(const MapEntry('_method', 'PUT'));

      await apiService.updateWorkshop('7', formData);

      expect(
        formData.fields.where((field) => field.key == '_method'),
        hasLength(1),
      );
    });
  });
}
