import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';

class TestApiService extends ApiService {
  TestApiService(this.handler) : super(baseUrl: 'http://localhost/api/v1');

  final Future<Response<dynamic>> Function({
    int page,
    int perPage,
    String? ifNoneMatch,
  }) handler;

  int callCount = 0;

  @override
  Future<Response<dynamic>> getMyVehicles({
    int page = 1,
    int perPage = 15,
    String? ifNoneMatch,
  }) async {
    callCount++;
    return handler(page: page, perPage: perPage, ifNoneMatch: ifNoneMatch);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('snapshot populates list before network response is applied', () async {
    final api = TestApiService(({
      page = 1,
      perPage = 15,
      ifNoneMatch,
    }) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Response(
        requestOptions: RequestOptions(path: '/my-vehicles'),
        statusCode: 200,
        data: {
          'success': true,
          'data': [
            {
              'id': 2,
              'license_plate': 'NEW1234',
              'brand': 'Honda',
              'model': 'Civic',
              'year': 2021,
            },
          ],
        },
        headers: Headers.fromMap({
          'etag': ['W/"new"']
        }),
      );
    });

    final repository = VehicleRepository(api);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vehicles.snapshot.v1',
      '{"savedAt":"2026-01-01T00:00:00.000Z","etag":"W/\\"old\\"","vehicles":[{"id":1,"license_plate":"OLD1234","brand":"Toyota","model":"Corolla","year":2020}]}',
    );

    var sawCachedFirst = false;
    repository.addListener(() {
      if (repository.vehicles.isNotEmpty &&
          repository.vehicles.first.licensePlate == 'OLD1234' &&
          api.callCount == 0) {
        sawCachedFirst = true;
      }
    });

    await repository.load();

    expect(sawCachedFirst, isTrue);
    expect(repository.vehicles.first.licensePlate, 'NEW1234');
    expect(api.callCount, 1);
  });

  test('304 keeps cached vehicles', () async {
    final api = TestApiService(({
      page = 1,
      perPage = 15,
      ifNoneMatch,
    }) async {
      return Response(
        requestOptions: RequestOptions(path: '/my-vehicles'),
        statusCode: 304,
      );
    });

    final repository = VehicleRepository(api);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vehicles.snapshot.v1',
      '{"savedAt":"2026-01-01T00:00:00.000Z","etag":"W/\\"cached\\"","vehicles":[{"id":1,"license_plate":"ABC1234","brand":"Toyota","model":"Corolla","year":2020}]}',
    );

    await repository.load();

    expect(repository.vehicles.first.licensePlate, 'ABC1234');
    expect(api.callCount, 1);
  });

  test('clear removes snapshot', () async {
    final api = TestApiService(({
      page = 1,
      perPage = 15,
      ifNoneMatch,
    }) async {
      return Response(
        requestOptions: RequestOptions(path: '/my-vehicles'),
        statusCode: 200,
        data: {
          'success': true,
          'data': [],
        },
      );
    });

    final repository = VehicleRepository(api);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vehicles.snapshot.v1',
      '{"savedAt":"2026-01-01T00:00:00.000Z","vehicles":[]}',
    );

    await repository.clear();

    expect(prefs.getString('vehicles.snapshot.v1'), isNull);
    expect(repository.vehicles, isEmpty);
  });
}
