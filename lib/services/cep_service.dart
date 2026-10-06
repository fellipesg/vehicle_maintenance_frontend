import 'dart:convert';

import 'package:http/http.dart' as http;

/// Endereço devolvido pela consulta de CEP.
class CepAddress {
  const CepAddress({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
  });

  factory CepAddress.fromViaCep(Map<String, dynamic> json) => CepAddress(
        street: json['logradouro']?.toString().trim() ?? '',
        neighborhood: json['bairro']?.toString().trim() ?? '',
        city: json['localidade']?.toString().trim() ?? '',
        state: json['uf']?.toString().trim() ?? '',
      );

  final String street;
  final String neighborhood;
  final String city;
  final String state;
}

/// Consulta de endereço por CEP no ViaCEP.
///
/// Devolve `null` quando o CEP não tem os oito dígitos ou quando o ViaCEP não
/// o conhece. Falha de rede sobe como exceção: quem chama decide o que fazer —
/// nos formulários o preenchimento é conveniência, então eles seguem calados.
class CepService {
  CepService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int cepLength = 8;

  static String sanitize(String value) => value.replaceAll(RegExp(r'\D'), '');

  static bool isComplete(String value) => sanitize(value).length == cepLength;

  Future<CepAddress?> lookup(String value) async {
    final cep = sanitize(value);

    if (cep.length != cepLength) {
      return null;
    }

    final response = await _client.get(
      Uri.https('viacep.com.br', '/ws/$cep/json/'),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = json.decode(response.body);

    // CEP inexistente volta como 200 com {"erro": true} (ou "true").
    if (decoded is! Map<String, dynamic> || decoded['erro'] != null) {
      return null;
    }

    return CepAddress.fromViaCep(decoded);
  }
}
