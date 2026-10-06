import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';

/// Responde no nível do adapter para que o Dio real monte a Response, incluindo
/// os headers (o ETag importa aqui).
class PagedVehiclesAdapter implements HttpClientAdapter {
  PagedVehiclesAdapter({this.lastPage = 3, this.perPage = 2});

  final int lastPage;
  final int perPage;
  final List<String?> requestedPages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = options.queryParameters['page']?.toString();
    requestedPages.add(page);

    final pageNumber = int.tryParse(page ?? '1') ?? 1;
    final firstId = (pageNumber - 1) * perPage + 1;

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': [
          for (var i = 0; i < perPage; i++)
            _vehicle(firstId + i, 'PLT000${firstId + i}'),
        ],
        'meta': {
          'current_page': pageNumber,
          'last_page': lastPage,
          'per_page': perPage,
          'total': lastPage * perPage,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'etag': ['W/"page-$pageNumber"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _vehicle(int id, String plate) => {
      'id': id,
      'license_plate': plate,
      'brand': 'VW',
      'model': 'Gol',
      'year': 2020,
    };

VehicleRepository buildRepository(HttpClientAdapter adapter) {
  final apiService = ApiService(baseUrl: 'http://test/api/v1');
  apiService.dio.httpClientAdapter = adapter;

  return VehicleRepository(apiService);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reads last_page from meta and offers more', () async {
    final repository = buildRepository(PagedVehiclesAdapter());

    await repository.load();

    expect(repository.vehicles, hasLength(2));
    expect(repository.hasMore, isTrue);
  });

  test('loadMore appends the next page instead of replacing', () async {
    final adapter = PagedVehiclesAdapter();
    final repository = buildRepository(adapter);

    await repository.load();
    await repository.loadMore();

    expect(repository.vehicles.map((v) => v.id), [1, 2, 3, 4]);
    expect(adapter.requestedPages, ['1', '2']);
    expect(repository.hasMore, isTrue);
  });

  test('hasMore turns false on the last page', () async {
    final repository = buildRepository(PagedVehiclesAdapter(lastPage: 2));

    await repository.load();
    await repository.loadMore();

    expect(repository.vehicles, hasLength(4));
    expect(repository.hasMore, isFalse);
  });

  test('loadMore does nothing once there are no more pages', () async {
    final adapter = PagedVehiclesAdapter(lastPage: 1);
    final repository = buildRepository(adapter);

    await repository.load();
    await repository.loadMore();

    expect(adapter.requestedPages, ['1']);
  });

  test('a reload goes back to page 1 and replaces the list', () async {
    final adapter = PagedVehiclesAdapter();
    final repository = buildRepository(adapter);

    await repository.load();
    await repository.loadMore();
    expect(repository.vehicles, hasLength(4));

    await repository.invalidate();

    expect(repository.vehicles.map((v) => v.id), [1, 2]);
    expect(repository.hasMore, isTrue);
  });

  test('skips ids already loaded when a page overlaps', () async {
    final adapter = _OverlappingAdapter();
    final repository = buildRepository(adapter);

    await repository.load();
    await repository.loadMore();

    // A página 2 repetiu o id 2, que não deve aparecer duas vezes.
    expect(repository.vehicles.map((v) => v.id), [1, 2, 3]);
  });

  test('restores the paging state with the snapshot', () async {
    final adapter = PagedVehiclesAdapter();
    final repository = buildRepository(adapter);

    await repository.load();
    await repository.loadMore();

    // Novo repositório sobre o mesmo SharedPreferences: hidrata do snapshot e
    // o 304 do refresh não traz `meta`, então o estado tem de vir de lá.
    final restored = buildRepository(_NotModifiedAdapter());
    await restored.load();

    expect(restored.vehicles, hasLength(4));
    expect(restored.hasMore, isTrue);
  });
}

class _OverlappingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.tryParse(options.queryParameters['page']?.toString() ?? '1') ?? 1;

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': page == 1
            ? [_vehicle(1, 'PLT0001'), _vehicle(2, 'PLT0002')]
            : [_vehicle(2, 'PLT0002'), _vehicle(3, 'PLT0003')],
        'meta': {'current_page': page, 'last_page': 2},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NotModifiedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('', 304, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
