import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';
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
  bool _isLoading = false;

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
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final vehicleData = {
        'license_plate': _licensePlateController.text.trim().toUpperCase(),
        'renavam': _renavamController.text.trim().isEmpty
            ? null
            : _renavamController.text.trim(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.parse(_yearController.text.trim()),
        'color': _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        'chassis': _chassisController.text.trim().isEmpty
            ? null
            : _chassisController.text.trim(),
        'engine': _engineController.text.trim().isEmpty
            ? null
            : _engineController.text.trim(),
      };

      Response response;
      if (widget.vehicle != null) {
        response = await apiService.updateVehicle(
          widget.vehicle!.id.toString(),
          vehicleData,
        );
      } else {
        response = await apiService.createVehicle(vehicleData);
      }

      if (response.data['success'] == true && mounted) {
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
                TextFormField(
                  controller: _licensePlateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                    helperText: 'Ex: ABC1234',
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
                          if (year == null || year < 1900 || year > DateTime.now().year + 1) {
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
                  controller: _chassisController,
                  decoration: const InputDecoration(
                    labelText: 'Chassi',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                  ),
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
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.vehicle != null ? 'Atualizar' : 'Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

