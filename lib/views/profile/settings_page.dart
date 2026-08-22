import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../auth/login_hub_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair deste aparelho'),
        content: const Text(
          'Deseja encerrar a sessão neste aparelho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginHubPage()),
        (route) => false,
      );
    }
  }

  void _showTwoFactorInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autenticação em duas etapas'),
        content: const Text(
          'Quando a verificação em duas etapas estiver ativa na sua conta, '
          'o app solicitará um código após o login. A configuração da 2FA '
          'será feita pelo servidor em uma versão futura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Segurança'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Alterar senha'),
                  subtitle: Text('Em breve'),
                  enabled: false,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Autenticação em duas etapas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTwoFactorInfo(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sair deste aparelho',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Notificações'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'As notificações push usam a permissão já solicitada '
                      'ao abrir o app. Você pode alterá-la nas configurações '
                      'do sistema operacional.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Sobre'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Vehicle Maintenance'),
              subtitle: Text('Versão 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
      ),
    );
  }
}
