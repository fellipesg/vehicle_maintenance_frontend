import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Contador de registros de oficina esperando decisão do proprietário.
///
/// Suposição de contrato: `pending_workshop_records_count` vem no payload de
/// `GET /me`. É o único lugar do app que lê esse campo; se o backend passar a
/// entregá-lo em outro endpoint, só `refresh` muda.
class WorkshopRecordsInbox extends ChangeNotifier {
  WorkshopRecordsInbox(this._apiService);

  final ApiService _apiService;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  Future<void> refresh() async {
    try {
      final response = await _apiService.getMe();
      final data = response.data is Map ? response.data['data'] : null;
      final raw = data is Map ? data['pending_workshop_records_count'] : null;

      setCount(int.tryParse('$raw') ?? 0);
    } catch (e) {
      debugPrint('WorkshopRecordsInbox: falha ao ler contador: $e');
    }
  }

  void setCount(int value) {
    final next = value < 0 ? 0 : value;
    if (next == _pendingCount) {
      return;
    }

    _pendingCount = next;
    notifyListeners();
  }

  void clear() => setCount(0);
}
