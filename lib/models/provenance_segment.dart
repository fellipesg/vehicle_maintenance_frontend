class ProvenanceSegment {
  final int maintenanceId;
  final DateTime? date;
  final bool isVerified;

  ProvenanceSegment({
    required this.maintenanceId,
    this.date,
    required this.isVerified,
  });

  factory ProvenanceSegment.fromJson(Map<String, dynamic> json) {
    return ProvenanceSegment(
      maintenanceId: json['maintenance_id'] as int? ?? 0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      isVerified: json['is_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'maintenance_id': maintenanceId,
        if (date != null)
          'date':
              '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
        'is_verified': isVerified,
      };
}
