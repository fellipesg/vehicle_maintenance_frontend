import 'vehicle.dart';

class VehicleLookupResult {
  final Vehicle vehicle;
  final String matchedBy;
  final DateTime? previousPlateEndedAt;

  const VehicleLookupResult({
    required this.vehicle,
    required this.matchedBy,
    this.previousPlateEndedAt,
  });

  static const matchChassis = 'chassis';
  static const matchRenavam = 'renavam';
  static const matchCurrentPlate = 'current_plate';
  static const matchPreviousPlate = 'previous_plate';

  factory VehicleLookupResult.fromApi(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map? ?? json);
    return VehicleLookupResult(
      vehicle: Vehicle.fromJson(data),
      matchedBy: data['matched_by']?.toString() ?? matchCurrentPlate,
      previousPlateEndedAt: data['previous_plate_ended_at'] != null
          ? DateTime.tryParse(data['previous_plate_ended_at'].toString())
          : null,
    );
  }
}
