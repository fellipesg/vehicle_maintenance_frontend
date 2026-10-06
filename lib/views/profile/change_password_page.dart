import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/forgot_password_page.dart';

/// Troca a senha com o usuário logado.
///
/// Quem entrou com Google ou Apple tem uma senha aleatória que nunca viu, e a
/// API exige a senha atual aqui. Por isso a tela oferece o link por e-mail como
/// saída — é o mesmo caminho que o e-mail de boas-vindas dessas contas usa.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _isSaving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? value) {
    return (value ?? '').isEmpty ? 'Informe sua senha atual' : null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Crie uma senha nova';
    }
    if (password.length < 8) {
      return 'A senha nova deve ter no mínimo 8 caracteres';
    }
    if (password == _currentController.text) {
      return 'A senha nova precisa ser diferente da atual';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'A confirmação da senha nova não confere';
    }

    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.changePassword(
        currentPassword: _currentController.text,
        password: _passwordController.text,
      );

      if (response.data is Map && response.data['success'] == true) {
        if (!mounted) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final message = response.data['message']?.toString();

        navigator.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message?.isNotEmpty == true ? message! : 'Senha alterada.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        return;
      }

      throw Exception(
        response.data is Map ? response.data['message'] : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = Provider.of<AuthService>(context, listen: false)
        .user?['email']
        ?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('current_password_field'),
                  controller: _currentController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Senha atual *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Mostrar senhas' : 'Ocultar senhas',
                    ),
                  ),
                  validator: _validateCurrent,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('new_password_field'),
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Senha nova *',
                    prefixIcon: Icon(Icons.lock_reset),
                    border: OutlineInputBorder(),
                    helperText: 'No mínimo 8 caracteres',
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('confirm_password_field'),
                  controller: _confirmationController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha nova *',
                    prefixIcon: Icon(Icons.lock_reset),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateConfirmation,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ao salvar, os outros aparelhos são desconectados. Este '
                  'continua conectado.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('change_password_submit'),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Salvando...' : 'Salvar senha nova'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('change_password_forgot_link'),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ForgotPasswordPage(initialEmail: email),
                            ),
                          ),
                  child: const Text(
                    'Não sabe sua senha atual? Receber link por e-mail',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
