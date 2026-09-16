class MaintenanceWarranty {
  final int? id;
  final int? maintenanceId;
  final int? maintenanceItemId;
  final int? warrantyTemplateId;
  final String? scope;
  final String name;
  final String? body;
  final int? durationDays;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? label;
  final bool isVigente;

  MaintenanceWarranty({
    this.id,
    this.maintenanceId,
    this.maintenanceItemId,
    this.warrantyTemplateId,
    this.scope,
    required this.name,
    this.body,
    this.durationDays,
    this.startsAt,
    this.endsAt,
    this.label,
    this.isVigente = false,
  });

  factory MaintenanceWarranty.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || value.toString().isEmpty) {
        return null;
      }

      return DateTime.tryParse(value.toString());
    }

    return MaintenanceWarranty(
      id: json['id'] as int?,
      maintenanceId: json['maintenance_id'] as int?,
      maintenanceItemId: json['maintenance_item_id'] as int?,
      warrantyTemplateId: json['warranty_template_id'] as int?,
      scope: json['scope'] as String?,
      name: json['name'] as String? ?? '',
      body: json['body'] as String?,
      durationDays: json['duration_days'] as int?,
      startsAt: parseDate(json['starts_at']),
      endsAt: parseDate(json['ends_at']),
      label: json['label'] as String?,
      isVigente: json['is_vigente'] == true,
    );
  }
}
