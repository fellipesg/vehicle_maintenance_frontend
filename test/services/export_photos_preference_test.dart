import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/export_photos_preference.dart';
import 'package:vehicle_maintenance/services/onboarding_storage.dart';

import '../support_photos.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('usa o valor do usuário em cache sem chamar a rede', () async {
    final api = FakePhotosApi();
    final auth =
        FakeAuth(api, {'user_type': 'user', 'export_include_photos': true});

    final result = await ExportPhotosPreference.resolve(auth);

    expect(result.supported, isTrue);
    expect(result.value, isTrue);
    expect(api.meCalls, 0);
  });

  test('null em cache significa "nunca perguntado"', () async {
    final api = FakePhotosApi();
    final auth =
        FakeAuth(api, {'user_type': 'user', 'export_include_photos': null});

    final result = await ExportPhotosPreference.resolve(auth);

    expect(result.supported, isTrue);
    expect(result.value, isNull);
  });

  test('sem o campo em cache lê GET /me e guarda no usuário', () async {
    final api = FakePhotosApi(me: {'export_include_photos': false});
    final auth = FakeAuth(api, {'user_type': 'user'});

    final result = await ExportPhotosPreference.resolve(auth);

    expect(api.meCalls, 1);
    expect(result.supported, isTrue);
    expect(result.value, isFalse);
    expect(auth.user!['export_include_photos'], isFalse);
  });

  test('backend sem o campo: não suportado', () async {
    final api = FakePhotosApi(me: {'name': 'Ana'});
    final auth = FakeAuth(api, {'user_type': 'user'});

    final result = await ExportPhotosPreference.resolve(auth);

    expect(result.supported, isFalse);
  });

  test('save grava no servidor e no usuário em cache', () async {
    final api = FakePhotosApi();
    final auth =
        FakeAuth(api, {'user_type': 'user', 'export_include_photos': null});

    await ExportPhotosPreference.save(auth, true);

    expect(api.exportPreferenceWrites, [true]);
    expect(auth.user!['export_include_photos'], isTrue);
  });

  test('oficina não tem a pergunta', () {
    final api = FakePhotosApi();

    expect(
      ExportPhotosPreference.appliesTo(
          FakeAuth(api, {'user_type': 'workshop'})),
      isFalse,
    );
    expect(
      ExportPhotosPreference.appliesTo(FakeAuth(api, {'user_type': 'user'})),
      isTrue,
    );
  });

  test('OnboardingStorage guarda e limpa a resposta pré-login', () async {
    const storage = OnboardingStorage();

    expect(await storage.readExportPhotosAnswer(), isNull);
    await storage.saveExportPhotosAnswer(false);
    expect(await storage.readExportPhotosAnswer(), isFalse);
    await storage.clearExportPhotosAnswer();
    expect(await storage.readExportPhotosAnswer(), isNull);
  });
}
