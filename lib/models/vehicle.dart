class Vehicle {
  final int? id;
  final String licensePlate;
  final String? renavam;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String? chassis;
  final String? engine;
  final List<dynamic>? maintenances;

  Vehicle({
    this.id,
    required this.licensePlate,
    this.renavam,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    this.chassis,
    this.engine,
    this.maintenances,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['license_plate'] ?? '',
      renavam: json['renavam'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      color: json['color'],
      chassis: json['chassis'],
      engine: json['engine'],
      maintenances: json['maintenances'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'license_plate': licensePlate,
      'renavam': renavam,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'chassis': chassis,
      'engine': engine,
    };
  }

  String get displayName => '$brand $model';
  String get fullInfo => '$displayName ($year) - $licensePlate';
}

