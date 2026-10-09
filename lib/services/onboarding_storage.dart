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
}
