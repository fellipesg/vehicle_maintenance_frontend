import 'maintenance_warranty.dart';

class MaintenanceItem {
  final int? id;
  final int? maintenanceId;
  final String name;
  final String? description;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? partNumber;
  final bool hasWarranty;
  final DateTime? warrantyStartsAt;
  final DateTime? warrantyEndsAt;
  final String? warrantyPeriodLabel;
  final bool isUnderWarranty;
  final MaintenanceWarranty? warranty;
  final int? warrantyTemplateId;

  MaintenanceItem({
    this.id,
    this.maintenanceId,
    required this.name,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.partNumber,
    this.hasWarranty = false,
    this.warrantyStartsAt,
    this.warrantyEndsAt,
    this.warrantyPeriodLabel,
    this.isUnderWarranty = false,
    this.warranty,
    this.warrantyTemplateId,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null || value.toString().isEmpty) {
        return null;
      }

      return DateTime.tryParse(value.toString());
    }

    final warrantyJson = json['warranty'];
    final warranty = warrantyJson is Map<String, dynamic>
        ? MaintenanceWarranty.fromJson(warrantyJson)
        : null;

    final hasWarrantyFromApi = json['has_warranty'] == true;
    final hasWarranty = warranty != null || hasWarrantyFromApi;

    return MaintenanceItem(
      id: json['id'],
      maintenanceId: json['maintenance_id'],
      name: json['name'] ?? '',
      description: json['description'],
      quantity: json['quantity'] ?? 1,
      unitPrice: parseDouble(json['unit_price']),
      totalPrice: parseDouble(json['total_price']),
      partNumber: json['part_number'],
      hasWarranty: hasWarranty,
      warrantyStartsAt:
          warranty?.startsAt ?? parseDate(json['warranty_starts_at']),
      warrantyEndsAt: warranty?.endsAt ?? parseDate(json['warranty_ends_at']),
      warrantyPeriodLabel: json['warranty_period_label'] as String?,
      isUnderWarranty:
          json['is_under_warranty'] == true || (warranty?.isVigente ?? false),
      warranty: warranty,
      warrantyTemplateId: warranty?.warrantyTemplateId,
    );
  }

  String? get displayWarrantyLabel {
    if (warranty?.label != null && warranty!.label!.isNotEmpty) {
      return warranty!.label;
    }

    if (warrantyPeriodLabel != null && warrantyPeriodLabel!.isNotEmpty) {
      return warrantyPeriodLabel;
    }

    if (warrantyEndsAt != null) {
      final end = warrantyEndsAt!;
      final formatted =
          '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
      return isUnderWarranty
          ? 'Em garantia até $formatted'
          : 'Garantia até $formatted';
    }

    return null;
  }

  String? get warrantyName => warranty?.name;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (maintenanceId != null) 'maintenance_id': maintenanceId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice.toStringAsFixed(2),
      'total_price': totalPrice.toStringAsFixed(2),
      'part_number': partNumber,
      if (warrantyTemplateId != null)
        'warranty_template_id': warrantyTemplateId,
    };
  }
}
