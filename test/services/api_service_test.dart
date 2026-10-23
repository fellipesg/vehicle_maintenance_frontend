import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';
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
  photoApiTests();

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
        (_) => jsonBody(200, {
          'success': true,
          'data': const {'id': 7}
        }),
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
        (_) => jsonBody(200, {
          'success': true,
          'data': const {'id': 7}
        }),
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

void photoApiTests() {
  group('fotos de manutenção e preferência do PDF', () {
    late ApiService apiService;
    late FakeHttpAdapter adapter;

    setUp(() {
      adapter = FakeHttpAdapter((_) => jsonBody(200, {'success': true}));
      apiService = ApiService(baseUrl: 'http://test/api/v1');
      apiService.dio.httpClientAdapter = adapter;
    });

    test('upload manda multipart com photo, subject, stage e item', () async {
      final dir = Directory.systemTemp.createTempSync('photo-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/frente.jpg')..writeAsBytesSync([1, 2, 3]);
      final progress = <int>[];

      await apiService.uploadMaintenancePhoto(
        maintenanceId: 5,
        filePath: file.path,
        subject: PhotoSubject.part,
        stage: PhotoStage.during,
        maintenanceItemId: 7,
        onSendProgress: (sent, total) => progress.add(sent),
      );

      final request = adapter.requests.single;
      final form = request.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};

      expect(request.method, 'POST');
      expect(request.path, '/maintenances/5/photos');
      expect(fields, {
        'subject': 'part',
        'stage': 'during',
        'maintenance_item_id': '7',
      });
      expect(form.files.single.key, 'photo');
      expect(form.files.single.value.filename, 'frente.jpg');
    });

    test('upload sem item não manda maintenance_item_id', () async {
      final dir = Directory.systemTemp.createTempSync('photo-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);

      await apiService.uploadMaintenancePhoto(
        maintenanceId: 5,
        filePath: file.path,
        subject: PhotoSubject.vehicle,
        stage: PhotoStage.before,
      );

      final form = adapter.requests.single.data as FormData;
      expect(form.fields.map((f) => f.key), ['subject', 'stage']);
    });

    test('delete usa a rota aninhada da manutenção', () async {
      await apiService.deleteMaintenancePhoto(maintenanceId: 5, photoId: 12);

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/maintenances/5/photos/12');
    });

    test('preferência do PDF manda só export_include_photos em PUT /me',
        () async {
      await apiService.updateExportIncludePhotos(true);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/me');
      expect(request.data, {'export_include_photos': true});
    });
  });
}
