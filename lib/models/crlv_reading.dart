/// Resultado de `POST /api/v1/vehicles/crlv`: o CRLV-e lido pelo servidor e o
/// caminho que ele decidiu.
///
/// - [CrlvReadingMode.newVehicle]: o formulário é preenchido e o cadastro vai
///   com [verificationToken], que marca a posse como verificada.
/// - [CrlvReadingMode.claim]: o veículo já está na RevisaLog e o vínculo é
///   confirmado em `POST /api/v1/vehicles/crlv/claim`.
/// - [CrlvReadingMode.linked]: o veículo já é da conta.
///
/// [needsPowerOfAttorney] vem quando o CRLV-e não está no CPF/CNPJ da conta e
/// o cadastro exige procuração, que só existe no site.
enum CrlvReadingMode { newVehicle, claim, linked }

class CrlvExistingVehicle {
  final int id;
  final String brand;
  final String model;
  final int? year;
  final int maintenancesCount;

  const CrlvExistingVehicle({
    required this.id,
    required this.brand,
    required this.model,
    this.year,
    this.maintenancesCount = 0,
  });

  String get title => [
    brand,
    model,
    if (year != null) '$year',
  ].where((part) => part.trim().isNotEmpty).join(' ');

  factory CrlvExistingVehicle.fromJson(Map<String, dynamic> json) {
    return CrlvExistingVehicle(
      id: _int(json['id']) ?? 0,
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: _int(json['year']),
      maintenancesCount: _int(json['maintenances_count']) ?? 0,
    );
  }
}

class CrlvReading {
  final CrlvReadingMode mode;
  final bool needsPowerOfAttorney;
  final String verificationToken;
  final String licensePlate;
  final String renavam;
  final String brand;
  final String model;
  final bool brandMatched;
  final bool modelMatched;
  final int? year;
  final String? color;
  final String? chassis;
  final String? engine;
  final CrlvExistingVehicle? existingVehicle;

  const CrlvReading({
    required this.mode,
    required this.needsPowerOfAttorney,
    required this.verificationToken,
    required this.licensePlate,
    required this.renavam,
    required this.brand,
    required this.model,
    this.brandMatched = true,
    this.modelMatched = true,
    this.year,
    this.color,
    this.chassis,
    this.engine,
    this.existingVehicle,
  });

  /// [data] é o `data` do envelope da API.
  factory CrlvReading.fromJson(Map<String, dynamic> data) {
    final vehicle = Map<String, dynamic>.from(data['vehicle'] as Map? ?? {});
    final existing = data['existing_vehicle'];

    return CrlvReading(
      mode: switch (data['mode']) {
        'claim' => CrlvReadingMode.claim,
        'linked' => CrlvReadingMode.linked,
        _ => CrlvReadingMode.newVehicle,
      },
      needsPowerOfAttorney: data['ownership'] == 'consignment',
      verificationToken: data['crlv_verification_token']?.toString() ?? '',
      licensePlate: vehicle['license_plate']?.toString() ?? '',
      renavam: vehicle['renavam']?.toString() ?? '',
      brand: vehicle['brand']?.toString() ?? '',
      model: vehicle['model']?.toString() ?? '',
      brandMatched: vehicle['brand_matched'] != false,
      modelMatched: vehicle['model_matched'] != false,
      year: _int(vehicle['year']),
      color: _blankToNull(vehicle['color']),
      chassis: _blankToNull(vehicle['chassis']),
      engine: _blankToNull(vehicle['engine']),
      existingVehicle: existing is Map
          ? CrlvExistingVehicle.fromJson(Map<String, dynamic>.from(existing))
          : null,
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String? _blankToNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
