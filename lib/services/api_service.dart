import 'package:dio/dio.dart';
import 'dart:io';

class ApiService {
  final Dio _dio;
  final String baseUrl;

  ApiService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // Method to set authorization token
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  // Getter for dio (for AuthService and other services)
  Dio get dio => _dio;

  // Get user's vehicles
  Future<Response> getMyVehicles({int page = 1, int perPage = 15}) async {
    return await _dio.get('/my-vehicles', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
  }

  // Vehicle endpoints
  Future<Response> getVehicles({Map<String, dynamic>? queryParams}) async {
    return await _dio.get('/vehicles', queryParameters: queryParams);
  }

  Future<Response> getVehicle(String id) async {
    return await _dio.get('/vehicles/$id');
  }

  Future<Response> searchVehicle(String identifier) async {
    return await _dio.get('/vehicles/search/$identifier');
  }

  Future<Response> createVehicle(Map<String, dynamic> data) async {
    return await _dio.post('/vehicles', data: data);
  }

  Future<Response> updateVehicle(String id, Map<String, dynamic> data) async {
    return await _dio.put('/vehicles/$id', data: data);
  }

  Future<Response> deleteVehicle(String id) async {
    return await _dio.delete('/vehicles/$id');
  }

  Future<Response> getVehicleMaintenances(
    String vehicleId, {
    int page = 1,
    int perPage = 15,
  }) async {
    return await _dio.get('/vehicles/$vehicleId/maintenances', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
  }

  Future<Response> requestVehiclePdfExport(String vehicleId) async {
    return await _dio.post('/vehicles/$vehicleId/export-pdf');
  }

  Future<Response> getVehiclePdfExportStatus(String exportId) async {
    return await _dio.get('/vehicle-pdf-exports/$exportId');
  }

  Future<Response> downloadVehiclePdfExport(String exportId) async {
    return await _dio.get(
      '/vehicle-pdf-exports/$exportId/download',
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Response> downloadFromUrl(String url) async {
    return await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
  }

  Future<Response> getVehicleTimeline(String vehicleId) async {
    return await _dio.get('/vehicles/$vehicleId/timeline');
  }

  Future<Response> getTermsOfUse() async {
    return await _dio.get('/legal/terms-of-use');
  }

  // Maintenance endpoints
  Future<Response> getMaintenances({
    Map<String, dynamic>? queryParams,
    int page = 1,
    int perPage = 15,
  }) async {
    return await _dio.get('/maintenances', queryParameters: {
      'page': page,
      'per_page': perPage,
      ...?queryParams,
    });
  }

  Future<Response> getMaintenance(String id) async {
    return await _dio.get('/maintenances/$id');
  }

  Future<Response> createMaintenance(FormData formData) async {
    return await _dio.post(
      '/maintenances',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }

  Future<Response> updateMaintenance(
      String id, Map<String, dynamic> data) async {
    return await _dio.put('/maintenances/$id', data: data);
  }

  Future<Response> deleteMaintenance(String id) async {
    return await _dio.delete('/maintenances/$id');
  }

  // Invoice endpoints
  Future<Response> uploadInvoice(FormData formData) async {
    return await _dio.post(
      '/invoices/upload',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }

  Future<Response> downloadInvoice(String id) async {
    return await _dio.get(
      '/invoices/$id/download',
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
  }

  Future<Response> deleteInvoice(String id) async {
    return await _dio.delete('/invoices/$id');
  }

  // Workshop endpoints
  Future<Response> getWorkshops({
    Map<String, dynamic>? queryParams,
    int page = 1,
    int perPage = 15,
  }) async {
    return await _dio.get('/workshops', queryParameters: {
      'page': page,
      'per_page': perPage,
      ...?queryParams,
    });
  }

  Future<Response> getWorkshop(String id) async {
    return await _dio.get('/workshops/$id');
  }

  Future<Response> createWorkshop(Map<String, dynamic> data) async {
    return await _dio.post('/workshops', data: data);
  }

  Future<Response> updateWorkshop(String id, Map<String, dynamic> data) async {
    return await _dio.put('/workshops/$id', data: data);
  }

  Future<Response> deleteWorkshop(String id) async {
    return await _dio.delete('/workshops/$id');
  }

  // Profile endpoints
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/me', data: data);
  }

  Future<Response> uploadAvatar(File file) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    return await _dio.post(
      '/me/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> uploadVehicleCover(String vehicleId, File file) async {
    final formData = FormData.fromMap({
      'cover': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    return await _dio.post(
      '/vehicles/$vehicleId/cover',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
