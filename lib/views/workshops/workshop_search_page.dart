import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workshop.dart';
import '../../services/api_service.dart';
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
  final _searchController = TextEditingController();
  List<Workshop> _workshops = [];
  List<Workshop> _filteredWorkshops = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadWorkshops();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredWorkshops = _workshops;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
        _filteredWorkshops = _workshops.where((workshop) {
          return workshop.name.toLowerCase().contains(query) ||
              workshop.city.toLowerCase().contains(query) ||
              workshop.neighborhood.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadWorkshops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final query = _searchController.text.trim();

      final response = await apiService.getWorkshops(
        queryParams: query.isNotEmpty ? {'search': query} : null,
      );

      if (response.data['success'] == true) {
        setState(() {
          _workshops = (response.data['data'] as List)
              .map((json) => Workshop.fromJson(json))
              .toList();
          _filteredWorkshops = _workshops;
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
              onSubmitted: (_) => _loadWorkshops(),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_filteredWorkshops.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching
                          ? 'Nenhuma oficina encontrada'
                          : 'Nenhuma oficina cadastrada',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
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
                itemCount: _filteredWorkshops.length,
                itemBuilder: (context, index) {
                  final workshop = _filteredWorkshops[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.build_circle, size: 40),
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
