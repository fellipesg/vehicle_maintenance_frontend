import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Eventos de conversão enviados ao SDK da Meta pelo app iOS.
///
/// Só o fato é enviado: nenhum parâmetro, nenhum dado pessoal (placa, chassi,
/// RENAVAM, nome, e-mail). O lado nativo (`AppDelegate.swift`) só aceita os
/// nomes abaixo; qualquer outro é recusado.
class MetaAppEvents {
  static const MethodChannel _channel = MethodChannel(
    'br.com.revisalog.app/meta_events',
  );

  static const String completeRegistration = 'complete_registration';
  static const String vehicleAdded = 'vehicle_added';

  /// Trocável nos testes; no app, só iOS envia.
  final bool Function() _isSupported;

  const MetaAppEvents({bool Function()? isSupported})
      : _isSupported = isSupported ?? _isIos;

  static bool _isIos() => !kIsWeb && Platform.isIOS;

  Future<void> logCompleteRegistration() => _log(completeRegistration);

  Future<void> logVehicleAdded() => _log(vehicleAdded);

  Future<void> _log(String event) async {
    if (!_isSupported()) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('log', event);
    } on MissingPluginException {
      // Sem o canal nativo (testes, outras plataformas): medição é opcional.
    } on PlatformException {
      // Falha da medição nunca pode afetar cadastro ou veículo.
    }
  }
}
