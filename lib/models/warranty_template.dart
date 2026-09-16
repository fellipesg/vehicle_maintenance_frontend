class WarrantyTemplate {
  final int id;
  final int? workshopId;
  final String name;
  final String? body;
  final int durationDays;
  final String scope;
  final bool isActive;

  WarrantyTemplate({
    required this.id,
    this.workshopId,
    required this.name,
    this.body,
    required this.durationDays,
    required this.scope,
    this.isActive = true,
  });

  factory WarrantyTemplate.fromJson(Map<String, dynamic> json) {
    return WarrantyTemplate(
      id: json['id'] as int,
      workshopId: json['workshop_id'] as int?,
      name: json['name'] as String,
      body: json['body'] as String?,
      durationDays: json['duration_days'] as int? ?? 0,
      scope: json['scope'] as String? ?? 'item',
      isActive: json['is_active'] == true,
    );
  }

  String get displayLabel => '$name ($durationDays dias)';
}
