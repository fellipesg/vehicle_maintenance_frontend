import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../models/vehicle_lookup_result.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import 'vehicle_form_page.dart';

/// Reivindica um veículo que já existe na base — o caminho que a mensagem de
/// chassi duplicado manda o usuário procurar e que até agora não existia no app.
///
/// A placa e o RENAVAM digitados são a prova de posse: o backend os confere
/// contra o documento do veículo. Por isso a ficha do veículo encontrado não
/// repete nenhum dos dois, mesmo que a busca pública devolva — mostrar o valor
/// esperado tornaria a conferência inútil.
///
/// Placa e RENAVAM não tiram o veículo de outra conta (o backend responde 403:
/// quem vendeu também conhece os dois). Nesse caso a tela leva ao CRLV-e, que
/// transfere o veículo quando está no CPF/CNPJ da conta.
class VehicleLinkPage extends StatefulWidget {
  /// Trocável nos testes; passado ao cadastro aberto por "Enviar CRLV-e".
  final CrlvPdfPicker? pickCrlvPdf;

  const VehicleLinkPage({super.key, this.pickCrlvPdf});

  @override
  State<VehicleLinkPage> createState() => _VehicleLinkPageState();
}

class _VehicleLinkPageState extends State<VehicleLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _renavamController = TextEditingController();

  Vehicle? _found;
  bool _isSearching = false;
  bool _isLinking = false;
  String? _notFoundMessage;

  /// O vínculo voltou 403: o veículo encontrado é de outra conta.
  bool _ownedByAnotherAccount = false;

  @override
  void dispose() {
    _plateController.dispose();
    _renavamController.dispose();
    super.dispose();
  }

  String get _plate => _plateController.text.trim().toUpperCase();

  String get _renavam => _renavamController.text.trim();

  String? _validatePlate(String? value) {
    final plate = value?.trim() ?? '';

    if (plate.isEmpty) {
      return 'Informe a placa do documento';
    }
    if (plate.length < 7) {
      return 'Placa deve ter 7 caracteres';
    }

    return null;
  }

  String? _validateRenavam(String? value) {
    final renavam = value?.trim() ?? '';

    if (renavam.isEmpty) {
      return 'Informe o RENAVAM do documento';
    }
    if (!RegExp(r'^\d{9,11}$').hasMatch(renavam)) {
      return 'RENAVAM deve ter de 9 a 11 dígitos';
    }

    return null;
  }

  /// Qualquer edição invalida a ficha na tela: ela pertence à placa pesquisada.
  void _resetResult() {
    if (_found == null && _notFoundMessage == null && !_ownedByAnotherAccount) {
      return;
    }

    setState(() {
      _found = null;
      _notFoundMessage = null;
      _ownedByAnotherAccount = false;
    });
  }

  Future<void> _search() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSearching = true;
      _found = null;
      _notFoundMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final VehicleLookupResult result = await apiService.searchVehicle(_plate);

      if (!mounted) {
        return;
      }

      setState(() {
        _found = result.vehicle;
        _isSearching = false;
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _notFoundMessage = e.response?.statusCode == 404
            ? 'Nenhum veículo encontrado com esta placa. Se ele nunca foi '
                'cadastrado, use "Adicionar veículo".'
            : apiErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _notFoundMessage = apiErrorMessage(e);
      });
    }
  }

  Future<void> _link() async {
    final vehicle = _found;
    if (vehicle?.id == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLinking = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.linkVehicle(
        vehicle!.id!.toString(),
        licensePlate: _plate,
        renavam: _renavam,
      );

      if (response.data is Map && response.data['success'] == true) {
        if (!mounted) {
          return;
        }

        // O ScaffoldMessenger está acima desta rota, então a mensagem sobrevive
        // ao pop e aparece já na lista com o veículo novo.
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        await context.read<VehicleRepository>().invalidate();

        if (!mounted) {
          return;
        }

        navigator.pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Veículo vinculado à sua conta!'),
            backgroundColor: Colors.green,
          ),
        );

        return;
      }

      throw Exception(
        response.data is Map ? response.data['message'] : null,
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      if (e.response?.statusCode == 403) {
        setState(() {
          _isLinking = false;
          _ownedByAnotherAccount = true;
        });

        return;
      }

      _showLinkError(e);
    } catch (e) {
      _showLinkError(e);
    }
  }

  void _showLinkError(Object e) {
    if (mounted) {
      setState(() {
        _isLinking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Troca esta tela pelo cadastro com o seletor do CRLV-e já aberto. O cadastro
  /// atualiza a lista e mostra o resultado sozinho.
  void _openCrlvFlow() {
    final picker = widget.pickCrlvPdf;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => picker == null
            ? const VehicleFormPage(startWithCrlv: true)
            : VehicleFormPage(startWithCrlv: true, pickCrlvPdf: picker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _isSearching || _isLinking;

    return Scaffold(
      appBar: AppBar(title: const Text('Vincular veículo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Já cadastrado por outra pessoa?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Informe a placa e o RENAVAM como estão no documento. '
                  'O histórico de manutenções continua com o veículo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('link_plate_field'),
                  controller: _plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(7),
                    // A conferência com o documento é sensível a caixa.
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  validator: _validatePlate,
                  onChanged: (_) => _resetResult(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('link_renavam_field'),
                  controller: _renavamController,
                  decoration: const InputDecoration(
                    labelText: 'RENAVAM *',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: _validateRenavam,
                ),
                const SizedBox(height: 24),
                if (_found == null)
                  FilledButton.icon(
                    key: const Key('link_search_button'),
                    onPressed: busy ? null : _search,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label:
                        Text(_isSearching ? 'Buscando...' : 'Buscar veículo'),
                  ),
                if (_notFoundMessage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _notFoundMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_found != null && _ownedByAnotherAccount) ...[
                  _foundCard(_found!, theme),
                  const SizedBox(height: 16),
                  _otherAccountCard(theme),
                ],
                if (_found != null && !_ownedByAnotherAccount) ...[
                  _foundCard(_found!, theme),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('link_confirm_button'),
                    onPressed: busy ? null : _link,
                    icon: _isLinking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _isLinking ? 'Vinculando...' : 'Vincular à minha conta',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se os dados não conferirem com o documento, o vínculo é '
                    'recusado.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otherAccountCard(ThemeData theme) {
    return Card(
      key: const Key('link_other_account_card'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Este veículo está em outra conta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Placa e RENAVAM não bastam para tirar o veículo de outra conta. '
              'Se você o comprou, envie o CRLV-e no seu nome: ele confirma a '
              'posse e traz o veículo para a sua conta, com o histórico.',
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('link_send_crlv_button'),
              onPressed: _openCrlvFlow,
              icon: const Icon(Icons.upload_file),
              label: const Text('Enviar CRLV-e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foundCard(Vehicle vehicle, ThemeData theme) {
    final total = vehicle.maintenancesCount ?? 0;
    final verified = vehicle.verifiedMaintenancesCount ?? 0;

    return Card(
      key: const Key('link_found_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            VehicleCoverAvatar(
              coverPhotoUrl: vehicle.coverPhotoUrl,
              coverPhotoPortraitUrl: vehicle.coverPhotoPortraitUrl,
              coverPhotoThumbUrl: vehicle.coverPhotoThumbUrl,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${vehicle.year} · ${vehicle.plateLabel}'),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Nenhuma manutenção registrada'
                        : '$total manutenção(ões) · $verified verificada(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
