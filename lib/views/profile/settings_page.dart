import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/theme_controller.dart';
import '../auth/login_hub_page.dart';
import 'change_password_page.dart';
import 'two_factor_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDeletingAccount = false;

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

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Isso remove seus dados pessoais e encerra o acesso. '
          'O histórico de manutenções permanece no chassi do veículo. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.deleteAccount();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginHubPage()),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Aparência'),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  mode: ThemeMode.light,
                  selected: themeController.mode == ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  title: 'Claro',
                  onSelected: themeController.setMode,
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  mode: ThemeMode.dark,
                  selected: themeController.mode == ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  title: 'Escuro',
                  onSelected: themeController.setMode,
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  mode: ThemeMode.system,
                  selected: themeController.mode == ThemeMode.system,
                  icon: Icons.brightness_auto_outlined,
                  title: 'Sistema',
                  subtitle: 'Segue a aparência do aparelho',
                  onSelected: themeController.setMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Segurança'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings_change_password'),
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Alterar senha'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isDeletingAccount
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('settings_two_factor'),
                  leading: const Icon(Icons.security),
                  title: const Text('Verificação em duas etapas'),
                  // listen: false porque o AuthService não é ChangeNotifier; o
                  // estado é relido no setState de volta da TwoFactorPage.
                  subtitle: Text(
                    Provider.of<AuthService>(context, listen: false)
                            .hasTwoFactorEnabled
                        ? 'Ativa'
                        : 'Desativada',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isDeletingAccount
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TwoFactorPage(),
                            ),
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sair deste aparelho',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap:
                      _isDeletingAccount ? null : () => _handleLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Conta'),
          Card(
            child: ListTile(
              leading: _isDeletingAccount
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Excluir conta',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Remove seus dados pessoais deste aplicativo',
              ),
              onTap: _isDeletingAccount
                  ? null
                  : () => _handleDeleteAccount(context),
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
              title: Text('RevisaLog'),
              subtitle: Text('Versão 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onSelected,
    this.subtitle,
  });

  final ThemeMode mode;
  final bool selected;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function(ThemeMode mode) onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      key: Key('theme_mode_${mode.name}'),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.outline,
      ),
      onTap: () => onSelected(mode),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
