import 'package:flutter/material.dart';

import '../../services/onboarding_storage.dart';
import '../../theme/provenance.dart';
import '../../widgets/revisalog_lockup.dart';
import '../auth/login_hub_page.dart';
import '../auth/register_page.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    this.footnote,
    this.showProvenance = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? footnote;
  final bool showProvenance;
}

const List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    icon: Icons.directions_car_outlined,
    title: 'O histórico do carro viaja com o carro',
    body: 'Cada manutenção fica ligada ao chassi, não ao dono. '
        'Na hora da venda, o histórico vai junto com o veículo.',
  ),
  _OnboardingSlide(
    icon: Icons.verified_outlined,
    title: 'Selo da oficina ou declarada',
    body: 'Você registra o que fez. A oficina que fez o serviço o confirma '
        'com o Selo da oficina, e qualquer pessoa confere o código.',
    showProvenance: true,
  ),
  _OnboardingSlide(
    icon: Icons.picture_as_pdf_outlined,
    title: 'Pronto para a venda',
    body: 'Exporte o PDF com a linha do tempo, a quilometragem e as notas '
        'fiscais.',
    footnote: 'Grátis no lançamento.',
  ),
];

/// Apresentação do produto exibida no primeiro acesso, antes do login.
///
/// Com [reopened] (aberto pelo link "Como funciona" do hub), fecha voltando
/// ao hub em vez de substituí-lo.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.reopened = false,
    this.storage = const OnboardingStorage(),
  });

  final bool reopened;
  final OnboardingStorage storage;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool toRegister}) async {
    await widget.storage.markSeen();
    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (widget.reopened) {
      if (toRegister) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const RegisterPage()),
        );
      } else {
        navigator.pop();
      }
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginHubPage()),
    );
    if (toRegister) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const RegisterPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RevisalogLockupHorizontal(height: 28),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('onboarding_skip'),
                    onPressed: () => _finish(toRegister: false),
                    child: const Text('Pular'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('onboarding_pages'),
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, i) => _SlideView(
                  slide: _slides[i],
                  position: i + 1,
                  total: _slides.length,
                ),
              ),
            ),
            Semantics(
              label: 'Página ${_index + 1} de ${_slides.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? scheme.primary : scheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: _isLast
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const Key('onboarding_register'),
                          onPressed: () => _finish(toRegister: true),
                          child: const Text('Criar conta grátis'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('onboarding_login'),
                          onPressed: () => _finish(toRegister: false),
                          child: const Text('Já tenho conta'),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        key: const Key('onboarding_next'),
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        child: const Text('Próximo'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.position,
    required this.total,
  });

  final _OnboardingSlide slide;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Semantics(
              container: true,
              label: 'Passo $position de $total',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(slide.icon, size: 36, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      slide.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (slide.showProvenance) ...[
                    const SizedBox(height: 20),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProvenanceChip(
                          label: ProvenanceTheme.sealLabel,
                          color: ProvenanceTheme.verifiedInk,
                          icon: Icons.verified,
                        ),
                        _ProvenanceChip(
                          label: ProvenanceTheme.declaredOwnerLabel,
                          color: ProvenanceTheme.declaredInk,
                          icon: Icons.edit_note,
                        ),
                      ],
                    ),
                  ],
                  if (slide.footnote != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      slide.footnote!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProvenanceChip extends StatelessWidget {
  const _ProvenanceChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ProvenanceTheme.verifiedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
