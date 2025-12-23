class Workshop {
  final int? id;
  final String name;
  final String phone;
  final String? whatsapp;
  final String? email;
  final String? facebook;
  final String? instagram;
  final String cep;
  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;

  Workshop({
    this.id,
    required this.name,
    required this.phone,
    this.whatsapp,
    this.email,
    this.facebook,
    this.instagram,
    required this.cep,
    required this.street,
    required this.number,
    this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
  });

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      facebook: json['facebook'] as String?,
      instagram: json['instagram'] as String?,
      cep: json['cep'] as String,
      street: json['street'] as String,
      number: json['number'] as String,
      complement: json['complement'] as String?,
      neighborhood: json['neighborhood'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'facebook': facebook,
      'instagram': instagram,
      'cep': cep.replaceAll(RegExp(r'\D'), ''), // Remove non-digits
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state.toUpperCase(),
    };
  }

  String get formattedCep {
    if (cep.length == 8) {
      return '${cep.substring(0, 5)}-${cep.substring(5)}';
    }
    return cep;
  }

  String get fullAddress {
    String address = '$street, $number';
    if (complement != null && complement!.isNotEmpty) {
      address += ' - $complement';
    }
    address += ' - $neighborhood, $city/$state';
    address += ' - CEP: $formattedCep';
    return address;
  }

  String get shortAddress {
    return '$street, $number - $neighborhood, $city/$state';
  }

  String? get googleMapsUrl {
    final address = Uri.encodeComponent(fullAddress);
    return 'https://www.google.com/maps/search/?api=1&query=$address';
  }
}
