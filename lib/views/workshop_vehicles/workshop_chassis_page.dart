import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/workshop_vehicle_lookup.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../widgets/catalog_autocomplete.dart';
import '../maintenances/maintenance_detail_page.dart';
import '../maintenances/maintenance_form_page.dart';

/// Texto de apoio dos campos livres de OS feita sem dono.
const String kNoPersonalDataHelper =
    'Não inclua nome, CPF, telefone ou placa do cliente.';

/// "Carro ainda não está no RevisaLog": a oficina informa o chassi, e o app
/// busca, reaproveita um carro sem dono ou cria um só com chassi, marca,
/// modelo e ano. Nenhum dado do cliente entra aqui.
class WorkshopChassisPage extends StatefulWidget {
  const WorkshopChassisPage({super.key});

  @override
  State<WorkshopChassisPage> createState() => _WorkshopChassisPageState();
}

class _WorkshopChassisPageState extends State<WorkshopChassisPage> {
  final _chassisFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();
  final _chassisController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _brandFocusNode = FocusNode();
  final _modelFocusNode = FocusNode();

  List<String> _catalogBrands = const [];
  List<String> _catalogModels = const [];
  String? _modelsLoadedForBrand;

  bool _isBusy = false;
  bool _searched = false;
  WorkshopVehicleLookup? _result;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadCatalogBrands();
  }

  @override
  void dispose() {
    _chassisController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _brandFocusNode.dispose();
    _modelFocusNode.dispose();
    super.dispose();
  }

  String get _chassis => _chassisController.text.trim().toUpperCase();

  String? _validateChassis(String? value) {
    final chassis = (value ?? '').trim().toUpperCase();

    if (chassis.length != 17) {
      return 'O chassi deve ter 17 caracteres';
    }
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(chassis)) {
      return 'Chassi inválido (não usa as letras I, O e Q)';
    }

    return null;
  }

  Future<void> _loadCatalogBrands() async {
    try {
      final brands = await context.read<ApiService>().getCatalogBrands();
      if (mounted) {
        setState(() => _catalogBrands = brands);
      }
    } catch (_) {
      // Sem catálogo, os campos aceitam texto livre.
    }
  }

  Future<void> _loadCatalogModels(String brand) async {
    if (brand.isEmpty || _modelsLoadedForBrand == brand) {
      return;
    }
    _modelsLoadedForBrand = brand;

    try {
      final models = await context.read<ApiService>().getCatalogModels(brand);
      if (mounted) {
        setState(() => _catalogModels = models);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _catalogModels = const []);
      }
    }
  }

  void _onBrandSelected(String brand) {
    final previous = _modelsLoadedForBrand;
    if (previous != null && previous != brand) {
      setState(() {
        _catalogModels = const [];
        _modelController.clear();
      });
    }
    _loadCatalogModels(brand);
  }

  void _resetResult() {
    if (!_searched && _result == null && _message == null) {
      return;
    }
    setState(() {
      _searched = false;
      _result = null;
      _message = null;
    });
  }

  Future<void> _lookup() async {
    if (!(_chassisFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isBusy = true;
      _message = null;
      _result = null;
      _searched = false;
    });

    try {
      final response =
          await context.read<ApiService>().lookupWorkshopVehicle(_chassis);
      final result = WorkshopVehicleLookup.fromEnvelope(response.data);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
        _searched = true;
        _result = result;
        if (result.found && result.hasOwner) {
          _message = 'Este carro já está no RevisaLog e tem proprietário. '
              'Registre a OS pelo fluxo normal, buscando o carro pela placa.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _message = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _create() async {
    if (!(_createFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      final response = await context.read<ApiService>().createWorkshopVehicle(
            chassis: _chassis,
            brand: _brandController.text.trim(),
            model: _modelController.text.trim(),
            year: int.parse(_yearController.text.trim()),
          );
      final created = WorkshopVehicleLookup.fromEnvelope(response.data);

      if (!mounted) {
        return;
      }

      setState(() => _isBusy = false);
      await _continueToOrder(created);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      // 409: alguém criou o chassi no meio do caminho; trata como uma busca.
      final conflict = e.response?.statusCode == 409
          ? WorkshopVehicleLookup.fromEnvelope(e.response?.data)
          : null;
      setState(() {
        _isBusy = false;
        if (conflict != null && conflict.found) {
          _result = conflict;
          _message = conflict.hasOwner
              ? 'Este carro já está no RevisaLog e tem proprietário. '
                  'Registre a OS pelo fluxo normal, buscando o carro pela placa.'
              : null;
        } else {
          _message = apiErrorMessage(e);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _message = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _continueToOrder(WorkshopVehicleLookup vehicle) async {
    if (vehicle.id == null) {
      setState(() => _message = 'Não foi possível identificar o carro.');
      return;
    }

    int? createdMaintenanceId;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaintenanceFormPage(
          vehicleId: vehicle.id!,
          isOwnerlessVehicle: true,
          onCreated: (id) => createdMaintenanceId = id,
        ),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    // A oficina não tem lista de veículos no app: abre a OS recém-criada, onde fica o cartão
    // "Avisar o cliente", antes de voltar para o início.
    if (createdMaintenanceId != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              MaintenanceDetailPage(maintenanceId: createdMaintenanceId!),
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final notFound = _searched && result != null && !result.found;

    return Scaffold(
      appBar: AppBar(title: const Text('Carro novo no RevisaLog')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Registre a OS pelo chassi, sem dados do cliente. Depois '
                'você pode avisar o cliente para ele assumir o carro.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _chassisFormKey,
                child: TextFormField(
                  key: const Key('workshop_chassis_field'),
                  controller: _chassisController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Chassi (17 caracteres) *',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(17),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  validator: _validateChassis,
                  onChanged: (_) => _resetResult(),
                ),
              ),
              const SizedBox(height: 16),
              if (!_searched)
                FilledButton.icon(
                  key: const Key('workshop_chassis_search'),
                  onPressed: _isBusy ? null : _lookup,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isBusy ? 'Buscando...' : 'Buscar chassi'),
                ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Card(
                  key: const Key('workshop_chassis_message'),
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _message!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ],
              if (result != null && result.isOwnerless) _ownerlessCard(result),
              if (notFound) _createForm(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerlessCard(WorkshopVehicleLookup vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('workshop_chassis_found_card'),
          child: ListTile(
            leading: const Icon(Icons.directions_car),
            title: Text(vehicle.displayName),
            subtitle: Text(
              [
                if (vehicle.year != null) '${vehicle.year}',
                'Ainda sem proprietário no RevisaLog',
              ].join(' · '),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('workshop_chassis_use'),
          onPressed: _isBusy ? null : () => _continueToOrder(vehicle),
          icon: const Icon(Icons.build),
          label: const Text('Registrar OS neste carro'),
        ),
      ],
    );
  }

  Widget _createForm(ThemeData theme) {
    return Form(
      key: _createFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chassi não encontrado. Informe os dados do carro para criá-lo.',
            key: const Key('workshop_chassis_not_found'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          CatalogAutocomplete(
            key: const Key('workshop_brand_field'),
            controller: _brandController,
            focusNode: _brandFocusNode,
            options: _catalogBrands,
            onSelected: _onBrandSelected,
            enabled: !_isBusy,
            decoration: const InputDecoration(
              labelText: 'Marca *',
              prefixIcon: Icon(Icons.directions_car),
              border: OutlineInputBorder(),
            ),
            requiredMessage: 'Por favor, selecione a marca',
            invalidMessage: 'Escolha uma marca da lista',
          ),
          const SizedBox(height: 12),
          CatalogAutocomplete(
            key: const Key('workshop_model_field'),
            controller: _modelController,
            focusNode: _modelFocusNode,
            options: _catalogModels,
            enabled: !_isBusy,
            decoration: const InputDecoration(
              labelText: 'Modelo *',
              border: OutlineInputBorder(),
            ),
            requiredMessage: 'Por favor, selecione o modelo',
            invalidMessage: 'Escolha um modelo da lista',
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('workshop_year_field'),
            controller: _yearController,
            enabled: !_isBusy,
            decoration: const InputDecoration(
              labelText: 'Ano do modelo *',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (value) {
              final year = int.tryParse((value ?? '').trim());
              if (year == null ||
                  year < 1900 ||
                  year > DateTime.now().year + 1) {
                return 'Informe um ano válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('workshop_create_vehicle'),
            onPressed: _isBusy ? null : _create,
            icon: const Icon(Icons.add),
            label: Text(_isBusy ? 'Criando...' : 'Criar e continuar a OS'),
          ),
        ],
      ),
    );
  }
}
