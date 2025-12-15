class Checklist {
  final int? id;
  final int? maintenanceId;
  final String checklistType;
  final List<Map<String, dynamic>>? items;
  final String? notes;

  Checklist({
    this.id,
    this.maintenanceId,
    required this.checklistType,
    this.items,
    this.notes,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'],
      maintenanceId: json['maintenance_id'],
      checklistType: json['checklist_type'] ?? 'initial',
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(json['items'])
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (maintenanceId != null) 'maintenance_id': maintenanceId,
      'checklist_type': checklistType,
      'items': items,
      'notes': notes,
    };
  }
}

