import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_error.dart';
import '../../services/api_service.dart';

/// Pede o link de redefinição de senha.
///
/// A troca em si acontece na página do portal que chega por e-mail — não há deep
/// link de volta para o app. A resposta do backend é a mesma exista ou não a
/// conta, então esta tela também não pode dizer se o e-mail estava cadastrado.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isSending = false;
  String? _sentMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Informe o e-mail da sua conta';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Informe um e-mail válido, como nome@exemplo.com';
    }

    return null;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSending = true;
      _sentMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.requestPasswordReset(
        _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      final message = response.data is Map
          ? response.data['message']?.toString()
          : null;

      setState(() {
        _isSending = false;
        _sentMessage = message?.isNotEmpty == true
            ? message!
            : 'Se este e-mail estiver cadastrado, você receberá um link em '
                'alguns minutos.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Receber link por e-mail',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviamos um link para você criar uma senha nova. Ele abre '
                  'no navegador e vale por tempo limitado.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('forgot_email_field'),
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('forgot_submit_button'),
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isSending ? 'Enviando...' : 'Enviar link'),
                ),
                if (_sentMessage != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    key: const Key('forgot_sent_card'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(_sentMessage!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
