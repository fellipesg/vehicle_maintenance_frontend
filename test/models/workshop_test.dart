import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/workshop.dart';

void main() {
  group('Workshop.fromJson', () {
    test('parses logo_url when present', () {
      final workshop = Workshop.fromJson({
        'id': 1,
        'name': 'Oficina',
        'phone': '11999999999',
        'cep': '01310100',
        'street': 'Rua A',
        'number': '10',
        'neighborhood': 'Centro',
        'city': 'São Paulo',
        'state': 'SP',
        'logo_url': 'https://cdn.example/logo.png',
      });

      expect(workshop.logoUrl, 'https://cdn.example/logo.png');
    });

    test('allows null logo_url', () {
      final workshop = Workshop.fromJson({
        'id': 1,
        'name': 'Oficina',
        'phone': '11999999999',
        'cep': '01310100',
        'street': 'Rua A',
        'number': '10',
        'neighborhood': 'Centro',
        'city': 'São Paulo',
        'state': 'SP',
        'logo_url': null,
      });

      expect(workshop.logoUrl, isNull);
    });
  });
}
