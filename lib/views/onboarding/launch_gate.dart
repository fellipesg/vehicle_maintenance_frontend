import 'package:flutter/material.dart';

import '../../services/onboarding_storage.dart';
import '../auth/login_hub_page.dart';
import 'onboarding_page.dart';

/// Decide a primeira tela: app (autenticado), onboarding (primeiro acesso) ou
/// hub de login.
class LaunchGate extends StatefulWidget {
  const LaunchGate({
    super.key,
    required this.isAuthenticated,
    required this.authenticatedBuilder,
    this.storage = const OnboardingStorage(),
  });

  final bool isAuthenticated;
  final WidgetBuilder authenticatedBuilder;
  final OnboardingStorage storage;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    if (!widget.isAuthenticated) {
      _load();
    }
  }

  Future<void> _load() async {
    final seen = await widget.storage.isSeen();
    if (mounted) {
      setState(() => _seen = seen);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAuthenticated) {
      return widget.authenticatedBuilder(context);
    }

    final seen = _seen;
    if (seen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return seen
        ? const LoginHubPage()
        : OnboardingPage(storage: widget.storage);
  }
}
