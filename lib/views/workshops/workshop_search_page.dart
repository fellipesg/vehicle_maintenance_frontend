import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workshop.dart';
import '../../services/api_service.dart';
import '../../widgets/load_more_button.dart';
import 'workshop_form_page.dart';

class WorkshopSearchPage extends StatefulWidget {
  final bool allowCreate;

  const WorkshopSearchPage({
    super.key,
    this.allowCreate = true,
  });

  @override
  State<WorkshopSearchPage> createState() => _WorkshopSearchPageState();
}

class _WorkshopSearchPageState extends State<WorkshopSearchPage> {
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final _searchController = TextEditingController();
  List<Workshop> _workshops = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  Timer? _debounce;
  int _loadedPage = 1;
  int? _lastPage;

  @override
  void initState() {
    super.initState();
    _loadWorkshops();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasMore => _lastPage != null && _loadedPage < _lastPage!;

  /// A busca é do servidor (`?search=`), não um filtro sobre o que já chegou:
  /// a resposta é paginada, então filtrar localmente só varria a primeira
  /// página e dava "nenhuma oficina encontrada" para quem estava na segunda.
  void _onSearchChanged() {
    final query = _searchController.text.trim();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _loadWorkshops);
  }

  Future<Response> _fetchPage(int page) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final query = _searchController.text.trim();

    return apiService.getWorkshops(
      page: page,
      queryParams: query.isNotEmpty ? {'search': query} : null,
    );
  }

  Future<void> _loadWorkshops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _fetchPage(1);

      if (response.data['success'] == true) {
        if (!mounted) {
          return;
        }

        setState(() {
          _workshops = _parsePage(response.data['data']);
          _loadedPage = 1;
          _lastPage = _lastPageFrom(response.data);
          _isLoading = false;
        });
      } else {
        throw Exception(
            response.data['message'] ?? 'Erro ao carregar oficinas');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar oficinas: $e'),
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

      if (!mounted) {
        return;
      }

      if (response.data['success'] == true) {
        final knownIds = _workshops.map((workshop) => workshop.id).toSet();

        setState(() {
          _workshops = [
            ..._workshops,
            ..._parsePage(response.data['data'])
                .where((workshop) => !knownIds.contains(workshop.id)),
          ];
          _loadedPage = nextPage;
          _lastPage = _lastPageFrom(response.data) ?? _lastPage;
          _isLoadingMore = false;
        });
      } else {
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
            content: Text('Erro ao carregar mais oficinas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Workshop> _parsePage(dynamic data) {
    if (data is! List) {
      return const [];
    }

    return data.map((json) => Workshop.fromJson(json)).toList();
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

  void _selectWorkshop(Workshop workshop) {
    // Return the selected workshop to the previous page
    Navigator.of(context).pop(workshop);
  }

  void _navigateToCreateWorkshop() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkshopFormPage(),
      ),
    );

    // If result is a Workshop object, automatically select it
    if (result is Workshop) {
      _selectWorkshop(result);
    } else if (result == true) {
      // If result is true (workshop was updated), just reload the list
      _loadWorkshops();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Oficina'),
        actions: widget.allowCreate
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _navigateToCreateWorkshop,
                  tooltip: 'Adicionar Oficina',
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nome, cidade ou bairro',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                // Busca agora, sem esperar (e sem deixar o debounce repetir).
                _debounce?.cancel();
                _loadWorkshops();
              },
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_workshops.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching
                          ? 'Nenhuma oficina encontrada'
                          : 'Nenhuma oficina cadastrada',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.allowCreate) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _navigateToCreateWorkshop,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Oficina'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _workshops.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _workshops.length) {
                    return LoadMoreButton(
                      isLoading: _isLoadingMore,
                      onPressed: _loadMore,
                    );
                  }

                  final workshop = _workshops[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: workshop.logoUrl != null &&
                              workshop.logoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                workshop.logoUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.build_circle,
                                  size: 40,
                                ),
                              ),
                            )
                          : const Icon(Icons.build_circle, size: 40),
                      title: Text(
                        workshop.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(workshop.shortAddress),
                          Text('Tel: ${workshop.phone}'),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _selectWorkshop(workshop),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
