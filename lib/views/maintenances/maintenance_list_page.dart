import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import 'maintenance_detail_page.dart';
import 'maintenance_form_page.dart';

class MaintenanceListPage extends StatefulWidget {
  final int? vehicleId;

  const MaintenanceListPage({super.key, this.vehicleId});

  @override
  State<MaintenanceListPage> createState() => _MaintenanceListPageState();
}

class _MaintenanceListPageState extends State<MaintenanceListPage> {
  List<Maintenance> _maintenances = [];
  bool _isLoading = true;
  Vehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadMaintenances();
    if (widget.vehicleId != null) {
      _loadVehicle();
    }
  }

  Future<void> _loadVehicle() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response =
          await apiService.getVehicle(widget.vehicleId.toString());

      if (response.data['success'] == true && mounted) {
        setState(() {
          _vehicle = Vehicle.fromJson(response.data['data']);
        });
      }
    } catch (_) {
      // Cover photo fallback handled by widget.
    }
  }

  Future<void> _loadMaintenances() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      Response response;

      if (widget.vehicleId != null) {
        response = await apiService
            .getVehicleMaintenances(widget.vehicleId.toString());
      } else {
        response = await apiService.getMaintenances();
      }

      if (response.data['success'] == true && mounted) {
        setState(() {
          _maintenances = (response.data['data'] as List)
              .map((json) => Maintenance.fromJson(json))
              .toList()
            ..sort((a, b) => a.maintenanceDate.compareTo(b.maintenanceDate));
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
            content: Text('Erro ao carregar manutenções: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(Maintenance maintenance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir esta manutenção?'),
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
      await apiService.deleteMaintenance(maintenance.id.toString());

      if (mounted) {
        _loadMaintenances();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manutenção excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir manutenção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manutenções'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _maintenances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.build_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma manutenção registrada',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.vehicleId != null
                            ? 'Adicione uma manutenção para este veículo'
                            : 'Adicione uma manutenção para começar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMaintenances,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _maintenances.length,
                    itemBuilder: (context, index) {
                      final maintenance = _maintenances[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: VehicleCoverAvatar(
                            coverPhotoUrl: _vehicle?.coverPhotoUrl,
                            size: 48,
                          ),
                          title: Text(
                            _getMaintenanceTypeLabel(
                                maintenance.maintenanceType),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(maintenance.maintenanceDate),
                              ),
                              if (maintenance.workshopName != null)
                                Text(maintenance.workshopName!),
                              if (maintenance.kilometers != null)
                                Text('${maintenance.kilometers} km'),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Excluir',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => MaintenanceFormPage(
                                          vehicleId: maintenance.vehicleId,
                                          maintenance: maintenance,
                                        ),
                                      ),
                                    )
                                    .then((_) => _loadMaintenances());
                              } else if (value == 'delete') {
                                _handleDelete(maintenance);
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => MaintenanceDetailPage(
                                      maintenanceId: maintenance.id!,
                                    ),
                                  ),
                                )
                                .then((_) => _loadMaintenances());
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: widget.vehicleId != null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MaintenanceFormPage(vehicleId: widget.vehicleId!),
                  ),
                );
                if (result == true) {
                  _loadMaintenances();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
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
}
