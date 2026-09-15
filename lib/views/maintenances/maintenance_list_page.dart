import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../models/maintenance.dart';
import '../../services/api_service.dart';
import '../../widgets/provenance/provenance_card.dart';
import '../../widgets/provenance/provenance_legend.dart';
import 'maintenance_detail_page.dart';
import 'maintenance_form_page.dart';

class MaintenanceListPage extends StatefulWidget {
  final int? vehicleId;
  final bool? verifiedFilter;

  const MaintenanceListPage({
    super.key,
    this.vehicleId,
    this.verifiedFilter,
  });

  @override
  State<MaintenanceListPage> createState() => _MaintenanceListPageState();
}

class _MaintenanceListPageState extends State<MaintenanceListPage> {
  List<Maintenance> _maintenances = [];
  bool _isLoading = true;
  bool? _verifiedFilter;

  @override
  void initState() {
    super.initState();
    _verifiedFilter = widget.verifiedFilter;
    _loadMaintenances();
  }

  Future<void> _loadMaintenances() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      Response response;

      if (widget.vehicleId != null) {
        response = await apiService.getVehicleMaintenances(
          widget.vehicleId.toString(),
          verified: _verifiedFilter,
        );
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const ProvenanceLegend(),
                      const SizedBox(height: 12),
                      for (final maintenance in _maintenances)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ProvenanceCard(
                            maintenance: maintenance,
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
                        ),
                    ],
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

}
