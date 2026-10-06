import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../models/maintenance.dart';
import '../../services/api_service.dart';
import '../../widgets/provenance/provenance_card.dart';
import '../../widgets/load_more_button.dart';
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
  bool _isLoadingMore = false;
  bool? _verifiedFilter;
  int _loadedPage = 1;
  int? _lastPage;

  @override
  void initState() {
    super.initState();
    _verifiedFilter = widget.verifiedFilter;
    _loadMaintenances();
  }

  bool get _hasMore => _lastPage != null && _loadedPage < _lastPage!;

  Future<Response> _fetchPage(int page) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    if (widget.vehicleId != null) {
      return apiService.getVehicleMaintenances(
        widget.vehicleId.toString(),
        page: page,
        verified: _verifiedFilter,
      );
    }

    return apiService.getMaintenances(
      page: page,
      queryParams: _verifiedFilter == null
          ? null
          : {'verified': _verifiedFilter! ? 1 : 0},
    );
  }

  /// A lista vem do servidor em ordem decrescente de data (mais recente
  /// primeiro) e é mantida assim: com paginação, reordenar o que já chegou
  /// jogaria os registros mais antigos para o topo a cada página carregada. A
  /// visão cronológica fica na timeline do veículo.
  Future<void> _loadMaintenances() async {
    try {
      final response = await _fetchPage(1);

      if (response.data['success'] == true && mounted) {
        setState(() {
          _maintenances = _parsePage(response.data['data']);
          _loadedPage = 1;
          _lastPage = _lastPageFrom(response.data);
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _loadedPage + 1;

    try {
      final response = await _fetchPage(nextPage);

      if (response.data['success'] == true && mounted) {
        final knownIds = _maintenances.map((m) => m.id).toSet();

        setState(() {
          _maintenances = [
            ..._maintenances,
            ..._parsePage(response.data['data'])
                .where((m) => !knownIds.contains(m.id)),
          ];
          _loadedPage = nextPage;
          _lastPage = _lastPageFrom(response.data) ?? _lastPage;
          _isLoadingMore = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar mais manutenções: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Maintenance> _parsePage(dynamic data) {
    if (data is! List) {
      return const [];
    }

    return data.map((json) => Maintenance.fromJson(json)).toList();
  }

  static int? _lastPageFrom(dynamic envelope) {
    if (envelope is! Map) {
      return null;
    }

    final meta = envelope['meta'];
    if (meta is! Map) {
      return null;
    }

    final lastPage = meta['last_page'];
    if (lastPage is int) {
      return lastPage;
    }

    return int.tryParse(lastPage?.toString() ?? '');
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                      if (_hasMore)
                        LoadMoreButton(
                          isLoading: _isLoadingMore,
                          onPressed: _loadMore,
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
