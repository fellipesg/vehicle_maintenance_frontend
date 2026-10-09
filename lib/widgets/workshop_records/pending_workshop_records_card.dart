import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/workshop_records_inbox.dart';
import '../../views/workshop_records/workshop_records_page.dart';

/// Aviso na Home: "Registros de oficinas para revisar (N)". Some quando N é 0.
class PendingWorkshopRecordsCard extends StatelessWidget {
  const PendingWorkshopRecordsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<WorkshopRecordsInbox>().pendingCount;
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        key: const Key('pending_workshop_records_card'),
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: ListTile(
          leading: Icon(
            Icons.build_circle,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          title: Text(
            'Registros de oficinas para revisar ($count)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          subtitle: Text(
            'Oficinas registraram serviços no seu carro. Escolha o que vincular.',
            style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WorkshopRecordsPage(),
              ),
            );
            if (context.mounted) {
              context.read<WorkshopRecordsInbox>().refresh();
            }
          },
        ),
      ),
    );
  }
}
