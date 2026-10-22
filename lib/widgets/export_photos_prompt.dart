import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_error.dart';
import '../services/auth_service.dart';
import '../services/export_photos_preference.dart';
import '../services/onboarding_storage.dart';

const String exportPhotosQuestion =
    'Incluir as fotos das manutenções no PDF do histórico?';

const String exportPhotosExplanation =
    'O PDF do histórico pode ser compartilhado com compradores. Com as fotos '
    'de antes e depois, ele mostra o estado do carro e das peças trocadas. '
    'Você pode mudar isso depois em Configurações.';

/// Pergunta uma vez (por abertura do app) se o PDF deve levar as fotos, quando
/// a conta ainda não respondeu. Não bloqueia: dá para dispensar com "Agora não".
///
/// Se a pessoa já respondeu no onboarding (antes do login, sem conta para
/// gravar), aplica essa resposta em vez de perguntar de novo.
class ExportPhotosPrompt {
  const ExportPhotosPrompt._();

  static bool _askedThisSession = false;

  static void resetSessionForTests() => _askedThisSession = false;

  static Future<void> maybeAsk(
    BuildContext context, {
    OnboardingStorage storage = const OnboardingStorage(),
  }) async {
    if (_askedThisSession) {
      return;
    }

    final AuthService auth;
    try {
      auth = context.read<AuthService>();
    } catch (_) {
      return;
    }

    if (!ExportPhotosPreference.appliesTo(auth)) {
      return;
    }

    final current = await ExportPhotosPreference.resolve(auth);
    if (!current.supported || current.value != null) {
      return;
    }

    _askedThisSession = true;

    final earlier = await storage.readExportPhotosAnswer();
    if (earlier != null) {
      try {
        await ExportPhotosPreference.save(auth, earlier);
        await storage.clearExportPhotosAnswer();
      } catch (_) {
        // Mantém a resposta guardada para tentar na próxima abertura.
        _askedThisSession = false;
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(exportPhotosQuestion),
        content: const Text(exportPhotosExplanation),
        actions: [
          TextButton(
            key: const Key('export_photos_later'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Agora não'),
          ),
          TextButton(
            key: const Key('export_photos_no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            key: const Key('export_photos_yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (answer == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportPhotosPreference.save(auth, answer);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(error, fallback: 'Não foi possível salvar.'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
