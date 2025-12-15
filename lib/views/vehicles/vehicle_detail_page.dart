import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';
import 'vehicle_form_page.dart';
import '../maintenances/maintenance_form_page.dart';
import '../maintenances/maintenance_list_page.dart';

class VehicleDetailPage extends StatefulWidget {
  final int vehicleId;

  const VehicleDetailPage({super.key, required this.vehicleId});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  Vehicle? _vehicle;
  bool _isLoading = true;
  int _maintenanceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getVehicle(widget.vehicleId.toString());

      if (response.data['success'] == true && mounted) {
        setState(() {
          _vehicle = Vehicle.fromJson(response.data['data']);
          _maintenanceCount = _vehicle?.maintenances?.length ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar veículo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este veículo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteVehicle(widget.vehicleId.toString());

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir veículo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleExportPdf() async {
    ScaffoldMessengerState? messenger;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Show loading indicator
      if (mounted) {
        messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Gerando PDF...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Download PDF with binary response
      final response = await apiService.dio.get(
        '/vehicles/${widget.vehicleId}/export-pdf',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // Get documents directory (downloads may not be available on all platforms)
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'historico_manutencoes_${_vehicle?.licensePlate ?? widget.vehicleId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Write the file
      await file.writeAsBytes(response.data);

      // Close loading snackbar
      if (mounted && messenger != null) {
        messenger.hideCurrentSnackBar();
      }

      // Open the file
      final uri = Uri.file(filePath);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF salvo em: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF salvo em: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading snackbar on error
      if (mounted && messenger != null) {
        messenger.hideCurrentSnackBar();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do Veículo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do Veículo')),
        body: const Center(child: Text('Veículo não encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Veículo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehicleFormPage(vehicle: _vehicle),
                ),
              );
              if (result == true) {
                _loadVehicle();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVehicle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _vehicle!.displayName,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Placa: ${_vehicle!.licensePlate}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildInfoRow('Ano', _vehicle!.year.toString()),
                      if (_vehicle!.color != null)
                        _buildInfoRow('Cor', _vehicle!.color!),
                      if (_vehicle!.renavam != null)
                        _buildInfoRow('RENAVAM', _vehicle!.renavam!),
                      if (_vehicle!.chassis != null)
                        _buildInfoRow('Chassi', _vehicle!.chassis!),
                      if (_vehicle!.engine != null)
                        _buildInfoRow('Motor', _vehicle!.engine!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.build),
                      title: const Text('Manutenções'),
                      subtitle: Text('$_maintenanceCount registro(s)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MaintenanceListPage(vehicleId: widget.vehicleId),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_circle),
                      title: const Text('Nova Manutenção'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MaintenanceFormPage(vehicleId: widget.vehicleId),
                          ),
                        );
                        if (result == true) {
                          _loadVehicle();
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: const Text('Exportar PDF'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _handleExportPdf,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MaintenanceFormPage(vehicleId: widget.vehicleId),
            ),
          );
          if (result == true) {
            _loadVehicle();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

