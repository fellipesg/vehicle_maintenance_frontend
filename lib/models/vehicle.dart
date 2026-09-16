import 'provenance_segment.dart';
import 'vehicle_plate.dart';

class Vehicle {
  final int? id;
  final String licensePlate;
  final String? currentPlate;
  final String? renavam;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String? chassis;
  final String? engine;
  final String? coverPhotoUrl;
  final String? coverPhotoPortraitUrl;
  final String? coverPhotoThumbUrl;
  final int? currentKilometers;
  final int? maintenancesCount;
  final int? verifiedMaintenancesCount;
  final List<ProvenanceSegment>? provenanceStrip;
  final List<VehiclePlate>? plateHistory;
  final List<dynamic>? maintenances;

  Vehicle({
    this.id,
    required this.licensePlate,
    this.currentPlate,
    this.renavam,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    this.chassis,
    this.engine,
    this.coverPhotoUrl,
    this.coverPhotoPortraitUrl,
    this.coverPhotoThumbUrl,
    this.currentKilometers,
    this.maintenancesCount,
    this.verifiedMaintenancesCount,
    this.provenanceStrip,
    this.plateHistory,
    this.maintenances,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final strip = json['provenance_strip'];
    final plates = json['plate_history'];

    return Vehicle(
      id: json['id'] as int?,
      licensePlate: json['license_plate']?.toString() ?? '',
      currentPlate: json['current_plate']?.toString() ??
          json['license_plate']?.toString(),
      renavam: json['renavam']?.toString(),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: json['year'] is int
          ? json['year'] as int
          : int.tryParse(json['year']?.toString() ?? '') ?? 0,
      color: json['color']?.toString(),
      chassis: json['chassis']?.toString(),
      engine: json['engine']?.toString(),
      coverPhotoUrl: json['cover_photo_url']?.toString(),
      coverPhotoPortraitUrl: json['cover_photo_portrait_url']?.toString(),
      coverPhotoThumbUrl: json['cover_photo_thumb_url']?.toString(),
      currentKilometers: json['current_kilometers'] as int?,
      maintenancesCount: _parseInt(json['maintenances_count']),
      verifiedMaintenancesCount: _parseInt(json['verified_maintenances_count']),
      provenanceStrip: strip is List
          ? strip
              .map((e) => ProvenanceSegment.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : null,
      plateHistory: plates is List
          ? plates
              .map((e) => VehiclePlate.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : null,
      maintenances: json['maintenances'],
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'license_plate': licensePlate,
      if (currentPlate != null) 'current_plate': currentPlate,
      'renavam': renavam,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'chassis': chassis,
      'engine': engine,
      if (currentKilometers != null) 'current_kilometers': currentKilometers,
      if (maintenancesCount != null) 'maintenances_count': maintenancesCount,
      if (verifiedMaintenancesCount != null)
        'verified_maintenances_count': verifiedMaintenancesCount,
      if (coverPhotoUrl != null) 'cover_photo_url': coverPhotoUrl,
      if (coverPhotoPortraitUrl != null)
        'cover_photo_portrait_url': coverPhotoPortraitUrl,
      if (coverPhotoThumbUrl != null)
        'cover_photo_thumb_url': coverPhotoThumbUrl,
      if (provenanceStrip != null)
        'provenance_strip': provenanceStrip!.map((s) => s.toJson()).toList(),
      if (plateHistory != null)
        'plate_history': plateHistory!.map((p) => p.toJson()).toList(),
    };
  }

  String get displayName => '$brand $model';
  String get fullInfo => '$displayName ($year) - $licensePlate';
  String get displayPlate => currentPlate ?? licensePlate;
}
