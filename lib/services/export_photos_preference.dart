import 'api_service.dart';
import 'auth_service.dart';

/// Preferência "incluir as fotos das manutenções no PDF do histórico".
///
/// Vive em `export_include_photos` no usuário (`GET /me`, `PUT /me`):
/// `null` = nunca perguntado, `true`/`false` = resposta do usuário. Oficinas
/// não exportam o histórico, então não têm a pergunta.
class ExportPhotosPreference {
  const ExportPhotosPreference._();

  static const String field = 'export_include_photos';

  /// A pergunta só faz sentido para quem exporta o histórico (não oficina).
  /// Sem o recurso de fotos na conta, não há o que incluir no PDF.
  static bool appliesTo(AuthService auth) =>
      auth.isAuthenticated && !auth.isWorkshopUser && auth.hasMaintenancePhotos;

  /// Valor atual. `supported` é falso quando nem o usuário em cache nem o
  /// `GET /me` trazem o campo (backend sem a funcionalidade ou sem rede): nesse
  /// caso o app não pergunta nem mostra o interruptor.
  static Future<({bool supported, bool? value})> resolve(
    AuthService auth,
  ) async {
    final cached = auth.user;
    if (cached != null && cached.containsKey(field)) {
      return (supported: true, value: _asBool(cached[field]));
    }

    try {
      final response = await auth.apiService.getMe();
      final data = response.data is Map ? response.data['data'] : null;

      if (data is Map && data.containsKey(field)) {
        final value = _asBool(data[field]);
        await _remember(auth, value);

        return (supported: true, value: value);
      }
    } catch (_) {
      // Sem resposta, não incomoda o usuário.
    }

    return (supported: false, value: null);
  }

  /// Grava no servidor e atualiza o usuário em cache. Lança em caso de erro.
  static Future<void> save(AuthService auth, bool value) async {
    final ApiService api = auth.apiService;
    await api.updateExportIncludePhotos(value);
    await _remember(auth, value);
  }

  static Future<void> _remember(AuthService auth, bool? value) async {
    final user = auth.user;
    if (user == null) {
      return;
    }

    await auth.saveUser({...user, field: value});
  }

  static bool? _asBool(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw == 1 || raw == '1') {
      return true;
    }
    if (raw == 0 || raw == '0') {
      return false;
    }

    return null;
  }
}
