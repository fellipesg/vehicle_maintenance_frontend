import 'package:dio/dio.dart';

/// Erro da API já traduzido para uma mensagem que pode ir direto para a tela.
///
/// O backend responde no envelope `{success, message, errors}` e valida em pt_BR,
/// então as mensagens de `errors` já estão prontas para o usuário — é delas que
/// vêm avisos como "A quilometragem deve ser no mínimo 48000 km".
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;

  /// Erros por campo, como o backend devolve em `errors` (ex.: `kilometers`,
  /// `items.0.name`). Vazio quando a resposta não trouxe validação.
  final Map<String, List<String>> fieldErrors;

  bool get isValidation => statusCode == 422;

  bool get isUnauthorized => statusCode == 401;

  /// Primeira mensagem do campo, se o backend reclamou dele.
  String? errorFor(String field) {
    final messages = fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  /// Converte qualquer erro em `ApiException`, preservando `fieldErrors`.
  factory ApiException.from(Object? error, {String? fallback}) {
    if (error is ApiException) {
      return error;
    }

    if (error is DioException) {
      return _fromDio(error, fallback: fallback);
    }

    final raw = _stripExceptionPrefix(error?.toString());

    return ApiException(raw ?? fallback ?? _genericFallback);
  }

  @override
  String toString() => message;
}

/// Mensagem pronta para `SnackBar` a partir de qualquer erro capturado.
String apiErrorMessage(Object? error, {String? fallback}) =>
    ApiException.from(error, fallback: fallback).message;

const String _genericFallback = 'Algo deu errado. Tente novamente.';

ApiException _fromDio(DioException error, {String? fallback}) {
  final status = error.response?.statusCode;
  final fieldErrors = _fieldErrorsFrom(error.response?.data);

  final message = _messageFromBody(error.response?.data, fieldErrors) ??
      _messageFromType(error) ??
      _messageFromStatus(status) ??
      fallback ??
      _genericFallback;

  return ApiException(
    message,
    statusCode: status,
    fieldErrors: fieldErrors,
  );
}

Map<String, List<String>> _fieldErrorsFrom(dynamic data) {
  if (data is! Map) {
    return const {};
  }

  final errors = data['errors'];
  if (errors is! Map) {
    return const {};
  }

  final parsed = <String, List<String>>{};

  for (final entry in errors.entries) {
    final messages = entry.value;
    final list = messages is List
        ? messages.map((m) => m.toString()).where((m) => m.isNotEmpty).toList()
        : <String>[
            if (messages != null && messages.toString().isNotEmpty)
              messages.toString(),
          ];

    if (list.isNotEmpty) {
      parsed[entry.key.toString()] = list;
    }
  }

  return parsed;
}

/// `errors` vem antes de `message` de propósito: num 422 o `message` é o
/// "The given data was invalid." genérico do Laravel, enquanto `errors` traz o
/// motivo real em pt_BR.
String? _messageFromBody(dynamic data, Map<String, List<String>> fieldErrors) {
  if (fieldErrors.isNotEmpty) {
    return fieldErrors.values.map((messages) => messages.first).join('\n');
  }

  if (data is! Map) {
    return null;
  }

  final message = data['message'];
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }

  return null;
}

String? _messageFromType(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'O servidor demorou para responder. Tente novamente.';
    case DioExceptionType.connectionError:
      return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
    case DioExceptionType.badCertificate:
      return 'Não foi possível validar o certificado do servidor.';
    case DioExceptionType.cancel:
      return 'Operação cancelada.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return null;
  }
}

String? _messageFromStatus(int? status) {
  if (status == null) {
    return null;
  }

  if (status >= 500) {
    return 'O servidor falhou ao processar o pedido. Tente novamente em instantes.';
  }

  return switch (status) {
    401 => 'Sua sessão expirou. Entre novamente.',
    403 => 'Você não tem permissão para fazer isso.',
    404 => 'Registro não encontrado.',
    413 => 'Arquivo muito grande. Envie um arquivo menor.',
    429 => 'Muitas tentativas em pouco tempo. Aguarde um instante e tente de novo.',
    _ => null,
  };
}

/// Mensagens lançadas como `Exception('...')` chegam aqui com o prefixo do Dart.
/// Um dump de `DioException` não serve para o usuário, então cai no fallback.
String? _stripExceptionPrefix(String? raw) {
  if (raw == null) {
    return null;
  }

  final cleaned = raw.replaceFirst('Exception: ', '').trim();

  if (cleaned.isEmpty || cleaned.startsWith('DioException')) {
    return null;
  }

  return cleaned;
}
