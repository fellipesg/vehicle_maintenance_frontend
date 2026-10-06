import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'password_and_code_dialog.dart';

/// Ativa, desativa e regera os códigos de recuperação da 2FA.
///
/// O segredo aparece em texto, para digitar no autenticador: o app não gera QR
/// (o do selo de verificação vem pronto do backend) e o `otpauth_uri` sozinho
/// não resolveria sem um gerador local.
class TwoFactorPage extends StatefulWidget {
  const TwoFactorPage({super.key});

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final _codeController = TextEditingController();

  bool _busy = false;

  /// Segredo devolvido pelo enable, enquanto a ativação não foi confirmada.
  String? _pendingSecret;

  /// Códigos de recuperação a mostrar uma única vez, após confirmar ou regerar.
  List<String>? _recoveryCodes;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  ApiService get _api => Provider.of<ApiService>(context, listen: false);

  AuthService get _auth => Provider.of<AuthService>(context, listen: false);

  void _snack(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);

    try {
      await action();
    } catch (e) {
      _snack(apiErrorMessage(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startEnable() {
    return _run(() async {
      final response = await _api.enableTwoFactor();
      final data = response.data is Map ? response.data['data'] : null;
      final secret = data is Map ? data['secret']?.toString() : null;

      if (secret == null || secret.isEmpty) {
        throw Exception('Não foi possível iniciar a ativação.');
      }

      if (mounted) {
        setState(() {
          _pendingSecret = secret;
          _recoveryCodes = null;
        });
      }
    });
  }

  Future<void> _confirmEnable() {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _snack('Informe o código do aplicativo autenticador.', error: true);

      return Future<void>.value();
    }

    // Capturado antes do await: o AuthService não é ChangeNotifier e o context
    // não deve ser lido depois de um gap assíncrono.
    final auth = _auth;

    return _run(() async {
      final response = await _api.confirmTwoFactor(code);
      final data = response.data is Map ? response.data['data'] : null;

      await auth.getCurrentUser();

      if (mounted) {
        setState(() {
          _pendingSecret = null;
          _recoveryCodes = _codesFrom(data);
          _codeController.clear();
        });
      }

      _snack('Verificação em duas etapas ativada.');
    });
  }

  /// Desativar e regerar pedem senha + código, então os dois passam pelo mesmo
  /// diálogo.
  Future<void> _confirmWithPasswordAndCode({
    required String title,
    required String actionLabel,
    required bool destructive,
  }) async {
    final credentials = await showDialog<PasswordAndCode>(
      context: context,
      builder: (_) => PasswordAndCodeDialog(
        title: title,
        actionLabel: actionLabel,
        destructive: destructive,
      ),
    );

    if (credentials == null || !mounted) {
      return;
    }

    if (!credentials.isComplete) {
      _snack('Informe a senha e o código.', error: true);

      return;
    }

    final password = credentials.password;
    final code = credentials.code;
    final auth = _auth;

    await _run(() async {
      if (destructive) {
        await _api.disableTwoFactor(password: password, code: code);
        await auth.getCurrentUser();

        if (mounted) {
          setState(() {
            _recoveryCodes = null;
            _pendingSecret = null;
          });
        }

        _snack('Verificação em duas etapas desativada.');

        return;
      }

      final response = await _api.regenerateTwoFactorRecoveryCodes(
        password: password,
        code: code,
      );
      final data = response.data is Map ? response.data['data'] : null;

      if (mounted) {
        setState(() {
          _recoveryCodes = _codesFrom(data);
        });
      }

      _snack('Códigos de recuperação gerados.');
    });
  }

  static List<String>? _codesFrom(dynamic data) {
    if (data is! Map) {
      return null;
    }

    final codes = data['recovery_codes'];

    return codes is List
        ? codes.map((code) => code.toString()).toList()
        : null;
  }

  Future<void> _copy(String value, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: value));
    _snack(confirmation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _auth.hasTwoFactorEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação em duas etapas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  enabled ? Icons.verified_user : Icons.gpp_maybe_outlined,
                  color: enabled ? Colors.green : theme.colorScheme.outline,
                ),
                title: Text(enabled ? 'Ativa' : 'Desativada'),
                subtitle: Text(
                  enabled
                      ? 'O app pede um código do autenticador depois do login.'
                      : 'Com ela ativa, o login passa a pedir um código além '
                          'da senha.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!enabled && _pendingSecret == null)
              FilledButton.icon(
                key: const Key('two_factor_enable_button'),
                onPressed: _busy ? null : _startEnable,
                icon: const Icon(Icons.security),
                label: const Text('Ativar'),
              ),
            if (_pendingSecret != null) _enrollCard(theme, _pendingSecret!),
            if (enabled) ...[
              OutlinedButton.icon(
                key: const Key('two_factor_regenerate_button'),
                onPressed: _busy
                    ? null
                    : () => _confirmWithPasswordAndCode(
                          title: 'Gerar novos códigos',
                          actionLabel: 'Gerar',
                          destructive: false,
                        ),
                icon: const Icon(Icons.autorenew),
                label: const Text('Gerar novos códigos de recuperação'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('two_factor_disable_button'),
                onPressed: _busy
                    ? null
                    : () => _confirmWithPasswordAndCode(
                          title: 'Desativar verificação em duas etapas',
                          actionLabel: 'Desativar',
                          destructive: true,
                        ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.gpp_bad_outlined),
                label: const Text('Desativar'),
              ),
            ],
            if (_recoveryCodes != null) _recoveryCard(theme, _recoveryCodes!),
          ],
        ),
      ),
    );
  }

  Widget _enrollCard(ThemeData theme, String secret) {
    return Card(
      key: const Key('two_factor_enroll_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Cadastre este código no seu autenticador',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Abra o aplicativo autenticador (Google Authenticator, Authy, '
              '1Password) e adicione uma conta manualmente com este código.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      secret,
                      key: const Key('two_factor_secret_text'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('two_factor_copy_secret'),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copiar código',
                    onPressed: () => _copy(secret, 'Código copiado.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '2. Digite o código de 6 dígitos que ele mostrar',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('two_factor_confirm_code_field'),
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código do autenticador',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('two_factor_confirm_button'),
              onPressed: _busy ? null : _confirmEnable,
              child: Text(_busy ? 'Confirmando...' : 'Confirmar e ativar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recoveryCard(ThemeData theme, List<String> codes) {
    return Card(
      key: const Key('two_factor_recovery_card'),
      margin: const EdgeInsets.only(top: 24),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Códigos de recuperação',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guarde-os agora, fora do aparelho. Eles não voltam a aparecer e '
              'cada um serve uma vez, se você perder o autenticador.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              codes.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', height: 1.6),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('two_factor_copy_recovery'),
              onPressed: () => _copy(
                codes.join('\n'),
                'Códigos de recuperação copiados.',
              ),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar códigos'),
            ),
          ],
        ),
      ),
    );
  }
}
