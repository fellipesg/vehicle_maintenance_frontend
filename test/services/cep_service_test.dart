import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vehicle_maintenance/services/cep_service.dart';

http.Response _json(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('CepService.sanitize', () {
    test('mantém apenas dígitos', () {
      expect(CepService.sanitize('86010-000'), '86010000');
      expect(CepService.sanitize(' 86.010-000 '), '86010000');
    });
  });

  group('CepService.isComplete', () {
    test('exige os oito dígitos', () {
      expect(CepService.isComplete('86010-000'), isTrue);
      expect(CepService.isComplete('8601000'), isFalse);
      expect(CepService.isComplete(''), isFalse);
    });
  });

  group('CepService.lookup', () {
    test('devolve o endereço e consulta o CEP só com dígitos', () async {
      late Uri requested;

      final service = CepService(
        client: MockClient((request) async {
          requested = request.url;

          return _json({
            'logradouro': 'Rua Piauí',
            'bairro': 'Centro',
            'localidade': 'Londrina',
            'uf': 'PR',
          });
        }),
      );

      final address = await service.lookup('86010-000');

      expect(requested.toString(), 'https://viacep.com.br/ws/86010000/json/');
      expect(address, isNotNull);
      expect(address!.street, 'Rua Piauí');
      expect(address.neighborhood, 'Centro');
      expect(address.city, 'Londrina');
      expect(address.state, 'PR');
    });

    test('devolve campos vazios quando o ViaCEP omite o logradouro', () async {
      final service = CepService(
        client: MockClient((_) async => _json({
              'localidade': 'Curitiba',
              'uf': 'PR',
            })),
      );

      final address = await service.lookup('80000000');

      expect(address!.street, '');
      expect(address.neighborhood, '');
      expect(address.city, 'Curitiba');
    });

    test('devolve null quando o ViaCEP marca erro', () async {
      final service = CepService(
        client: MockClient((_) async => _json({'erro': 'true'})),
      );

      expect(await service.lookup('00000000'), isNull);
    });

    test('devolve null sem tocar na rede se faltam dígitos', () async {
      var calls = 0;

      final service = CepService(
        client: MockClient((_) async {
          calls++;

          return _json({});
        }),
      );

      expect(await service.lookup('8601000'), isNull);
      expect(calls, 0);
    });

    test('devolve null quando a resposta não é 200', () async {
      final service = CepService(
        client: MockClient((_) async => _json({}, status: 500)),
      );

      expect(await service.lookup('86010000'), isNull);
    });

    test('propaga falha de rede para quem chamou', () async {
      final service = CepService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      expect(service.lookup('86010000'), throwsA(isA<SocketExceptionStub>()));
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
