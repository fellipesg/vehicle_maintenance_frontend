import 'package:flutter/widgets.dart';

import '../services/cep_service.dart';

/// Liga um campo de CEP ao preenchimento automático do endereço.
///
/// A tela diz qual é o campo de CEP e o que fazer com o endereço encontrado; o
/// mixin cuida do resto: dispara só com os oito dígitos, não repete a mesma
/// consulta e nunca chama setState depois do dispose.
mixin CepAutofill<T extends StatefulWidget> on State<T> {
  /// Serviço usado na consulta. Testes injetam um dublê por aqui.
  CepService get cepService;

  /// Campo de onde o CEP é lido.
  TextEditingController get cepField;

  /// Preenche os campos da tela. Já roda dentro de setState.
  void onCepResolved(CepAddress address);

  /// CEP com oito dígitos que o ViaCEP não conhece.
  void onCepNotFound() {}

  bool _isLookingUpCep = false;
  String? _lastQueriedCep;

  /// Indica consulta em andamento, para a tela mostrar o progresso.
  bool get isLookingUpCep => _isLookingUpCep;

  void listenToCepField() => cepField.addListener(_onCepFieldChanged);

  void stopListeningToCepField() => cepField.removeListener(_onCepFieldChanged);

  void _onCepFieldChanged() {
    final cep = CepService.sanitize(cepField.text);

    if (cep.length != CepService.cepLength) {
      _lastQueriedCep = null;

      return;
    }

    if (cep == _lastQueriedCep) {
      return;
    }

    _lastQueriedCep = cep;
    _lookUpCep(cep);
  }

  Future<void> _lookUpCep(String cep) async {
    setState(() => _isLookingUpCep = true);

    try {
      final address = await cepService.lookup(cep);

      if (!mounted) {
        return;
      }

      if (address == null) {
        onCepNotFound();
      } else {
        setState(() => onCepResolved(address));
      }
    } catch (_) {
      // Conveniência: uma falha de rede não pode travar o cadastro.
    } finally {
      if (mounted) {
        setState(() => _isLookingUpCep = false);
      }
    }
  }
}
