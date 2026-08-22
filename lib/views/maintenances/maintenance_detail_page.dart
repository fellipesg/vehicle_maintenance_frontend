import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/maintenance.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import 'maintenance_form_page.dart';

class MaintenanceDetailPage extends StatefulWidget {
  final int maintenanceId;

  const MaintenanceDetailPage({super.key, required this.maintenanceId});

  @override
  State<MaintenanceDetailPage> createState() => _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState extends State<MaintenanceDetailPage> {
  Maintenance? _maintenance;
  Vehicle? _vehicle;
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
        final maintenance = Maintenance.fromJson(response.data['data']);
        setState(() {
          _maintenance = maintenance;
          _isLoading = false;
        });
        await _loadVehicle(maintenance.vehicleId);
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

  Future<void> _loadVehicle(int vehicleId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getVehicle(vehicleId.toString());

      if (response.data['success'] == true && mounted) {
        setState(() {
          _vehicle = Vehicle.fromJson(response.data['data']);
        });
      }
    } catch (_) {
      // Cover photo fallback handled by widget.
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

      final response = await apiService.downloadInvoice(invoice.id.toString());

      if (mounted && messenger != null) {
        messenger.hideCurrentSnackBar();
      }

      final bytes = Uint8List.fromList(List<int>.from(response.data as List<int>));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_safePdfFileName(invoice)}');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'Não foi possível abrir o PDF neste aparelho.',
            ),
            backgroundColor: Colors.red,
          ),
        );
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          VehicleCoverAvatar(
                            coverPhotoUrl: _vehicle?.coverPhotoUrl,
                            size: 72,
                            borderRadius: 12,
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
                      if (_maintenance!.workshop != null ||
                          _maintenance!.workshopName != null)
                        _buildWorkshopSection(),
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
            ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _safePdfFileName(Invoice invoice) {
    final raw = invoice.fileName.trim();
    final base = raw.isEmpty
        ? 'nota-${invoice.id ?? 'fiscal'}'
        : raw.replaceAll(RegExp(r'[/\\]'), '_');
    return base.toLowerCase().endsWith('.pdf') ? base : '$base.pdf';
  }

  String _normalizeBrWhatsapp(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('55') && digits.length >= 12) {
      return digits;
    }
    return '55$digits';
  }

  Future<void> _openWhatsApp(String rawPhone) async {
    final phone = _normalizeBrWhatsapp(rawPhone);
    if (phone.length < 12) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Número de WhatsApp inválido.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final appUri = Uri.parse('whatsapp://send?phone=$phone');
    final webUri = Uri.parse('https://wa.me/$phone');

    try {
      if (await canLaunchUrl(appUri)) {
        final opened = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        if (opened) {
          return;
        }
      }

      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível abrir o WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWorkshopSection() {
    final workshop = _maintenance!.workshop;
    final workshopName = _maintenance!.workshopName;

    if (workshop == null && workshopName == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.build_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Oficina',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (workshop != null) ...[
          // Nome da oficina
          Text(
            workshop.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          // Telefone
          InkWell(
            onTap: () async {
              final uri = Uri.parse('tel:${workshop.phone}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.phone, size: 20),
                const SizedBox(width: 8),
                Text(
                  workshop.phone,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // WhatsApp
          if (workshop.whatsapp != null)
            InkWell(
              onTap: () => _openWhatsApp(workshop.whatsapp!),
              child: Row(
                children: [
                  const Icon(Icons.chat, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'WhatsApp: ${workshop.whatsapp}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          if (workshop.whatsapp != null) const SizedBox(height: 4),
          // Email
          if (workshop.email != null)
            InkWell(
              onTap: () async {
                final uri = Uri.parse('mailto:${workshop.email}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.email, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    workshop.email!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          if (workshop.email != null) const SizedBox(height: 8),
          // Endereço (clicável para abrir no mapa)
          InkWell(
            onTap: () async {
              final url = workshop.googleMapsUrl;
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workshop.shortAddress,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Redes Sociais
          if (workshop.facebook != null || workshop.instagram != null)
            Wrap(
              spacing: 16,
              children: [
                if (workshop.facebook != null)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(workshop.facebook!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.facebook,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Facebook',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (workshop.instagram != null)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(workshop.instagram!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Instagram',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ] else ...[
          // Fallback para workshop_name quando não há workshop completo
          Text(
            workshopName!,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
        const SizedBox(height: 16),
      ],
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
