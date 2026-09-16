import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/api_service.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import '../../widgets/cover_framing.dart';
import '../../widgets/cover_image_cropper.dart';
import '../../widgets/terms_scroll_acceptance.dart';
import 'package:provider/provider.dart';

class VehicleFormPage extends StatefulWidget {
  final Vehicle? vehicle;

  const VehicleFormPage({super.key, this.vehicle});

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

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _licensePlateController.text = widget.vehicle!.licensePlate;
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
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _chassisController.dispose();
    _engineController.dispose();
    _kilometersController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newPlate = _licensePlateController.text.trim().toUpperCase();
    if (widget.vehicle != null &&
        newPlate != widget.vehicle!.licensePlate.toUpperCase()) {
      final registerChange = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registrar troca de placa?'),
          content: const Text(
            'A placa anterior ficará no histórico.',
          ),
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
        'renavam': _renavamController.text.trim().isEmpty
            ? null
            : _renavamController.text.trim(),
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
      };

      Response response;
      String? vehicleId;

      if (widget.vehicle != null) {
        vehicleId = widget.vehicle!.id.toString();
        if (newPlate != widget.vehicle!.licensePlate.toUpperCase()) {
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
            content: Text(widget.vehicle != null
                ? 'Veículo atualizado com sucesso!'
                : 'Veículo cadastrado com sucesso!'),
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
            content: Text('Erro: ${e.toString()}'),
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
          child: Image.file(
            file,
            fit: BoxFit.cover,
          ),
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
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
          style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                  decoration: const InputDecoration(
                    labelText: 'RENAVAM',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Marca *',
                          prefixIcon: Icon(Icons.directions_car),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira a marca';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Modelo *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira o modelo';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
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
                        maxLength: 4,
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
                          widget.vehicle != null ? 'Atualizar' : 'Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
