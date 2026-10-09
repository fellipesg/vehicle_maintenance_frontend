import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/workshop_record.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../services/workshop_records_inbox.dart';
import '../../widgets/workshop_records/owner_decision_sheet.dart';

/// Registros feitos por oficinas nos carros do usuário, para ele decidir o que
/// vincular. "Pendentes" é o padrão; "Todos" deixa mudar uma decisão já tomada
/// (ocultar do público, revogar anexos).
class WorkshopRecordsPage extends StatefulWidget {
  const WorkshopRecordsPage({super.key});

  @override
  State<WorkshopRecordsPage> createState() => _WorkshopRecordsPageState();
}

class _WorkshopRecordsPageState extends State<WorkshopRecordsPage> {
  List<WorkshopRecord> _records = const [];
  bool _showAll = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final response =
          await api.getWorkshopRecords(status: _showAll ? 'all' : 'pending');
      final records = WorkshopRecord.listFromEnvelope(response.data);

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _isLoading = false;
      });

      if (!_showAll) {
        context.read<WorkshopRecordsInbox>().setCount(records.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Não foi possível carregar os registros das oficinas.',
          );
        });
      }
    }
  }

  Future<void> _open(WorkshopRecord record) async {
    final updated = await OwnerDecisionSheet.show(context, record);
    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      final index = _records.indexWhere((r) => r.id == updated.id);
      if (!_showAll && !updated.isPending) {
        _records = [..._records]..removeWhere((r) => r.id == updated.id);
      } else if (index != -1) {
        _records = [..._records]..[index] = updated;
      }
    });

    context.read<WorkshopRecordsInbox>().refresh();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sua escolha foi salva.')),
    );
  }

  void _setFilter(bool showAll) {
    if (_showAll == showAll) {
      return;
    }

    _showAll = showAll;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registros de oficinas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('records_filter_pending'),
                  label: const Text('Para revisar'),
                  selected: !_showAll,
                  onSelected: (_) => _setFilter(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('records_filter_all'),
                  label: const Text('Todos'),
                  selected: _showAll,
                  onSelected: (_) => _setFilter(true),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _showAll
                ? 'Nenhuma oficina registrou serviços nos seus carros.'
                : 'Nenhum registro de oficina para revisar.',
            key: const Key('records_empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        itemBuilder: (context, index) => _RecordCard(
          record: _records[index],
          onTap: () => _open(_records[index]),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final WorkshopRecord record;
  final VoidCallback onTap;

  String get _statusLabel {
    return switch (record.ownerStatus) {
      OwnerStatus.pending => 'Aguardando sua decisão',
      OwnerStatus.linked => 'Vinculado ao seu carro',
      OwnerStatus.declined => 'Não vinculado',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = record.maintenanceDate;
    final details = [
      if (date != null) DateFormat('dd/MM/yyyy').format(date),
      if (record.kilometers != null) '${record.kilometers} km',
    ].join(' · ');
    final itemNames = record.items.map((i) => i.name).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.workshop.name.isEmpty ? 'Oficina' : record.workshop.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  record.vehicle.displayName,
                  if (record.vehicle.year != null) '${record.vehicle.year}',
                ].join(' · '),
              ),
              if (details.isNotEmpty) Text(details),
              if (itemNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    itemNames,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(_statusLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (record.attachmentsCount > 0)
                    Chip(
                      avatar: const Icon(Icons.attach_file, size: 16),
                      label: Text('${record.attachmentsCount} anexo(s)'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (record.hiddenFromPublic)
                    const Chip(
                      avatar: Icon(Icons.visibility_off, size: 16),
                      label: Text('Oculto do público'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
