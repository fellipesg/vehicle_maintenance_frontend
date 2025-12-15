import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/maintenance.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../services/api_service.dart';
import 'maintenance_form_page.dart';

class MaintenanceDetailPage extends StatefulWidget {
  final int maintenanceId;

  const MaintenanceDetailPage({super.key, required this.maintenanceId});

  @override
  State<MaintenanceDetailPage> createState() => _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState extends State<MaintenanceDetailPage> {
  Maintenance? _maintenance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenance();
  }

  Future<void> _loadMaintenance() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response =
          await apiService.getMaintenance(widget.maintenanceId.toString());

      if (response.data['success'] == true && mounted) {
        setState(() {
          _maintenance = Maintenance.fromJson(response.data['data']);
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
            content: Text('Erro ao carregar manutenção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewInvoice(Invoice invoice) async {
    ScaffoldMessengerState? messenger;

    try {
      if (invoice.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID da nota fiscal não encontrado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

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
                Text('Baixando nota fiscal...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Download the file using the API service
      final response = await apiService.downloadInvoice(invoice.id.toString());

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${invoice.fileName}';
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir a nota fiscal'),
              backgroundColor: Colors.red,
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
            content: Text('Erro ao abrir nota fiscal: $e'),
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
        appBar: AppBar(title: const Text('Detalhes da Manutenção')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_maintenance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Manutenção')),
        body: const Center(child: Text('Manutenção não encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Manutenção'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MaintenanceFormPage(
                    vehicleId: _maintenance!.vehicleId,
                    maintenance: _maintenance,
                  ),
                ),
              );
              if (result == true) {
                _loadMaintenance();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaintenance,
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
                            _getMaintenanceTypeIcon(
                                _maintenance!.maintenanceType),
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getMaintenanceTypeLabel(
                                      _maintenance!.maintenanceType),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(_maintenance!.maintenanceDate),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      if (_maintenance!.workshopName != null)
                        _buildInfoRow('Oficina', _maintenance!.workshopName!),
                      if (_maintenance!.kilometers != null)
                        _buildInfoRow(
                            'Quilometragem', '${_maintenance!.kilometers} km'),
                      if (_maintenance!.serviceCategory != null)
                        _buildInfoRow(
                          'Categoria',
                          _getServiceCategoryLabel(
                              _maintenance!.serviceCategory!),
                        ),
                      if (_maintenance!.description != null)
                        _buildInfoRow('Descrição', _maintenance!.description!),
                      if (_maintenance!.isManufacturerRequired == true)
                        const Chip(
                          label: Text('Exigida pelo fabricante'),
                          avatar: Icon(Icons.verified, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              if (_maintenance!.items != null &&
                  _maintenance!.items!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Itens da Manutenção',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const Divider(height: 1),
                      ..._maintenance!.items!.map((MaintenanceItem item) {
                        return ListTile(
                          title: Text(item.name),
                          subtitle: item.description != null
                              ? Text(item.description!)
                              : null,
                          trailing: Text(
                            '${item.quantity}x R\$ ${item.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              if (_maintenance!.invoices != null &&
                  _maintenance!.invoices!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Notas Fiscais',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const Divider(height: 1),
                      ..._maintenance!.invoices!.map((Invoice invoice) {
                        return ListTile(
                          leading: const Icon(Icons.picture_as_pdf,
                              color: Colors.red),
                          title: Text(invoice.fileName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (invoice.invoiceNumber != null)
                                Text('Número: ${invoice.invoiceNumber}'),
                              if (invoice.invoiceDate != null)
                                Text(
                                  'Data: ${DateFormat('dd/MM/yyyy').format(invoice.invoiceDate!)}',
                                ),
                              if (invoice.totalAmount != null)
                                Text(
                                  'Valor: R\$ ${invoice.totalAmount!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _viewInvoice(invoice),
                            tooltip: 'Visualizar Nota Fiscal',
                          ),
                          onTap: () => _viewInvoice(invoice),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
            width: 120,
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

  IconData _getMaintenanceTypeIcon(String type) {
    switch (type) {
      case 'preventive':
        return Icons.verified;
      case 'corrective':
        return Icons.build;
      case 'inspection':
        return Icons.search;
      default:
        return Icons.settings;
    }
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
