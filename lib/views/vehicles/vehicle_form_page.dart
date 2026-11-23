import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/crlv_reading.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import '../../widgets/catalog_autocomplete.dart';
import '../../widgets/cover_framing.dart';
import '../../widgets/cover_image_cropper.dart';
import '../../widgets/terms_scroll_acceptance.dart';
import 'package:provider/provider.dart';

/// Escolhe o PDF do CRLV-e e devolve o caminho, ou null se a pessoa desistir.
typedef CrlvPdfPicker = Future<String?> Function();

Future<String?> _pickCrlvPdfFromDevice() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  return result?.files.single.path;
}

class VehicleFormPage extends StatefulWidget {
  final Vehicle? vehicle;

  /// Trocável nos testes; no app abre o seletor de arquivos do sistema.
  final CrlvPdfPicker pickCrlvPdf;

  const VehicleFormPage({
    super.key,
    this.vehicle,
    this.pickCrlvPdf = _pickCrlvPdfFromDevice,
  });

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _renavamController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _chassisController = TextEditingController();
  final _engineController = TextEditingController();
  final _kilometersController = TextEditingController();
  bool _isLoading = false;
  bool _termsAccepted = false;
  String _termsContent = '';
  bool _loadingTerms = false;
  final ImagePicker _picker = ImagePicker();
  final CoverImageCropper _coverCropper = CoverImageCropper();
  File? _coverLandscapeFile;
  File? _coverPortraitFile;
  String? _existingLandscapeUrl;
  String? _existingPortraitUrl;

  final _brandFocusNode = FocusNode();
  final _modelFocusNode = FocusNode();

  /// Sugestões do catálogo. Vazias enquanto carregam ou se a requisição falhar:
  /// os campos continuam aceitando texto livre, porque o catálogo não cobre
  /// todo modelo novo ou importado e o backend aceita qualquer string.
  List<String> _catalogBrands = const [];
  List<String> _catalogModels = const [];

  /// Marca cujos modelos já estão em `_catalogModels`, para não repetir a busca.
  String? _modelsLoadedForBrand;

  bool _hasBrandText = false;

  /// CRLV-e lido pelo servidor para este cadastro. Enquanto existir, placa e
  /// RENAVAM vêm dele e ficam travados: o backend confere os dois contra o
  /// documento, e o token que vai no cadastro verifica a posse.
  CrlvReading? _crlv;
  bool _readingCrlv = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogBrands();
    if (widget.vehicle != null) {
      _licensePlateController.text = widget.vehicle!.licensePlate ?? '';
      _renavamController.text = widget.vehicle!.renavam ?? '';
      _brandController.text = widget.vehicle!.brand;
      _modelController.text = widget.vehicle!.model;
      _yearController.text = widget.vehicle!.year.toString();
      _colorController.text = widget.vehicle!.color ?? '';
      _chassisController.text = widget.vehicle!.chassis ?? '';
      _engineController.text = widget.vehicle!.engine ?? '';
      _existingLandscapeUrl = widget.vehicle!.coverPhotoUrl;
      _existingPortraitUrl = widget.vehicle!.coverPhotoPortraitUrl;
      if (widget.vehicle!.currentKilometers != null) {
        _kilometersController.text =
            widget.vehicle!.currentKilometers.toString();
      }
    } else {
      _loadTerms();
    }

    _hasBrandText = _brandController.text.trim().isNotEmpty;
    _brandController.addListener(_onBrandTextChanged);

    // Editando: já há marca, então os modelos dela podem vir junto.
    if (_hasBrandText) {
      _loadCatalogModels(_brandController.text.trim());
    }
  }

  /// O campo de modelo liga e desliga conforme a marca. Reconstrói só na virada
  /// entre vazio e preenchido, não a cada tecla.
  void _onBrandTextChanged() {
    final hasText = _brandController.text.trim().isNotEmpty;

    if (hasText != _hasBrandText) {
      setState(() => _hasBrandText = hasText);
    }
  }

  /// Falha silenciosa de propósito: sem sugestões o formulário ainda funciona, e
  /// um erro aqui não deve atrapalhar quem está cadastrando.
  Future<void> _loadCatalogBrands() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final brands = await apiService.getCatalogBrands();

      if (mounted) {
        setState(() => _catalogBrands = brands);
      }
    } catch (_) {
      // Sem catálogo: marca e modelo seguem como texto livre.
    }
  }

  Future<void> _loadCatalogModels(String brand) async {
    if (brand.isEmpty || _modelsLoadedForBrand == brand) {
      return;
    }

    _modelsLoadedForBrand = brand;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final models = await apiService.getCatalogModels(brand);

      if (mounted) {
        setState(() => _catalogModels = models);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _catalogModels = const []);
      }
    }
  }

  /// Chamado quando a marca é escolhida na lista: o nome vem canônico, que é o
  /// que o endpoint de modelos espera (ele resolve por chave exata).
  void _onBrandSelected(String brand) {
    final previous = _modelsLoadedForBrand;

    if (previous != null && previous != brand) {
      // Trocou de marca: o modelo escolhido era de outra e não vale mais, como
      // no portal web, que repovoa o select de modelo a cada troca.
      setState(() {
        _catalogModels = const [];
        _modelController.clear();
      });
    }

    _loadCatalogModels(brand);
  }

  /// O catálogo é curado e pode ter perdido uma marca ou modelo que algum
  /// veículo já usa. Nesse caso o valor atual entra na lista, como o web faz,
  /// para a edição não ficar impossível.
  List<String> _withCurrentValue(List<String> options, String current) {
    final value = current.trim();

    if (value.isEmpty || options.isEmpty || options.contains(value)) {
      return options;
    }

    return [value, ...options];
  }

  Future<void> _loadTerms() async {
    setState(() {
      _loadingTerms = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getTermsOfUse();
      if (response.data['success'] == true && mounted) {
        setState(() {
          _termsContent = response.data['data']['content']?.toString() ?? '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _termsContent =
              'Ao cadastrar o veículo, você declara que as informações são verdadeiras e de sua responsabilidade.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTerms = false;
        });
      }
    }
  }

  Future<void> _pickLandscapeCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked == null || !mounted) {
      return;
    }

    final cropped = await _coverCropper.cropLandscape(picked.path);
    if (cropped != null && mounted) {
      setState(() {
        _coverLandscapeFile = cropped;
      });
    }
  }

  Future<void> _pickPortraitCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked == null || !mounted) {
      return;
    }

    final cropped = await _coverCropper.cropPortrait(picked.path);
    if (cropped != null && mounted) {
      setState(() {
        _coverPortraitFile = cropped;
      });
    }
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _renavamController.dispose();
    _brandController.removeListener(_onBrandTextChanged);
    _brandFocusNode.dispose();
    _modelFocusNode.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _chassisController.dispose();
    _engineController.dispose();
    _kilometersController.dispose();
    super.dispose();
  }

  /// O backend exige RENAVAM nos dois casos, e o campo não tinha validator — dava
  /// para salvar vazio e receber um 422. No cadastro exige 9 a 11 dígitos (carros antigos têm 9), como o
  /// portal web; na edição só exige não-vazio, porque a API aceitou
  /// `max:20` por um tempo e enforcar o formato travaria esses valores antigos.
  String? _validateRenavam(String? value) {
    final renavam = value?.trim() ?? '';

    if (renavam.isEmpty) {
      return 'RENAVAM é obrigatório';
    }

    if (widget.vehicle == null && !RegExp(r'^\d{9,11}$').hasMatch(renavam)) {
      return 'RENAVAM deve ter de 9 a 11 dígitos';
    }

    return null;
  }

  /// Carro criado por oficina não tinha placa: informá-la agora não é troca.
  bool _plateChanged(String newPlate) {
    final current = widget.vehicle?.licensePlate?.toUpperCase() ?? '';

    return widget.vehicle != null && current.isNotEmpty && newPlate != current;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newPlate = _licensePlateController.text.trim().toUpperCase();
    if (_plateChanged(newPlate)) {
      final registerChange = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registrar troca de placa?'),
          content: const Text('A placa anterior ficará no histórico.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      );
      if (registerChange != true) {
        return;
      }
    }

    if (widget.vehicle == null && !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leia e aceite os termos de uso para continuar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final vehicleData = {
        'license_plate': newPlate,
        // Nunca `null`: a regra é `sometimes|required`, então mandar a chave
        // vazia fazia a edição falhar com 422 em vez de deixar o valor como está.
        'renavam': _renavamController.text.trim(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.parse(_yearController.text.trim()),
        'color': _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        'chassis': _chassisController.text.trim().toUpperCase(),
        'engine': _engineController.text.trim().isEmpty
            ? null
            : _engineController.text.trim(),
        'current_kilometers': int.parse(_kilometersController.text.trim()),
        if (widget.vehicle == null) 'terms_accepted': true,
        if (widget.vehicle == null && _crlv != null)
          'crlv_verification_token': _crlv!.verificationToken,
      };

      Response response;
      String? vehicleId;

      if (widget.vehicle != null) {
        vehicleId = widget.vehicle!.id.toString();
        if (_plateChanged(newPlate)) {
          vehicleData['plate_changed_at'] =
              DateTime.now().toUtc().toIso8601String();
        }
        response = await apiService.updateVehicle(vehicleId, vehicleData);
      } else {
        response = await apiService.createVehicle(vehicleData);
        if (response.data['data']?['id'] != null) {
          vehicleId = response.data['data']['id'].toString();
        }
      }

      if (response.data['success'] == true &&
          vehicleId != null &&
          (_coverLandscapeFile != null || _coverPortraitFile != null)) {
        await apiService.uploadVehicleCover(
          vehicleId,
          landscape: _coverLandscapeFile,
          portrait: _coverPortraitFile,
        );
      }

      if (response.data['success'] == true && mounted) {
        await context.read<VehicleRepository>().invalidate();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehicle != null
                  ? 'Veículo atualizado com sucesso!'
                  : _crlv != null
                      ? 'Veículo cadastrado com o CRLV-e. A posse está confirmada.'
                      : 'Veículo cadastrado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.data['message'] ?? 'Erro ao salvar veículo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndReadCrlv() async {
    final String? path;

    try {
      path = await widget.pickCrlvPdf();
    } catch (e) {
      _showError('Não foi possível abrir o arquivo: $e');
      return;
    }

    if (path == null || path.isEmpty || !mounted) {
      return;
    }

    setState(() => _readingCrlv = true);

    final CrlvReading reading;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.readCrlv(path);
      final data = response.data['data'];

      if (response.data['success'] != true || data is! Map) {
        throw Exception(
            response.data['message'] ?? 'Não foi possível ler o CRLV-e.');
      }

      reading = CrlvReading.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _showError(apiErrorMessage(e));
      return;
    } finally {
      if (mounted) {
        setState(() => _readingCrlv = false);
      }
    }

    if (!mounted) return;

    try {
      switch (reading.mode) {
        case CrlvReadingMode.linked:
          _showInfo('Este veículo já está na sua conta.');
        case CrlvReadingMode.claim:
          await _offerClaim(reading);
        case CrlvReadingMode.newVehicle:
          if (reading.needsPowerOfAttorney) {
            await _showPowerOfAttorneyNotice();
          } else {
            _applyCrlv(reading);
          }
      }
    } catch (e) {
      _showError(apiErrorMessage(e));
    }
  }

  /// Preenche o formulário com o que o servidor leu. Quilometragem, capas e o
  /// aceite dos termos continuam com a pessoa: o CRLV-e não traz.
  void _applyCrlv(CrlvReading reading) {
    setState(() {
      _crlv = reading;
      _licensePlateController.text = reading.licensePlate;
      _renavamController.text = reading.renavam;
      _chassisController.text = reading.chassis ?? _chassisController.text;
      _brandController.text = reading.brand;
      _modelController.text = reading.model;
      if (reading.year != null) {
        _yearController.text = reading.year.toString();
      }
      _colorController.text = reading.color ?? _colorController.text;
      _engineController.text = reading.engine ?? _engineController.text;
    });

    _onBrandSelected(reading.brand);
  }

  void _clearCrlv() {
    setState(() => _crlv = null);
  }

  Future<void> _offerClaim(CrlvReading reading) async {
    if (reading.needsPowerOfAttorney) {
      await _showPowerOfAttorneyNotice();
      return;
    }

    final existing = reading.existingVehicle;
    final count = existing?.maintenancesCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Este veículo já está na RevisaLog'),
        content: Text(
          '${existing?.title ?? 'Veículo'}'
          '${count > 0 ? ' com $count ${count == 1 ? 'manutenção registrada' : 'manutenções registradas'}' : ''}. '
          'O CRLV-e confirma que ele é seu: vincule-o à sua conta para continuar o histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.claimVehicleWithCrlv(
      reading.verificationToken,
    );

    if (response.data['success'] != true) {
      throw Exception(
        response.data['message'] ?? 'Não foi possível vincular o veículo.',
      );
    }

    final pending = response.data['data']?['pending_workshop_records_count'];
    if (!mounted) return;

    await context.read<VehicleRepository>().invalidate();
    if (!mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending is int && pending > 0
              ? 'Veículo vinculado. Oficinas registraram serviços nele: veja em Registros de oficinas.'
              : 'Veículo vinculado à sua conta.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showPowerOfAttorneyNotice() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termine pelo site'),
        content: const Text(
          'O CRLV-e não está no CPF/CNPJ da sua conta, então este veículo precisa '
          'de procuração. Termine o cadastro pelo site da RevisaLog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _crlvSection() {
    final theme = Theme.of(context);
    final reading = _crlv;

    return Card(
      key: const Key('vehicle_crlv_section'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  reading == null ? Icons.description_outlined : Icons.verified,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reading == null
                        ? 'Cadastre com o CRLV-e'
                        : 'Dados lidos do CRLV-e',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reading == null
                  ? 'Envie o PDF do CRLV-e digital (app Carteira Digital de '
                      'Trânsito) e preenchemos os dados. Com ele, a posse do '
                      'veículo fica confirmada.'
                  : 'Confira os dados, informe a quilometragem e aceite os '
                      'termos. Placa e RENAVAM vêm do documento.'
                      '${reading.brandMatched && reading.modelMatched ? '' : ' Confira a marca e o modelo: não achamos no catálogo exatamente o que está no documento.'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (reading == null)
              FilledButton.icon(
                key: const Key('vehicle_crlv_pick'),
                onPressed: _readingCrlv || _isLoading ? null : _pickAndReadCrlv,
                icon: _readingCrlv
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _readingCrlv ? 'Lendo o CRLV-e…' : 'Enviar CRLV-e (PDF)',
                ),
              )
            else
              OutlinedButton.icon(
                key: const Key('vehicle_crlv_clear'),
                onPressed: _isLoading ? null : _clearCrlv,
                icon: const Icon(Icons.close),
                label: const Text('Preencher sem o CRLV-e'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _coverPreview({
    required File? file,
    required String? existingUrl,
    required double aspectRatio,
    required double fallbackSize,
  }) {
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Image.file(file, fit: BoxFit.cover),
        ),
      );
    }

    return VehicleCoverAvatar(
      coverPhotoUrl: existingUrl,
      coverPhotoPortraitUrl: existingUrl,
      size: fallbackSize,
      borderRadius: 12,
    );
  }

  Widget _coverSection({
    required String title,
    required String pickLabel,
    required String hint,
    required File? file,
    required String? existingUrl,
    required double aspectRatio,
    required VoidCallback onPick,
  }) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: _coverPreview(
            file: file,
            existingUrl: existingUrl,
            aspectRatio: aspectRatio,
            fallbackSize: aspectRatio >= 1 ? 160 : 120,
          ),
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.crop),
          label: Text(pickLabel),
        ),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle != null ? 'Editar Veículo' : 'Novo Veículo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.vehicle == null) ...[
                  _crlvSection(),
                  const SizedBox(height: 24),
                ],
                _coverSection(
                  title: 'Capa paisagem (celular deitado)',
                  pickLabel: CoverFramingLandscape.pickLabel,
                  hint: CoverFramingLandscape.hint,
                  file: _coverLandscapeFile,
                  existingUrl: _existingLandscapeUrl,
                  aspectRatio: CoverFramingLandscape.aspectRatio,
                  onPick: _pickLandscapeCover,
                ),
                const SizedBox(height: 24),
                _coverSection(
                  title: 'Capa retrato (celular em pé)',
                  pickLabel: CoverFramingPortrait.pickLabel,
                  hint: CoverFramingPortrait.hint,
                  file: _coverPortraitFile,
                  existingUrl: _existingPortraitUrl ?? _existingLandscapeUrl,
                  aspectRatio: CoverFramingPortrait.aspectRatio,
                  onPick: _pickPortraitCover,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('vehicle_chassis_field'),
                  controller: _chassisController,
                  decoration: const InputDecoration(
                    labelText: 'Chassi *',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                    helperText:
                        'O chassi identifica o veículo para sempre. A placa pode mudar.',
                    helperMaxLines: 2,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 17,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o chassi';
                    }
                    final len = value.trim().length;
                    final year = int.tryParse(_yearController.text.trim());
                    final minLen = year != null && year < 1990 ? 9 : 17;
                    if (len < minLen) {
                      return minLen == 17
                          ? 'Chassi deve ter 17 caracteres'
                          : 'Chassi deve ter entre 9 e 17 caracteres';
                    }
                    if (len > 17) {
                      return 'Chassi deve ter no máximo 17 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licensePlateController,
                  readOnly: _crlv != null,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                    helperText: 'Placa atual',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 7,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira a placa';
                    }
                    if (value.length < 7) {
                      return 'Placa deve ter 7 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _renavamController,
                  readOnly: _crlv != null,
                  decoration: const InputDecoration(
                    labelText: 'RENAVAM *',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateRenavam,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CatalogAutocomplete(
                        key: const Key('vehicle_brand_field'),
                        controller: _brandController,
                        focusNode: _brandFocusNode,
                        options: _withCurrentValue(
                          _catalogBrands,
                          widget.vehicle?.brand ?? '',
                        ),
                        onSelected: _onBrandSelected,
                        decoration: const InputDecoration(
                          labelText: 'Marca *',
                          prefixIcon: Icon(Icons.directions_car),
                          border: OutlineInputBorder(),
                        ),
                        requiredMessage: 'Por favor, selecione a marca',
                        invalidMessage: 'Escolha uma marca da lista',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: CatalogAutocomplete(
                        key: const Key('vehicle_model_field'),
                        controller: _modelController,
                        focusNode: _modelFocusNode,
                        options: _withCurrentValue(
                          _catalogModels,
                          widget.vehicle?.model ?? '',
                        ),
                        // Como no web: sem marca não há lista de modelo.
                        enabled: _hasBrandText,
                        decoration: InputDecoration(
                          labelText: 'Modelo *',
                          border: const OutlineInputBorder(),
                          hintText: !_hasBrandText
                              ? 'Selecione a marca primeiro'
                              : null,
                        ),
                        requiredMessage: 'Por favor, selecione o modelo',
                        invalidMessage: 'Escolha um modelo da lista',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'Ano *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        // Sem maxLength: o contador "0/4" deixava o Ano mais
                        // alto que o Cor ao lado e desalinhava a linha.
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira o ano';
                          }
                          final year = int.tryParse(value);
                          if (year == null ||
                              year < 1900 ||
                              year > DateTime.now().year + 1) {
                            return 'Ano inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Cor',
                          prefixIcon: Icon(Icons.palette),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _engineController,
                  decoration: const InputDecoration(
                    labelText: 'Motor',
                    prefixIcon: Icon(Icons.settings),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kilometersController,
                  decoration: InputDecoration(
                    labelText: widget.vehicle == null
                        ? 'Quilometragem atual *'
                        : 'Quilometragem atual',
                    prefixIcon: const Icon(Icons.speed),
                    border: const OutlineInputBorder(),
                    helperText: 'Informe o hodômetro atual do veículo.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a quilometragem atual';
                    }
                    final km = int.tryParse(value.trim());
                    if (km == null || km < 0) {
                      return 'Quilometragem inválida';
                    }
                    return null;
                  },
                ),
                if (widget.vehicle == null) ...[
                  const SizedBox(height: 16),
                  if (_loadingTerms)
                    const Center(child: CircularProgressIndicator())
                  else if (_termsContent.isNotEmpty)
                    TermsScrollAcceptance(
                      content: _termsContent,
                      onAcceptedChanged: (accepted) {
                        setState(() {
                          _termsAccepted = accepted;
                        });
                      },
                    ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed:
                      _isLoading || (widget.vehicle == null && !_termsAccepted)
                          ? null
                          : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.vehicle != null ? 'Atualizar' : 'Cadastrar',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
