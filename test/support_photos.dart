import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/maintenance_photo.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/services/maintenance_photo_picker.dart';

Map<String, dynamic> photoJson({
  int id = 1,
  int maintenanceId = 5,
  String subject = 'vehicle',
  String stage = 'before',
  int? itemId,
  int sort = 1,
  int? width = 2000,
  int? height = 1000,
  String? color = '#5a6b7c',
}) {
  return {
    'id': id,
    'maintenance_id': maintenanceId,
    'maintenance_item_id': itemId,
    'subject': subject,
    'stage': stage,
    'original_name': 'foto-$id.jpg',
    'sort': sort,
    'created_by': 3,
    'created_at': '2026-10-01T10:00:00Z',
    'width': width,
    'height': height,
    'dominant_color': color,
    'processed': true,
    'variants': {
      'thumb': 'https://cdn.example/t/$id?sig=a',
      'display': 'https://cdn.example/d/$id?sig=a',
      'master': 'https://cdn.example/m/$id?sig=a',
    },
    'expires_at': '2026-10-01T10:10:00Z',
    'url': 'http://test/api/v1/maintenance-photos/$id',
  };
}

Map<String, dynamic> maintenanceJson({
  bool verified = false,
  int? workshopId,
  List<Map<String, dynamic>> photos = const [],
  bool photosLocked = false,
  int? photosCount,
  List<Map<String, dynamic>> items = const [],
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
    'invoices': const [],
    'items': items,
    'photos': photos,
    'photos_count': photosCount ?? photos.length,
    'photos_locked': photosLocked,
  };
}

Map<String, dynamic> itemJson(int id, String name) => {
      'id': id,
      'maintenance_id': 5,
      'name': name,
      'quantity': 1,
      'unit_price': '10.00',
      'total_price': '10.00',
    };

DioException dioError(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/x');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

class FakeTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}

class FakeFcm extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

/// Conta logada em memória, sem disco nem rede.
class FakeAuth extends AuthService {
  // ignore: use_super_parameters
  FakeAuth(ApiService api, Map<String, dynamic> user)
      : _user = Map.of(user),
        super(api, tokenStorage: FakeTokenStorage(), fcmService: FakeFcm());

  Map<String, dynamic> _user;
  @override
  Map<String, dynamic>? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {
    _user = Map.of(user);
  }

  int refreshCount = 0;

  /// Relê o `/me` da API de teste; um `/me` vazio mantém o usuário atual.
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    refreshCount++;
    final response = await apiService.getMe();
    final data = response.data['data'];
    if (data is Map && data.isNotEmpty) {
      await saveUser(Map<String, dynamic>.from(data));
    }

    return _user;
  }
}

class FakePicker extends MaintenancePhotoPicker {
  FakePicker(this.paths);

  List<String> paths;
  final List<PhotoSource> requested = [];

  @override
  Future<List<String>> pick(PhotoSource source) async {
    requested.add(source);

    return paths;
  }
}

/// API de manutenção com fotos, usuário (`/me`) e upload controláveis.
class FakePhotosApi extends ApiService {
  FakePhotosApi({Map<String, dynamic>? maintenance, this.me})
      : maintenance = maintenance ?? maintenanceJson(),
        super(baseUrl: 'http://test');

  Map<String, dynamic> maintenance;
  Map<String, dynamic>? me;

  int getMaintenanceCalls = 0;
  int meCalls = 0;
  final List<bool> exportPreferenceWrites = [];
  Object? exportPreferenceError;

  final List<Map<String, dynamic>> uploads = [];

  /// Resolve cada envio; lance para simular falha. `sent`/`total` alimentam o
  /// progresso.
  Future<void> Function(String path, void Function(int, int)? onProgress)?
      uploadHandler;

  final List<int> deletedPhotoIds = [];
  Object? deleteError;

  @override
  Future<Response> getMaintenance(String id) async {
    getMaintenanceCalls++;

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
  Future<Response> getMe() async {
    meCalls++;

    return Response(
      requestOptions: RequestOptions(path: '/me'),
      data: {'success': true, 'data': me ?? <String, dynamic>{}},
      statusCode: 200,
    );
  }

  @override
  Future<Response> updateExportIncludePhotos(bool value) async {
    if (exportPreferenceError != null) {
      throw exportPreferenceError!;
    }
    exportPreferenceWrites.add(value);

    return Response(
      requestOptions: RequestOptions(path: '/me'),
      data: {'success': true},
      statusCode: 200,
    );
  }

  @override
  Future<Response> uploadMaintenancePhoto({
    required int maintenanceId,
    required String filePath,
    required PhotoSubject subject,
    required PhotoStage stage,
    int? maintenanceItemId,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploads.add({
      'maintenance_id': maintenanceId,
      'path': filePath,
      'subject': subject.apiValue,
      'stage': stage.apiValue,
      'item': maintenanceItemId,
    });

    await uploadHandler?.call(filePath, onSendProgress);

    return Response(
      requestOptions:
          RequestOptions(path: '/maintenances/$maintenanceId/photos'),
      data: {'success': true},
      statusCode: 201,
    );
  }

  @override
  Future<Response> deleteMaintenancePhoto({
    required int maintenanceId,
    required int photoId,
  }) async {
    if (deleteError != null) {
      throw deleteError!;
    }
    deletedPhotoIds.add(photoId);
    maintenance = {
      ...maintenance,
      'photos': [
        for (final photo in maintenance['photos'] as List)
          if ((photo as Map)['id'] != photoId) photo,
      ],
    };

    return Response(
      requestOptions: RequestOptions(path: '/x'),
      data: {'success': true},
      statusCode: 200,
    );
  }
}

Widget providers(
  FakePhotosApi api,
  FakeAuth auth, {
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      Provider<AuthService>.value(value: auth),
    ],
    child: MaterialApp(home: child),
  );
}

/// `features` do usuário (`/me`) com o recurso de fotos liberado.
const Map<String, dynamic> photosFeatureOn = {'maintenance_photos': true};
