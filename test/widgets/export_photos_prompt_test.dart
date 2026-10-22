import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/onboarding_storage.dart';
import 'package:vehicle_maintenance/widgets/export_photos_prompt.dart';

import '../support_photos.dart';

/// Chama a pergunta como a HomePage faz ao abrir.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ExportPhotosPrompt.maybeAsk(context),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

Future<FakePhotosApi> _pump(
  WidgetTester tester,
  Map<String, dynamic> user,
) async {
  final api = FakePhotosApi();
  await tester
      .pumpWidget(providers(api, FakeAuth(api, user), child: const _Host()));
  await tester.pumpAndSettle();

  return api;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExportPhotosPrompt.resetSessionForTests();
  });

  testWidgets('pergunta quando a conta ainda não respondeu', (tester) async {
    await _pump(tester, {'user_type': 'user', 'export_include_photos': null});

    expect(find.text(exportPhotosQuestion), findsOneWidget);
    expect(
        find.textContaining('compartilhado com compradores'), findsOneWidget);
  });

  testWidgets('Sim grava true via PUT /me', (tester) async {
    final api = await _pump(
      tester,
      {'user_type': 'user', 'export_include_photos': null},
    );

    await tester.tap(find.byKey(const Key('export_photos_yes')));
    await tester.pumpAndSettle();

    expect(api.exportPreferenceWrites, [true]);
    expect(find.text(exportPhotosQuestion), findsNothing);
  });

  testWidgets('Não grava false', (tester) async {
    final api = await _pump(
      tester,
      {'user_type': 'user', 'export_include_photos': null},
    );

    await tester.tap(find.byKey(const Key('export_photos_no')));
    await tester.pumpAndSettle();

    expect(api.exportPreferenceWrites, [false]);
  });

  testWidgets('Agora não dispensa sem gravar', (tester) async {
    final api = await _pump(
      tester,
      {'user_type': 'user', 'export_include_photos': null},
    );

    await tester.tap(find.byKey(const Key('export_photos_later')));
    await tester.pumpAndSettle();

    expect(api.exportPreferenceWrites, isEmpty);
    expect(find.text(exportPhotosQuestion), findsNothing);
  });

  testWidgets('não pergunta se já respondeu', (tester) async {
    final api = await _pump(
      tester,
      {'user_type': 'user', 'export_include_photos': false},
    );

    expect(find.text(exportPhotosQuestion), findsNothing);
    expect(api.exportPreferenceWrites, isEmpty);
  });

  testWidgets('oficina nunca é perguntada', (tester) async {
    await _pump(
      tester,
      {'user_type': 'workshop', 'export_include_photos': null},
    );

    expect(find.text(exportPhotosQuestion), findsNothing);
  });

  testWidgets('backend sem o campo: não pergunta', (tester) async {
    await _pump(tester, {'user_type': 'user'});

    expect(find.text(exportPhotosQuestion), findsNothing);
  });

  testWidgets('aplica a resposta dada no onboarding em vez de perguntar',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      OnboardingStorage.exportPhotosAnswerKey: true,
    });

    final api = await _pump(
      tester,
      {'user_type': 'user', 'export_include_photos': null},
    );

    expect(find.text(exportPhotosQuestion), findsNothing);
    expect(api.exportPreferenceWrites, [true]);
    expect(await const OnboardingStorage().readExportPhotosAnswer(), isNull);
  });

  testWidgets('falha ao salvar mostra a mensagem', (tester) async {
    final api = FakePhotosApi()..exportPreferenceError = dioError(500, {});
    await tester.pumpWidget(
      providers(
        api,
        FakeAuth(api, {'user_type': 'user', 'export_include_photos': null}),
        child: const _Host(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_photos_yes')));
    await tester.pumpAndSettle();

    expect(find.textContaining('O servidor falhou'), findsOneWidget);
  });
}
