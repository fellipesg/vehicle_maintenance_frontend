import 'maintenance_item.dart';
import 'invoice.dart';

class Maintenance {
  final int? id;
  final int vehicleId;
  final int? userId;
  final String maintenanceType;
  final String? description;
  final String? workshopName;
  final DateTime maintenanceDate;
  final int? kilometers;
  final String? serviceCategory;
  final bool? isManufacturerRequired;
  final List<MaintenanceItem>? items;
  final List<Invoice>? invoices;
  final List<dynamic>? checklists;

  Maintenance({
    this.id,
    required this.vehicleId,
    this.userId,
    required this.maintenanceType,
    this.description,
    this.workshopName,
    required this.maintenanceDate,
    this.kilometers,
    this.serviceCategory,
    this.isManufacturerRequired,
    this.items,
    this.invoices,
    this.checklists,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) {
    return Maintenance(
      id: json['id'],
      vehicleId: json['vehicle_id'] ?? 0,
      userId: json['user_id'],
      maintenanceType: json['maintenance_type'] ?? '',
      description: json['description'],
      workshopName: json['workshop_name'],
      maintenanceDate: json['maintenance_date'] != null
          ? DateTime.parse(json['maintenance_date'])
          : DateTime.now(),
      kilometers: json['kilometers'],
      serviceCategory: json['service_category'],
      isManufacturerRequired: json['is_manufacturer_required'] ?? false,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => MaintenanceItem.fromJson(item))
              .toList()
          : null,
      invoices: json['invoices'] != null
          ? (json['invoices'] as List)
              .map((invoice) => Invoice.fromJson(invoice))
              .toList()
          : null,
      checklists: json['checklists'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'maintenance_type': maintenanceType,
      'description': description,
      'workshop_name': workshopName,
      'maintenance_date': maintenanceDate.toIso8601String().split('T')[0],
      'kilometers': kilometers,
      'service_category': serviceCategory,
      'is_manufacturer_required': isManufacturerRequired ?? false,
    };
  }
}

