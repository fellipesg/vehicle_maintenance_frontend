import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/api_error.dart';

DioException dioError({
  int? statusCode,
  Object? body,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final options = RequestOptions(path: '/maintenances');

  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
  );
}

void main() {
  group('ApiException.from on validation responses', () {
    test('prefers errors over the generic Laravel message', () {
      final exception = ApiException.from(dioError(
        statusCode: 422,
        body: const {
          'success': false,
          'message': 'The given data was invalid.',
          'errors': {
            'kilometers': [
              'A quilometragem deve ser no mínimo 48000 km (hodômetro ou manutenção já registrada até essa data).',
            ],
          },
        },
      ));

      expect(exception.isValidation, isTrue);
      expect(exception.statusCode, 422);
      expect(exception.message, contains('no mínimo 48000 km'));
      expect(exception.message, isNot(contains('given data was invalid')));
      expect(exception.errorFor('kilometers'), contains('48000'));
    });

    test('joins one message per field', () {
      final exception = ApiException.from(dioError(
        statusCode: 422,
        body: const {
          'errors': {
            'renavam': ['O campo renavam é obrigatório.', 'segunda mensagem'],
            'license_plate': ['O campo placa já está em uso.'],
          },
        },
      ));

      expect(
        exception.message,
        'O campo renavam é obrigatório.\nO campo placa já está em uso.',
      );
      expect(exception.fieldErrors.keys, containsAll(['renavam', 'license_plate']));
    });

    test('keeps nested item keys addressable', () {
      final exception = ApiException.from(dioError(
        statusCode: 422,
        body: const {
          'errors': {
            'items.0.name': ['O campo nome é obrigatório.'],
          },
        },
      ));

      expect(exception.errorFor('items.0.name'), 'O campo nome é obrigatório.');
    });
  });

  group('ApiException.from on other responses', () {
    test('uses the envelope message when there is no validation', () {
      final exception = ApiException.from(dioError(
        statusCode: 422,
        body: const {
          'success': false,
          'message':
              'Cannot delete workshop because it has associated maintenances.',
        },
      ));

      expect(
        exception.message,
        'Cannot delete workshop because it has associated maintenances.',
      );
    });

    test('maps status codes with no usable body', () {
      expect(
        ApiException.from(dioError(statusCode: 401, body: null)).message,
        'Sua sessão expirou. Entre novamente.',
      );
      expect(
        ApiException.from(dioError(statusCode: 403, body: null)).message,
        'Você não tem permissão para fazer isso.',
      );
      expect(
        ApiException.from(dioError(statusCode: 429, body: null)).message,
        contains('Muitas tentativas'),
      );
      expect(
        ApiException.from(dioError(statusCode: 503, body: null)).message,
        contains('servidor falhou'),
      );
    });

    test('explains transport failures instead of leaking the Dio dump', () {
      expect(
        ApiException.from(dioError(type: DioExceptionType.connectionError))
            .message,
        contains('Sem conexão'),
      );
      expect(
        ApiException.from(dioError(type: DioExceptionType.connectionTimeout))
            .message,
        contains('demorou para responder'),
      );
    });

    test('falls back when the body carries nothing usable', () {
      final exception = ApiException.from(
        dioError(statusCode: 418, body: 'nope'),
        fallback: 'Erro ao salvar oficina',
      );

      expect(exception.message, 'Erro ao salvar oficina');
    });
  });

  group('apiErrorMessage', () {
    test('strips the Dart Exception prefix', () {
      expect(
        apiErrorMessage(Exception('Leia e aceite os termos de uso.')),
        'Leia e aceite os termos de uso.',
      );
    });

    test('never shows a raw DioException to the user', () {
      final message = apiErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/vehicles'),
          type: DioExceptionType.unknown,
        ),
      );

      expect(message, isNot(contains('DioException')));
      expect(message, 'Algo deu errado. Tente novamente.');
    });

    test('passes an ApiException through untouched', () {
      const original = ApiException('Placa já cadastrada.', statusCode: 422);

      expect(apiErrorMessage(original), 'Placa já cadastrada.');
      expect(ApiException.from(original), same(original));
    });
  });
}
