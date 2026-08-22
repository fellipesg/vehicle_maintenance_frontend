import 'package:flutter/material.dart';
import '../../models/login_portal.dart';
import 'login_page.dart';
import 'register_page.dart';

class LoginHubPage extends StatelessWidget {
  const LoginHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.directions_car,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Vehicle Maintenance',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Como você deseja entrar?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha o portal correspondente ao seu perfil',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              ...LoginPortal.values.map(
                (portal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PortalCard(
                    key: Key('login_hub_portal_${portal.name}'),
                    portal: portal,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(userType: 'user'),
                    ),
                  );
                },
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: Colors.grey.shade700),
                    children: const [
                      TextSpan(text: 'Não tem conta? '),
                      TextSpan(
                        text: 'Cadastre-se',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({super.key, required this.portal});

  final LoginPortal portal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: portal.accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: portal.accent.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LoginPage(portal: portal)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: portal.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(portal.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      portal.hubTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      portal.hubSubtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: portal.accent),
            ],
          ),
        ),
      ),
    );
  }
}
