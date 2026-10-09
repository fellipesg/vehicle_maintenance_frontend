import 'package:dio/dio.dart';
import 'package:vehicle_maintenance/services/api_service.dart';

Response<dynamic> okResponse(String path, dynamic data) => Response(
      requestOptions: RequestOptions(path: path),
      data: data,
      statusCode: 200,
    );

DioException dioFailure(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/x');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

Map<String, dynamic> recordJson({
  int id = 1,
  String ownerStatus = 'pending',
  String attachmentsStatus = 'pending',
  bool canAccept = true,
  bool hidden = false,
}) =>
    {
      'id': id,
      'vehicle': {
        'id': 9,
        'brand': 'Fiat',
        'model': 'Uno',
        'year': 2012,
        'chassis_masked': '9BD*********1234',
      },
      'workshop': {'id': 3, 'name': 'Oficina Central'},
      'maintenance_date': '2026-09-01',
      'kilometers': 45000,
      'service_category': 'mechanical',
      'maintenance_type': 'preventive',
      'items': [
        {'name': 'Óleo', 'quantity': 1},
      ],
      'verification_code': 'ABC123',
      'attachments': {'invoices': 2, 'photos': 1},
      'owner_status': ownerStatus,
      'attachments_status': attachmentsStatus,
      'hidden_from_public': hidden,
      'can_accept_attachments': canAccept,
    };

class FakeWorkshopApi extends ApiService {
  FakeWorkshopApi() : super(baseUrl: 'http://test');

  List<Map<String, dynamic>> records = [];
  String? requestedStatus;
  Object? decisionError;
  Map<String, dynamic>? decisionResult;
  Map<String, dynamic>? sentDecision;
  int meCount = 0;

  Object? lookupError;
  Map<String, dynamic> lookupBody = {
    'success': true,
    'data': {'found': false, 'vehicle': null},
  };
  Map<String, dynamic>? createdPayload;
  Object? createError;
  Map<String, dynamic> createBody = {
    'success': true,
    'data': {
      'id': 77,
      'brand': 'Fiat',
      'model': 'Uno',
      'year': 2012,
      'has_owner': false,
    },
  };

  Object? whatsappError;
  Object? emailError;
  String? whatsappPhone;
  String? emailSent;

  @override
  Future<Response> getMe() async => okResponse('/me', {
        'success': true,
        'data': {'id': 1, 'pending_workshop_records_count': meCount},
      });

  @override
  Future<Response> getWorkshopRecords({String status = 'pending'}) async {
    requestedStatus = status;
    return okResponse(
        '/me/workshop-records', {'success': true, 'data': records});
  }

  @override
  Future<Response> submitOwnerDecision(
    int maintenanceId, {
    required bool link,
    required bool attachFiles,
    required bool hideFromPublic,
  }) async {
    sentDecision = {
      'link': link,
      'attach_files': attachFiles,
      'hide_from_public': hideFromPublic,
    };
    if (decisionError != null) {
      throw decisionError!;
    }
    return okResponse('/x', {
      'success': true,
      'data': decisionResult ??
          recordJson(
            id: maintenanceId,
            ownerStatus: link ? 'linked' : 'declined',
            hidden: hideFromPublic,
          ),
    });
  }

  @override
  Future<Response> lookupWorkshopVehicle(String chassis) async {
    if (lookupError != null) {
      throw lookupError!;
    }
    return okResponse('/lookup', lookupBody);
  }

  @override
  Future<Response> createWorkshopVehicle({
    required String chassis,
    required String brand,
    required String model,
    required int year,
  }) async {
    createdPayload = {
      'chassis': chassis,
      'brand': brand,
      'model': model,
      'year': year,
    };
    if (createError != null) {
      throw createError!;
    }
    return okResponse('/workshop/vehicles', createBody);
  }

  @override
  Future<Response> sendWhatsappInvite(int maintenanceId, String phone) async {
    whatsappPhone = phone;
    if (whatsappError != null) {
      throw whatsappError!;
    }
    return okResponse('/x', {
      'success': true,
      'data': {
        'url': 'https://wa.me/5511999998888?text=oi',
        'whatsapp_invited_at': '2026-10-09T12:00:00Z',
      },
    });
  }

  @override
  Future<Response> sendEmailInvite(int maintenanceId, String email) async {
    emailSent = email;
    if (emailError != null) {
      throw emailError!;
    }
    return okResponse('/x', {
      'success': true,
      'data': {'email_invited_at': '2026-10-09T12:00:00Z'},
    });
  }

  @override
  Future<List<String>> getCatalogBrands() async => const ['Fiat', 'Ford'];

  @override
  Future<List<String>> getCatalogModels(String brand) async =>
      const ['Uno', 'Palio'];
}
