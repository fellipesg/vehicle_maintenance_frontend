import 'maintenance_item.dart';
import 'maintenance_warranty.dart';
import 'invoice.dart';
import 'workshop.dart';

class Maintenance {
  final int? id;
  final int vehicleId;
  final int? userId;
  final int? workshopId;
  final String maintenanceType;
  final String? description;
  final String? workshopName;
  final DateTime maintenanceDate;
  final int? kilometers;
  final String? serviceCategory;
  final bool? isManufacturerRequired;
  final String? registeredByType;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? provenanceLabel;
  final String? provenanceSublabel;
  final Workshop? verifiedWorkshop;
  final String? verificationCode;
  final String? verificationUrl;
  final List<List<int>>? verificationQrMatrix;
  final List<MaintenanceItem>? items;
  final List<Invoice>? invoices;
  final List<dynamic>? checklists;
  final Workshop? workshop;
  final MaintenanceWarranty? generalWarranty;
  final String? ownerName;

  Maintenance({
    this.id,
    required this.vehicleId,
    this.userId,
    this.workshopId,
    required this.maintenanceType,
    this.description,
    this.workshopName,
    required this.maintenanceDate,
    this.kilometers,
    this.serviceCategory,
    this.isManufacturerRequired,
    this.registeredByType,
    this.isVerified = false,
    this.verifiedAt,
    this.provenanceLabel,
    this.provenanceSublabel,
    this.verifiedWorkshop,
    this.verificationCode,
    this.verificationUrl,
    this.verificationQrMatrix,
    this.items,
    this.invoices,
    this.checklists,
    this.workshop,
    this.generalWarranty,
    this.ownerName,
  });

  bool get hasInvoices => (invoices?.isNotEmpty ?? false);

  factory Maintenance.fromJson(Map<String, dynamic> json) {
    final generalWarrantyJson = json['general_warranty'];
    final qr = json['verification_qr_matrix'];

    return Maintenance(
      id: json['id'] as int?,
      vehicleId: json['vehicle_id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      workshopId: json['workshop_id'] as int?,
      maintenanceType: json['maintenance_type']?.toString() ?? '',
      description: json['description']?.toString(),
      workshopName: json['workshop_name']?.toString(),
      maintenanceDate: json['maintenance_date'] != null
          ? DateTime.parse(json['maintenance_date'].toString())
          : DateTime.now(),
      kilometers: json['kilometers'] as int?,
      serviceCategory: json['service_category']?.toString(),
      isManufacturerRequired: json['is_manufacturer_required'] == true,
      registeredByType: json['registered_by_type']?.toString(),
      isVerified: json['is_verified'] == true || json['verified_at'] != null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
      provenanceLabel: json['provenance_label']?.toString() ??
          json['provenance_card_label']?.toString(),
      provenanceSublabel: json['provenance_sublabel']?.toString() ??
          json['provenance_meta']?.toString(),
      verifiedWorkshop: json['verified_workshop'] is Map<String, dynamic>
          ? Workshop.fromJson(
              Map<String, dynamic>.from(json['verified_workshop'] as Map),
            )
          : null,
      verificationCode: json['verification_code']?.toString(),
      verificationUrl: json['verification_url']?.toString(),
      verificationQrMatrix: qr is List
          ? qr
              .map((row) => (row as List)
                  .map((cell) => cell is int ? cell : int.parse('$cell'))
                  .toList())
              .toList()
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => MaintenanceItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList()
          : null,
      invoices: json['invoices'] != null
          ? (json['invoices'] as List)
              .map((invoice) => Invoice.fromJson(
                    Map<String, dynamic>.from(invoice as Map),
                  ))
              .toList()
          : null,
      checklists: json['checklists'],
      workshop: json['workshop'] is Map<String, dynamic>
          ? Workshop.fromJson(
              Map<String, dynamic>.from(json['workshop'] as Map))
          : null,
      generalWarranty: generalWarrantyJson is Map<String, dynamic>
          ? MaintenanceWarranty.fromJson(generalWarrantyJson)
          : null,
      ownerName: json['user'] is Map ? json['user']['name']?.toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'maintenance_type': maintenanceType,
      'description': description,
      'workshop_name': workshopName,
      'maintenance_date': maintenanceDate.toIso8601String().split('T').first,
      'kilometers': kilometers,
      'service_category': serviceCategory,
      'is_manufacturer_required': isManufacturerRequired ?? false,
      if (registeredByType != null) 'registered_by_type': registeredByType,
      'is_verified': isVerified,
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      if (provenanceLabel != null) 'provenance_label': provenanceLabel,
      if (provenanceSublabel != null) 'provenance_sublabel': provenanceSublabel,
      if (verificationCode != null) 'verification_code': verificationCode,
      if (verificationUrl != null) 'verification_url': verificationUrl,
    };
  }
}
