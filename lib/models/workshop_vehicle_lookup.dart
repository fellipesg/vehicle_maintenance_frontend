/// Resultado da busca por chassi feita pela oficina
/// (`GET /workshop/vehicles/lookup`) ou da criação (`POST /workshop/vehicles`).
///
/// Quando o carro já tem dono o backend devolve só `{id, has_owner}`, sem
/// marca, modelo ou ano — por isso tudo aqui é opcional.
class WorkshopVehicleLookup {
  const WorkshopVehicleLookup({
    required this.found,
    this.id,
    this.brand,
    this.model,
    this.year,
    this.hasOwner = false,
  });

  final bool found;
  final int? id;
  final String? brand;
  final String? model;
  final int? year;
  final bool hasOwner;

  bool get isOwnerless => found && !hasOwner && id != null;

  String get displayName {
    final name = '${brand ?? ''} ${model ?? ''}'.trim();

    return name.isEmpty ? 'Veículo' : name;
  }

  /// `envelope` é o corpo `{success, data, message}`.
  factory WorkshopVehicleLookup.fromEnvelope(dynamic envelope) {
    final data = envelope is Map ? envelope['data'] : null;
    if (data is! Map) {
      return const WorkshopVehicleLookup(found: false);
    }

    // Criação devolve o veículo direto; a busca devolve `{found, vehicle}`.
    final hasWrapper = data.containsKey('found');
    final vehicle = hasWrapper ? data['vehicle'] : data;
    final found = hasWrapper ? data['found'] == true : true;

    if (!found || vehicle is! Map) {
      return const WorkshopVehicleLookup(found: false);
    }

    return WorkshopVehicleLookup.fromVehicleJson(
      Map<String, dynamic>.from(vehicle),
    );
  }

  factory WorkshopVehicleLookup.fromVehicleJson(Map<String, dynamic> json) {
    final year = json['year'];

    return WorkshopVehicleLookup(
      found: true,
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      year: year is int ? year : int.tryParse('$year'),
      hasOwner: json['has_owner'] == true,
    );
  }
}
