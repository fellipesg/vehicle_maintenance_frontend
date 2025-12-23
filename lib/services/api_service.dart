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
  Future<Response> getMyVehicles() async {
    return await _dio.get('/my-vehicles');
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

  Future<Response> getVehicleMaintenances(String vehicleId) async {
    return await _dio.get('/vehicles/$vehicleId/maintenances');
  }

  Future<Response> exportVehiclePdf(String vehicleId) async {
    return await _dio.get('/vehicles/$vehicleId/export-pdf');
  }

  // Maintenance endpoints
  Future<Response> getMaintenances({Map<String, dynamic>? queryParams}) async {
    return await _dio.get('/maintenances', queryParameters: queryParams);
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
  Future<Response> getWorkshops({Map<String, dynamic>? queryParams}) async {
    return await _dio.get('/workshops', queryParameters: queryParams);
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
}
