import 'package:shared_preferences/shared_preferences.dart';

/// Guarda se o onboarding de primeiro acesso já foi concluído ou pulado.
class OnboardingStorage {
  const OnboardingStorage();

  static const String storageKey = 'onboarding_seen_v1';

  Future<bool> isSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey) ?? false;
    } catch (_) {
      // Sem acesso ao armazenamento, não bloqueia a entrada no app.
      return true;
    }
  }

  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, true);
    } catch (_) {
      // Pior caso: o onboarding aparece de novo na próxima abertura.
    }
  }

  static const String exportPhotosAnswerKey = 'onboarding_export_photos_v1';

  /// Resposta à pergunta "incluir as fotos no PDF?" dada antes do login. Fica
  /// guardada no aparelho até existir uma conta para receber o `PUT /me`.
  Future<void> saveExportPhotosAnswer(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(exportPhotosAnswerKey, value);
    } catch (_) {
      // Sem armazenamento, a pergunta é refeita depois do login.
    }
  }

  Future<bool?> readExportPhotosAnswer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(exportPhotosAnswerKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearExportPhotosAnswer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(exportPhotosAnswerKey);
    } catch (_) {
      // Pior caso: a resposta é reaplicada na próxima conta sem preferência.
    }
  }
}
