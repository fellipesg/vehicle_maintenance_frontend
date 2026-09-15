class VehiclePlate {
  final String plate;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? source;
  final bool isCurrent;

  VehiclePlate({
    required this.plate,
    this.startedAt,
    this.endedAt,
    this.source,
    this.isCurrent = false,
  });

  factory VehiclePlate.fromJson(Map<String, dynamic> json) {
    return VehiclePlate(
      plate: json['plate']?.toString() ?? '',
      startedAt: _parseDate(json['started_at']),
      endedAt: _parseDate(json['ended_at']),
      source: json['source']?.toString(),
      isCurrent: json['is_current'] == true || json['ended_at'] == null,
    );
  }

  Map<String, dynamic> toJson() => {
        'plate': plate,
        if (startedAt != null) 'started_at': _formatDate(startedAt!),
        if (endedAt != null) 'ended_at': _formatDate(endedAt!),
        if (source != null) 'source': source,
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
