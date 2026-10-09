import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/workshop_record.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';

/// Folha de decisão do proprietário sobre um registro feito por oficina.
///
/// Três escolhas independentes, com texto claro sobre o que cada uma faz:
/// vincular ao carro, anexar notas fiscais e fotos, ocultar do histórico
/// público. O envio vai para `POST /maintenances/{id}/owner-decision`; erros do
/// servidor (422) aparecem na própria folha com a mensagem em pt-BR.
class OwnerDecisionSheet extends StatefulWidget {
  const OwnerDecisionSheet({super.key, required this.record});

  final WorkshopRecord record;

  /// Abre a folha e devolve o registro atualizado, ou nulo se foi fechada.
  static Future<WorkshopRecord?> show(
    BuildContext context,
    WorkshopRecord record,
  ) {
    return showModalBottomSheet<WorkshopRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OwnerDecisionSheet(record: record),
    );
  }

  @override
  State<OwnerDecisionSheet> createState() => _OwnerDecisionSheetState();
}

class _OwnerDecisionSheetState extends State<OwnerDecisionSheet> {
  late bool _link;
  late bool _attach;
  late bool _hide;
  bool _isSubmitting = false;
  String? _error;

  WorkshopRecord get _record => widget.record;

  /// Anexos aceitos podem ser revogados; anexos pendentes só aceitos com posse
  /// verificada (`can_accept_attachments`).
  bool get _attachEnabled =>
      _link && (_record.canAcceptAttachments || _record.attachmentsAccepted);

  @override
  void initState() {
    super.initState();
    _link = _record.isLinked;
    _attach = _record.attachmentsAccepted;
    _hide = _record.hiddenFromPublic;
  }

  /// Por que o anexo está bloqueado, quando está.
  String? get _attachDisabledReason {
    if (_record.canAcceptAttachments || _record.attachmentsAccepted) {
      return _link
          ? null
          : 'Vincule o registro ao seu carro para poder anexar.';
    }

    return switch (_record.attachmentsStatus) {
      AttachmentsStatus.pending =>
        'Para anexar, verifique que o carro é seu enviando o CRLV-e no site '
            'do RevisaLog. Depois volte aqui.',
      AttachmentsStatus.declined ||
      AttachmentsStatus.revoked =>
        'Os anexos já foram recusados ou removidos e foram apagados.',
      _ => 'Este registro não tem notas fiscais nem fotos.',
    };
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final response = await api.submitOwnerDecision(
        _record.id,
        link: _link,
        attachFiles: _link && _attach,
        hideFromPublic: _hide,
      );

      final data = response.data is Map ? response.data['data'] : null;
      final updated = data is Map
          ? WorkshopRecord.fromJson(Map<String, dynamic>.from(data))
          : _record;

      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Não foi possível salvar sua escolha. Tente novamente.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final attachCount = _record.attachmentsCount;
    final reason = _attachDisabledReason;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Registro da oficina ${_record.workshop.name}'.trim(),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _record.vehicle.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 12),
            Text(
              'A oficina registrou um serviço neste carro antes de você ter '
              'conta. Nada é ligado a você sem a sua escolha. Escolha abaixo '
              'o que fazer — você pode mudar depois.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('decision_link_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Vincular ao meu carro'),
              subtitle: const Text(
                'O serviço entra no histórico do seu carro, com data, '
                'quilometragem, itens e o selo da oficina. Se você não '
                'vincular, o registro continua no chassi só com os dados '
                'básicos.',
              ),
              value: _link,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() {
                        _link = value;
                        if (!value) {
                          _attach = false;
                        }
                      }),
            ),
            SwitchListTile(
              key: const Key('decision_attach_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                attachCount > 0
                    ? 'Anexar notas fiscais e fotos ($attachCount)'
                    : 'Anexar notas fiscais e fotos',
              ),
              subtitle: Text(
                reason ??
                    'Notas fiscais e fotos podem conter seus dados pessoais '
                        '(nome, CPF, placa). Só passam a fazer parte do '
                        'histórico se você aceitar. Se recusar, são apagadas. '
                        'Se já aceitou, desligar remove os arquivos.',
              ),
              value: _attach,
              onChanged: (_isSubmitting || !_attachEnabled)
                  ? null
                  : (value) => setState(() => _attach = value),
            ),
            SwitchListTile(
              key: const Key('decision_hide_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ocultar do histórico público'),
              subtitle: const Text(
                'O registro deixa de aparecer na consulta pública e no '
                'histórico do carro para qualquer pessoa, exceto para a '
                'oficina que o fez.',
              ),
              value: _hide,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _hide = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('decision_error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('decision_submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar minha escolha'),
            ),
          ],
        ),
      ),
    );
  }
}
