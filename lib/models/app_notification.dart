/// Notificação da conta (o "sino"), vinda de GET /api/v1/notifications.
class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String body;
  final int? vehicleId;
  final int? maintenanceId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.vehicleId,
    required this.maintenanceId,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: json['type'] as String?,
      title: (json['title'] as String?) ?? 'Notificação',
      body: (json['body'] as String?) ?? '',
      vehicleId: _toInt(json['vehicle_id']),
      maintenanceId: _toInt(json['maintenance_id']),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      readAt: _toDate(json['read_at']),
      createdAt: _toDate(json['created_at']),
    );
  }

  AppNotification markedAsRead() {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      vehicleId: vehicleId,
      maintenanceId: maintenanceId,
      data: data,
      readAt: readAt ?? DateTime.now(),
      createdAt: createdAt,
    );
  }

  /// Dados no mesmo formato do push FCM, para NotificationNavigation.
  Map<String, dynamic> get navigationData => {
        ...data,
        if (type != null) 'type': type,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (maintenanceId != null) 'maintenance_id': maintenanceId,
      };

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
