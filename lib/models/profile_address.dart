/// Endereço editado em "Meus Dados", no PUT /api/v1/me.
///
/// É o endereço do proprietário. Loja e oficina não mandam este bloco: o
/// endereço delas vive no cadastro da empresa ("Minha loja", "Minha oficina"),
/// editado só na web. Mandar os campos em branco apagaria o que está gravado,
/// então a ausência do endereço vira ausência das chaves no corpo do PUT.
class ProfileAddress {
  const ProfileAddress({
    this.postalCode,
    this.street,
    this.number,
    this.complement,
    this.city,
    this.state,
    this.country,
  });

  final String? postalCode;
  final String? street;
  final String? number;
  final String? complement;
  final String? city;
  final String? state;
  final String? country;

  Map<String, dynamic> toPayload() => {
        'postal_code': postalCode,
        'street': street,
        'number': number,
        'complement': complement,
        'city': city,
        'state': state,
        'country': country,
      };
}
