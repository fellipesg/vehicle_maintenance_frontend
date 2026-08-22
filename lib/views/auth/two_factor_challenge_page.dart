import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../home_page.dart';

class TwoFactorChallengePage extends StatefulWidget {
  const TwoFactorChallengePage({
    super.key,
    required this.challengeToken,
  });

  final String challengeToken;

  @override
  State<TwoFactorChallengePage> createState() => _TwoFactorChallengePageState();
}

class _TwoFactorChallengePageState extends State<TwoFactorChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  bool _isLoading = false;
  bool _showRecoveryCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final code = _codeController.text.trim();
      final recoveryCode = _recoveryCodeController.text.trim();

      final success = await authService.completeTwoFactorChallenge(
        challengeToken: widget.challengeToken,
        code: _showRecoveryCode ? null : code,
        recoveryCode: _showRecoveryCode && recoveryCode.isNotEmpty
            ? recoveryCode
            : null,
      );

      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível verificar o código.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    if (raw.contains('Invalid authentication code') ||
        raw.contains('Invalid') ||
        raw.contains('422')) {
      return 'Código inválido ou expirado. Tente novamente.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificação em duas etapas'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.security,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirme sua identidade',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _showRecoveryCode
                      ? 'Digite um dos seus códigos de recuperação.'
                      : 'Digite o código de 6 dígitos do seu aplicativo autenticador.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_showRecoveryCode) ...[
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Código de verificação',
                      hintText: '000000',
                      prefixIcon: Icon(Icons.pin),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (_showRecoveryCode) {
                        return null;
                      }
                      if (value == null || value.length != 6) {
                        return 'Informe o código de 6 dígitos';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _recoveryCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código de recuperação',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_showRecoveryCode) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe um código de recuperação';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _showRecoveryCode = !_showRecoveryCode;
                          });
                        },
                  child: Text(
                    _showRecoveryCode
                        ? 'Usar código do autenticador'
                        : 'Usar código de recuperação',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
