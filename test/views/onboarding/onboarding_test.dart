import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/onboarding_storage.dart';
import 'package:vehicle_maintenance/theme/app_theme.dart';
import 'package:vehicle_maintenance/views/auth/login_hub_page.dart';
import 'package:vehicle_maintenance/views/auth/register_page.dart';
import 'package:vehicle_maintenance/views/onboarding/launch_gate.dart';
import 'package:vehicle_maintenance/views/onboarding/onboarding_page.dart';

Widget _app({required bool authenticated}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: LaunchGate(
      isAuthenticated: authenticated,
      authenticatedBuilder: (_) => const Scaffold(body: Text('home-logado')),
    ),
  );
}

Future<void> _goToLastPage(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding_next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboarding_next')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('primeiro acesso mostra o onboarding', (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();

    expect(find.text('O histórico do carro viaja com o carro'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    expect(find.byType(LoginHubPage), findsNothing);
  });

  testWidgets('desliza entre as três páginas e mostra CTAs na última',
      (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta grátis'), findsNothing);
    await tester.drag(
      find.byKey(const Key('onboarding_pages')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selo da oficina ou declarada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Pronto para a venda'), findsOneWidget);
    expect(find.text('Grátis no lançamento.'), findsOneWidget);
    expect(find.text('Criar conta grátis'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
  });

  testWidgets('Pular vai ao hub e a segunda abertura pula o onboarding',
      (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginHubPage), findsOneWidget);
    expect(await const OnboardingStorage().isSeen(), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();
    expect(find.byType(LoginHubPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('Criar conta grátis abre o cadastro', (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();
    await _goToLastPage(tester);

    await tester.tap(find.byKey(const Key('onboarding_register')));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(await const OnboardingStorage().isSeen(), isTrue);
  });

  testWidgets('Já tenho conta abre o hub de login', (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();
    await _goToLastPage(tester);

    await tester.tap(find.byKey(const Key('onboarding_login')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginHubPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
  });

  testWidgets('usuário autenticado não vê o onboarding', (tester) async {
    await tester.pumpWidget(_app(authenticated: true));
    await tester.pumpAndSettle();

    expect(find.text('home-logado'), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('Como funciona no hub reabre o onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({
      OnboardingStorage.storageKey: true,
    });
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('login_hub_how_it_works')));
    await tester.tap(find.byKey(const Key('login_hub_how_it_works')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(LoginHubPage), findsOneWidget);
  });

  testWidgets('cabe em tela pequena com texto grande', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 480),
          textScaler: TextScaler.linear(1.8),
        ),
        child: _app(authenticated: false),
      ),
    );
    await tester.pumpAndSettle();
    await _goToLastPage(tester);

    expect(tester.takeException(), isNull);
  });
}
