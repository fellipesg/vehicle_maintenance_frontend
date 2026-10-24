import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';

/// Recurso "fotos das manutenções", liberado por conta pelo administrador.
///
/// Vem em `features.maintenance_photos` no usuário (`GET /me`, login e
/// cadastro). Chave ausente ou valor diferente de `true` significa desligado:
/// um backend sem o recurso nunca habilita as fotos no app.
class MaintenancePhotosFeature {
  const MaintenancePhotosFeature._();

  static const String featuresField = 'features';
  static const String field = 'maintenance_photos';

  static const String disabledMessage =
      'Fotos não estão habilitadas para sua conta.';

  static bool isEnabledFor(Map<String, dynamic>? user) {
    final features = user?[featuresField];

    return features is Map && features[field] == true;
  }

  /// Lê do [AuthService] do contexto; sem provider (ou sem conta) é desligado.
  static bool of(BuildContext context) {
    try {
      return context.read<AuthService>().hasMaintenancePhotos;
    } catch (_) {
      return false;
    }
  }
}
