import 'package:flutter/material.dart';

/// Senha e código colhidos no diálogo.
class PasswordAndCode {
  const PasswordAndCode(this.password, this.code);

  final String password;
  final String code;

  bool get isComplete => password.isNotEmpty && code.isNotEmpty;
}

/// Desativar a 2FA e regerar os códigos de recuperação pedem senha + código do
/// autenticador, então os dois fluxos usam este diálogo.
///
/// É um widget com estado para que os `TextEditingController` vivam enquanto o
/// diálogo existe: descartá-los logo depois do `showDialog` os destruía enquanto
/// a animação de saída ainda reconstruía os campos.
class PasswordAndCodeDialog extends StatefulWidget {
  const PasswordAndCodeDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.destructive,
  });

  final String title;
  final String actionLabel;
  final bool destructive;

  @override
  State<PasswordAndCodeDialog> createState() => _PasswordAndCodeDialogState();
}

class _PasswordAndCodeDialogState extends State<PasswordAndCodeDialog> {
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('two_factor_password_field'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Sua senha',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('two_factor_code_field'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código do autenticador',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('two_factor_dialog_confirm'),
          onPressed: () => Navigator.of(context).pop(
            PasswordAndCode(
              _passwordController.text,
              _codeController.text.trim(),
            ),
          ),
          style: widget.destructive
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
