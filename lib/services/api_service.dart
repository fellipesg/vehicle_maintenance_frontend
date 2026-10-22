import 'package:dio/dio.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/maintenance_photo.dart';
import '../models/vehicle_lookup_result.dart';

/// Chamado quando o backend recusa o Bearer token (401) de uma rota autenticada.
typedef UnauthorizedCallback = Future<void> Function();

class ApiService {
  final Dio _dio;
  final String baseUrl;

  /// Encerra a sessão quando o token expira, é revogado ou perde a validade
  /// porque houve login em outro aparelho (o backend mantém um token `mobile`
  /// por conta). Sem isso o app fica "logado" com um token morto.
  UnauthorizedCallback? onUnauthorized;

  bool _handlingUnauthorized = false;

  /// Rotas em que 401 é a resposta normal para credencial errada — não é sessão
  /// expirada, e `/logout` já está encerrando a sessão por conta própria.
  static const Set<String> _unauthenticatedPaths = {
    '/login',
    '/register',
    '/logout',
    '/auth/',
    '/two-factor/challenge',
  };

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
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        responseHeader: false,
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        if (_isExpiredSession(error)) {
          await _notifyUnauthorized();
        }

        handler.next(error);
      },
    ));
  }

  bool _isExpiredSession(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }

    // Sem Authorization não havia sessão para expirar.
    if (_dio.options.headers['Authorization'] == null) {
      return false;
    }

    final path = error.requestOptions.path;

    return !_unauthenticatedPaths.any(path.contains);
  }

  Future<void> _notifyUnauthorized() async {
    final callback = onUnauthorized;

    // Várias requisições em paralelo podem receber 401 juntas; só a primeira
    // encerra a sessão. Depois disso o header já saiu e `_isExpiredSession`
    // passa a devolver false.
    if (callback == null || _handlingUnauthorized) {
      return;
    }

    _handlingUnauthorized = true;

    try {
      await callback();
    } finally {
      _handlingUnauthorized = false;
    }
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

  // Get user's vehicles (or all vehicles for admin)
  Future<Response<dynamic>> getMyVehicles({
    int page = 1,
    int perPage = 15,
    String? ifNoneMatch,
  }) async {
    return await _dio.get(
      '/my-vehicles',
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
      options: Options(
        validateStatus: (status) =>
            status != null && (status < 400 || status == 304),
        headers: ifNoneMatch != null ? {'If-None-Match': ifNoneMatch} : null,
      ),
    );
  }

  Future<Response<dynamic>> getAdminVehicles({
    int page = 1,
    int perPage = 50,
  }) async {
    return await _dio.get(
      '/admin/vehicles',
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
    );
  }

  // Vehicle catalog (sugestões de marca e modelo)

  /// Marcas ativas do catálogo. O backend devolve uma lista de strings.
  Future<List<String>> getCatalogBrands() async {
    final response = await _dio.get('/vehicle-catalog/brands');

    return _stringList(response.data);
  }

  /// Modelos de uma marca. O backend resolve por chave exata, então `brand`
  /// precisa ser o nome como está no catálogo — daí passarmos o valor
  /// selecionado, não o que o usuário digitou.
  Future<List<String>> getCatalogModels(String brand) async {
    final response = await _dio.get(
      '/vehicle-catalog/models',
      queryParameters: {'brand': brand},
    );

    return _stringList(response.data);
  }

  static List<String> _stringList(dynamic envelope) {
    if (envelope is! Map) {
      return const [];
    }

    final data = envelope['data'];
    if (data is! List) {
      return const [];
    }

    return data
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Vehicle endpoints
  Future<Response> getVehicle(String id) async {
    return await _dio.get('/vehicles/$id');
  }

  Future<VehicleLookupResult> searchVehicle(String identifier) async {
    final response = await _dio.get('/vehicles/search/$identifier');
    return VehicleLookupResult.fromApi(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Response> createVehicle(Map<String, dynamic> data) async {
    return await _dio.post('/vehicles', data: data);
  }

  Future<Response> updateVehicle(String id, Map<String, dynamic> data) async {
    return await _dio.put('/vehicles/$id', data: data);
  }

  /// Reivindica um veículo já cadastrado. A placa e o RENAVAM são a prova de
  /// posse e o backend os confere contra o documento do veículo
  /// (`VehicleOwnershipService::documentMatchesVehicle`), respondendo 422 com
  /// uma mensagem genérica quando não batem.
  Future<Response> linkVehicle(
    String id, {
    required String licensePlate,
    required String renavam,
    DateTime? purchaseDate,
  }) async {
    return await _dio.post(
      '/vehicles/$id/link',
      data: {
        'license_plate': licensePlate,
        'renavam': renavam,
        if (purchaseDate != null)
          'purchase_date': purchaseDate.toIso8601String().split('T').first,
      },
    );
  }

  Future<Response> deleteVehicle(String id) async {
    return await _dio.delete('/vehicles/$id');
  }

  Future<Response> getVehicleMaintenances(
    String vehicleId, {
    int page = 1,
    int perPage = 15,
    bool? verified,
  }) async {
    return await _dio
        .get('/vehicles/$vehicleId/maintenances', queryParameters: {
      'page': page,
      'per_page': perPage,
      if (verified != null) 'verified': verified ? 1 : 0,
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

  /// Anexa uma nota a uma manutenção já criada. Até aqui a nota só entrava no
  /// momento de registrar o serviço: quem esquecesse não tinha como voltar.
  ///
  /// `invoice_type` é `general` — nota da OS inteira. O vínculo com um item
  /// específico (`item` + `maintenance_item_id`) existe na API, mas o app ainda
  /// não tem onde escolher o item.
  Future<Response> uploadInvoice({
    required int maintenanceId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'maintenance_id': maintenanceId,
      'invoice_type': 'general',
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    return await _dio.post(
      '/invoices/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
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

  // Maintenance photo endpoints

  /// Envia uma foto de antes/durante/depois. Campos do multipart (ver
  /// `StoreMaintenancePhotoRequest`): `photo` (jpg/jpeg/png/webp, até 5 MB),
  /// `subject` (`vehicle|part`), `stage` (`before|during|after`) e
  /// `maintenance_item_id` opcional. O backend aceita no máximo 4 fotos por
  /// grupo (assunto + momento) e responde 422 com a mensagem quando passa.
  Future<Response> uploadMaintenancePhoto({
    required int maintenanceId,
    required String filePath,
    required PhotoSubject subject,
    required PhotoStage stage,
    int? maintenanceItemId,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'subject': subject.apiValue,
      'stage': stage.apiValue,
      if (maintenanceItemId != null) 'maintenance_item_id': maintenanceItemId,
      'photo': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    return await _dio.post(
      '/maintenances/$maintenanceId/photos',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        // Uploads de câmera em rede móvel passam fácil dos 30 s do padrão.
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  Future<Response> deleteMaintenancePhoto({
    required int maintenanceId,
    required int photoId,
  }) async {
    return await _dio.delete('/maintenances/$maintenanceId/photos/$photoId');
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

  Future<Response> createWorkshop(FormData formData) async {
    return await _dio.post(
      '/workshops',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> updateWorkshop(String id, FormData formData) async {
    // POST + `_method=PUT`: o PHP só popula $_POST/$_FILES em POST, então um PUT
    // multipart chega ao Laravel sem campo nenhum — a validação é toda
    // `sometimes`, passa, e a resposta é 200 sem ter salvo nada.
    if (!formData.fields.any((field) => field.key == '_method')) {
      formData.fields.add(const MapEntry('_method', 'PUT'));
    }

    return await _dio.post(
      '/workshops/$id',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> getWarrantyTemplates(
    String workshopId, {
    int page = 1,
    int perPage = 100,
  }) async {
    return await _dio.get(
      '/workshops/$workshopId/warranty-templates',
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
    );
  }

  // Registros de oficina em carros sem dono

  /// Usuário logado. Traz `pending_workshop_records_count` (ver
  /// `WorkshopRecordsInbox`, único lugar que lê o campo).
  Future<Response> getMe() async {
    return await _dio.get('/me');
  }

  /// `status`: `pending` (padrão do backend) ou `all`.
  Future<Response> getWorkshopRecords({String status = 'pending'}) async {
    return await _dio.get(
      '/me/workshop-records',
      queryParameters: {'status': status},
    );
  }

  Future<Response> submitOwnerDecision(
    int maintenanceId, {
    required bool link,
    required bool attachFiles,
    required bool hideFromPublic,
  }) async {
    return await _dio.post(
      '/maintenances/$maintenanceId/owner-decision',
      data: {
        'link': link,
        'attach_files': attachFiles,
        'hide_from_public': hideFromPublic,
      },
    );
  }

  /// Busca por chassi (17 caracteres). Só oficinas.
  Future<Response> lookupWorkshopVehicle(String chassis) async {
    return await _dio.get(
      '/workshop/vehicles/lookup',
      queryParameters: {'chassis': chassis},
    );
  }

  /// Cria o carro só com chassi, marca, modelo e ano. 409 se o chassi existe.
  Future<Response> createWorkshopVehicle({
    required String chassis,
    required String brand,
    required String model,
    required int year,
  }) async {
    return await _dio.post(
      '/workshop/vehicles',
      data: {
        'chassis': chassis,
        'brand': brand,
        'model': model,
        'year': year,
      },
    );
  }

  Future<Response> sendEmailInvite(int maintenanceId, String email) async {
    return await _dio.post(
      '/maintenances/$maintenanceId/invites/email',
      data: {'email': email},
    );
  }

  Future<Response> sendWhatsappInvite(int maintenanceId, String phone) async {
    return await _dio.post(
      '/maintenances/$maintenanceId/invites/whatsapp',
      data: {'phone': phone},
    );
  }

  // Profile endpoints
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/me', data: data);
  }

  /// Preferência de incluir as fotos das manutenções no PDF do histórico.
  /// Manda só este campo: `PUT /me` valida tudo como `sometimes`/`nullable`.
  Future<Response> updateExportIncludePhotos(bool value) async {
    return await _dio.put('/me', data: {'export_include_photos': value});
  }

  Future<Response> deleteAccount() async {
    return await _dio.delete('/me');
  }

  // Password endpoints

  /// Pede o link de redefinição. A resposta é a mesma exista ou não a conta, de
  /// propósito, para não revelar quais e-mails estão cadastrados.
  Future<Response> requestPasswordReset(String email) async {
    return await _dio.post('/password/forgot', data: {'email': email});
  }

  /// Troca a senha do usuário logado. Derruba os outros aparelhos no servidor;
  /// o token deste segue valendo.
  Future<Response> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    return await _dio.put(
      '/me/password',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  // Two-factor endpoints

  /// Primeiro passo: devolve `secret` e `otpauth_uri` para cadastrar no
  /// autenticador. A 2FA só passa a valer depois do confirm.
  Future<Response> enableTwoFactor() async {
    return await _dio.post('/two-factor/enable');
  }

  Future<Response> confirmTwoFactor(String code) async {
    return await _dio.post('/two-factor/confirm', data: {'code': code});
  }

  Future<Response> disableTwoFactor({
    required String password,
    required String code,
  }) async {
    return await _dio.post(
      '/two-factor/disable',
      data: {'password': password, 'code': code},
    );
  }

  Future<Response> regenerateTwoFactorRecoveryCodes({
    required String password,
    required String code,
  }) async {
    return await _dio.post(
      '/two-factor/recovery-codes',
      data: {'password': password, 'code': code},
    );
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

  Future<Response> uploadVehicleCover(
    String vehicleId, {
    File? landscape,
    File? portrait,
  }) async {
    final fields = <String, dynamic>{};

    if (landscape != null) {
      fields['cover'] = await MultipartFile.fromFile(
        landscape.path,
        filename: landscape.path.split('/').last,
      );
    }

    if (portrait != null) {
      fields['cover_portrait'] = await MultipartFile.fromFile(
        portrait.path,
        filename: portrait.path.split('/').last,
      );
    }

    final formData = FormData.fromMap(fields);

    return await _dio.post(
      '/vehicles/$vehicleId/cover',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
