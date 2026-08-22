import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../models/maintenance.dart';
import '../../models/maintenance_item.dart';
import '../../models/workshop.dart';
import '../../services/api_service.dart';
import 'maintenance_item_form_dialog.dart';
import '../workshops/workshop_search_page.dart';

class MaintenanceFormPage extends StatefulWidget {
  final int vehicleId;
  final Maintenance? maintenance;

  const MaintenanceFormPage({
    super.key,
    required this.vehicleId,
    this.maintenance,
  });

  @override
  State<MaintenanceFormPage> createState() => _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends State<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _workshopNameController = TextEditingController();
  final _kilometersController = TextEditingController();

  String _maintenanceType = 'preventive';
  String? _serviceCategory;
  DateTime _maintenanceDate = DateTime.now();
  bool _isManufacturerRequired = false;
  bool _isLoading = false;
  int? _minKilometers;
  List<MaintenanceItem> _items = [];
  List<String> _invoiceFiles = [];
  Workshop? _selectedWorkshop;

  final List<String> _maintenanceTypes = [
    'preventive',
    'corrective',
    'inspection',
    'other',
  ];

  final List<String> _serviceCategories = [
    'mechanical',
    'electrical',
    'suspension',
    'painting',
    'finishing',
    'interior',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.maintenance != null) {
      _descriptionController.text = widget.maintenance!.description ?? '';
      _workshopNameController.text = widget.maintenance!.workshopName ?? '';
      _kilometersController.text =
          widget.maintenance!.kilometers?.toString() ?? '';
      _maintenanceType = widget.maintenance!.maintenanceType;
      _serviceCategory = widget.maintenance!.serviceCategory;
      _maintenanceDate = widget.maintenance!.maintenanceDate;
      _isManufacturerRequired =
          widget.maintenance!.isManufacturerRequired ?? false;
      _items = widget.maintenance!.items ?? [];
      if (widget.maintenance!.workshopId != null) {
        _loadWorkshop(widget.maintenance!.workshopId!);
      }
    }

    _loadVehicleKilometers();
  }

  Future<void> _loadVehicleKilometers() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response =
          await apiService.getVehicle(widget.vehicleId.toString());

      if (response.data['success'] == true && mounted) {
        final currentKm = response.data['data']['current_kilometers'];
        setState(() {
          _minKilometers = currentKm is int ? currentKm : int.tryParse('$currentKm');
          if (widget.maintenance == null &&
              _kilometersController.text.isEmpty &&
              _minKilometers != null) {
            _kilometersController.text = _minKilometers.toString();
          }
        });
      }
    } catch (_) {
      // Keep form usable even if vehicle fetch fails.
    }
  }

  Future<void> _loadWorkshop(int workshopId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getWorkshop(workshopId.toString());
      if (response.data['success'] == true) {
        setState(() {
          _selectedWorkshop = Workshop.fromJson(response.data['data']);
          _workshopNameController.text = _selectedWorkshop!.name;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _selectWorkshop() async {
    final workshop = await Navigator.push<Workshop>(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkshopSearchPage(
          allowCreate: true,
        ),
      ),
    );

    if (workshop != null) {
      setState(() {
        _selectedWorkshop = workshop;
        _workshopNameController.text = workshop.name;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _workshopNameController.dispose();
    _kilometersController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _maintenanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _maintenanceDate = picked;
      });
    }
  }

  Future<void> _addItem() async {
    final item = await showDialog<MaintenanceItem>(
      context: context,
      builder: (_) => MaintenanceItemFormDialog(),
    );

    if (item != null) {
      setState(() {
        _items.add(item);
      });
    }
  }

  void _editItem(int index) async {
    final item = await showDialog<MaintenanceItem>(
      context: context,
      builder: (_) => MaintenanceItemFormDialog(item: _items[index]),
    );

    if (item != null) {
      setState(() {
        _items[index] = item;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _pickInvoiceFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _invoiceFiles = result.files
              .map((f) => f.path!)
              .where((p) => p.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar arquivos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

      // Ensure service_category is not null (it's required)
      if (_serviceCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma categoria de serviço'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final formData = FormData.fromMap({
        'vehicle_id': widget.vehicleId,
        'workshop_id': _selectedWorkshop?.id,
        'maintenance_type': _maintenanceType,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'workshop_name': _workshopNameController.text.trim().isEmpty
            ? null
            : _workshopNameController.text.trim(),
        'maintenance_date': _maintenanceDate.toIso8601String().split('T')[0],
        'kilometers': int.parse(_kilometersController.text.trim()),
        'service_category': _serviceCategory!,
        'is_manufacturer_required': _isManufacturerRequired
            ? 1
            : 0, // Send as int to ensure boolean conversion
        'items': _items.map((item) => item.toJson()).toList(),
      });

      // Add invoice files
      for (var filePath in _invoiceFiles) {
        formData.files.add(
          MapEntry(
            'invoices[]',
            await MultipartFile.fromFile(filePath),
          ),
        );
      }

      Response response;
      if (widget.maintenance != null) {
        // For update, convert FormData to regular map
        if (_serviceCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, selecione uma categoria de serviço'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final updateData = {
          'vehicle_id': widget.vehicleId,
          'maintenance_type': _maintenanceType,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'workshop_name': _workshopNameController.text.trim().isEmpty
              ? null
              : _workshopNameController.text.trim(),
          'maintenance_date': _maintenanceDate.toIso8601String().split('T')[0],
          'kilometers': int.parse(_kilometersController.text.trim()),
          'service_category': _serviceCategory!,
          'is_manufacturer_required': _isManufacturerRequired,
          'items': _items.map((item) => item.toJson()).toList(),
        };
        response = await apiService.updateMaintenance(
          widget.maintenance!.id.toString(),
          updateData,
        );
      } else {
        response = await apiService.createMaintenance(formData);
      }

      if (response.data['success'] == true && mounted) {
        // Show success message before popping
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.maintenance != null
                ? 'Manutenção atualizada com sucesso!'
                : 'Manutenção registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop and return true to trigger list refresh
        Navigator.of(context).pop(true);
      } else {
        throw Exception(
            response.data['message'] ?? 'Erro ao salvar manutenção');
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
        title: Text(widget.maintenance != null
            ? 'Editar Manutenção'
            : 'Nova Manutenção'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _maintenanceType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Manutenção *',
                    prefixIcon: Icon(Icons.build),
                    border: OutlineInputBorder(),
                  ),
                  items: _maintenanceTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getMaintenanceTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _maintenanceType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data da Manutenção *',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      '${_maintenanceDate.day}/${_maintenanceDate.month}/${_maintenanceDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kilometersController,
                  decoration: InputDecoration(
                    labelText: 'Quilometragem *',
                    prefixIcon: const Icon(Icons.speed),
                    border: const OutlineInputBorder(),
                    helperText: _minKilometers == null
                        ? 'Informe o hodômetro nesta manutenção.'
                        : 'Hodômetro atual: $_minKilometers km. Informe um valor igual ou maior.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a quilometragem';
                    }
                    final km = int.tryParse(value.trim());
                    if (km == null || km < 0) {
                      return 'Quilometragem inválida';
                    }
                    if (_minKilometers != null && km < _minKilometers!) {
                      return 'A quilometragem deve ser no mínimo $_minKilometers km';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _serviceCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoria de Serviço',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: _serviceCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getServiceCategoryLabel(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _serviceCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Oficina
                InkWell(
                  onTap: _selectWorkshop,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Oficina',
                      prefixIcon: const Icon(Icons.build_circle),
                      suffixIcon: _selectedWorkshop != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedWorkshop = null;
                                  _workshopNameController.clear();
                                });
                              },
                            )
                          : const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      helperText: _selectedWorkshop != null
                          ? 'Toque para trocar de oficina'
                          : 'Toque para buscar ou adicionar oficina',
                    ),
                    child: Text(
                      _selectedWorkshop != null
                          ? _selectedWorkshop!.name
                          : _workshopNameController.text.isEmpty
                              ? 'Buscar oficina...'
                              : _workshopNameController.text,
                      style: TextStyle(
                        color: _selectedWorkshop != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_selectedWorkshop != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _selectedWorkshop!.shortAddress,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Manutenção exigida pelo fabricante'),
                  value: _isManufacturerRequired,
                  onChanged: (value) {
                    setState(() {
                      _isManufacturerRequired = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Item'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickInvoiceFiles,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Notas Fiscais'),
                      ),
                    ),
                  ],
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Itens da Manutenção (${_items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.quantity}x - R\$ ${item.totalPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeItem(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                if (_invoiceFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Notas Fiscais (${_invoiceFiles.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._invoiceFiles.map((filePath) {
                    final fileName = filePath.split('/').last;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(fileName),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _invoiceFiles.remove(filePath);
                            });
                          },
                        ),
                      ),
                    );
                  }),
                ],
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
                      : Text(
                          widget.maintenance != null ? 'Atualizar' : 'Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMaintenanceTypeLabel(String type) {
    switch (type) {
      case 'preventive':
        return 'Preventiva';
      case 'corrective':
        return 'Corretiva';
      case 'inspection':
        return 'Inspeção';
      case 'other':
        return 'Outra';
      default:
        return type;
    }
  }

  String _getServiceCategoryLabel(String category) {
    switch (category) {
      case 'mechanical':
        return 'Mecânica';
      case 'electrical':
        return 'Elétrica';
      case 'suspension':
        return 'Suspensão';
      case 'painting':
        return 'Pintura';
      case 'finishing':
        return 'Acabamento';
      case 'interior':
        return 'Interior';
      default:
        return category;
    }
  }
}
