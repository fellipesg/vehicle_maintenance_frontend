/// Registro (OS) feito por uma oficina em um carro que o usuário agora possui.
///
/// O parse tolera campos ausentes: o contrato é novo e o app não deve quebrar se
/// o backend omitir algo.
class WorkshopRecord {
  const WorkshopRecord({
    required this.id,
    required this.vehicle,
    required this.workshop,
    this.maintenanceDate,
    this.kilometers,
    this.serviceCategory,
    this.maintenanceType,
    this.items = const [],
    this.verificationCode,
    this.invoicesCount = 0,
    this.photosCount = 0,
    this.ownerStatus = OwnerStatus.pending,
    this.attachmentsStatus = AttachmentsStatus.none,
    this.hiddenFromPublic = false,
    this.canAcceptAttachments = false,
    this.canDecide = true,
  });

  final int id;
  final WorkshopRecordVehicle vehicle;
  final WorkshopRecordWorkshop workshop;
  final DateTime? maintenanceDate;
  final int? kilometers;
  final String? serviceCategory;
  final String? maintenanceType;
  final List<WorkshopRecordItem> items;
  final String? verificationCode;
  final int invoicesCount;
  final int photosCount;
  final OwnerStatus ownerStatus;
  final AttachmentsStatus attachmentsStatus;
  final bool hiddenFromPublic;
  final bool canAcceptAttachments;

  /// Só o dono comprovado pelo CRLV-e decide (`can_decide`). Sem o campo, a
  /// API é anterior a essa regra e o servidor continua sendo quem recusa.
  final bool canDecide;

  int get attachmentsCount => invoicesCount + photosCount;

  bool get isPending => ownerStatus == OwnerStatus.pending;

  bool get isLinked => ownerStatus == OwnerStatus.linked;

  bool get attachmentsAccepted =>
      attachmentsStatus == AttachmentsStatus.accepted;

  factory WorkshopRecord.fromJson(Map<String, dynamic> json) {
    final attachments = json['attachments'];
    final items = json['items'];

    return WorkshopRecord(
      id: _int(json['id']) ?? 0,
      vehicle: WorkshopRecordVehicle.fromJson(_map(json['vehicle'])),
      workshop: WorkshopRecordWorkshop.fromJson(_map(json['workshop'])),
      maintenanceDate: json['maintenance_date'] != null
          ? DateTime.tryParse(json['maintenance_date'].toString())
          : null,
      kilometers: _int(json['kilometers']),
      serviceCategory: json['service_category']?.toString(),
      maintenanceType: json['maintenance_type']?.toString(),
      items: items is List
          ? items
              .whereType<Map>()
              .map((item) => WorkshopRecordItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      verificationCode: json['verification_code']?.toString(),
      invoicesCount:
          attachments is Map ? _int(attachments['invoices']) ?? 0 : 0,
      photosCount: attachments is Map ? _int(attachments['photos']) ?? 0 : 0,
      ownerStatus: OwnerStatus.parse(json['owner_status']?.toString()),
      attachmentsStatus:
          AttachmentsStatus.parse(json['attachments_status']?.toString()),
      hiddenFromPublic: json['hidden_from_public'] == true,
      canAcceptAttachments: json['can_accept_attachments'] == true,
      canDecide:
          json.containsKey('can_decide') ? json['can_decide'] == true : true,
    );
  }

  static List<WorkshopRecord> listFromEnvelope(dynamic envelope) {
    if (envelope is! Map || envelope['data'] is! List) {
      return const [];
    }

    return (envelope['data'] as List)
        .whereType<Map>()
        .map((row) => WorkshopRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

enum OwnerStatus {
  pending,
  linked,
  declined;

  static OwnerStatus parse(String? value) {
    return switch (value) {
      'linked' => OwnerStatus.linked,
      'declined' => OwnerStatus.declined,
      _ => OwnerStatus.pending,
    };
  }
}

enum AttachmentsStatus {
  none,
  pending,
  accepted,
  declined,
  revoked;

  static AttachmentsStatus parse(String? value) {
    return switch (value) {
      'pending' => AttachmentsStatus.pending,
      'accepted' => AttachmentsStatus.accepted,
      'declined' => AttachmentsStatus.declined,
      'revoked' => AttachmentsStatus.revoked,
      _ => AttachmentsStatus.none,
    };
  }
}

class WorkshopRecordVehicle {
  const WorkshopRecordVehicle({
    this.id,
    this.brand = '',
    this.model = '',
    this.year,
    this.chassisMasked,
  });

  final int? id;
  final String brand;
  final String model;
  final int? year;
  final String? chassisMasked;

  String get displayName {
    final name = '$brand $model'.trim();

    return name.isEmpty ? 'Veículo' : name;
  }

  factory WorkshopRecordVehicle.fromJson(Map<String, dynamic> json) {
    return WorkshopRecordVehicle(
      id: _int(json['id']),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: _int(json['year']),
      chassisMasked: json['chassis_masked']?.toString(),
    );
  }
}

class WorkshopRecordWorkshop {
  const WorkshopRecordWorkshop({this.id, this.name = ''});

  final int? id;
  final String name;

  factory WorkshopRecordWorkshop.fromJson(Map<String, dynamic> json) {
    return WorkshopRecordWorkshop(
      id: _int(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class WorkshopRecordItem {
  const WorkshopRecordItem({required this.name, this.quantity});

  final String name;
  final num? quantity;

  factory WorkshopRecordItem.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'];

    return WorkshopRecordItem(
      name: json['name']?.toString() ?? '',
      quantity: quantity is num ? quantity : num.tryParse('$quantity'),
    );
  }
}

int? _int(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
