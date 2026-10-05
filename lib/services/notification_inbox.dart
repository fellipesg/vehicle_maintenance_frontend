import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'api_service.dart';

/// Caixa de notificações da conta: contador de não lidas (badge do sino) e lista paginada.
class NotificationInbox extends ChangeNotifier {
  NotificationInbox(this._apiService);

  final ApiService _apiService;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool get isLoading => _loading;
  bool get hasMore => _page < _lastPage;

  String? _error;
  String? get error => _error;

  Future<void> refreshUnreadCount() async {
    try {
      final response =
          await _apiService.dio.get('/notifications/unread-count');
      final count = response.data?['data']?['unread_count'];
      _setUnread(int.tryParse(count.toString()) ?? 0);
    } catch (e) {
      debugPrint('NotificationInbox: falha ao ler contador: $e');
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _lastPage = 1;
    _items.clear();
    await loadMore();
    await refreshUnreadCount();
  }

  Future<void> loadMore() async {
    if (_loading || !hasMore) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get(
        '/notifications',
        queryParameters: {'page': _page + 1, 'per_page': 20},
      );
      final body = response.data as Map<String, dynamic>;
      final rows = (body['data'] as List?) ?? const [];
      _items.addAll(rows.map(
        (row) => AppNotification.fromJson(Map<String, dynamic>.from(row)),
      ));
      final meta = body['meta'] as Map<String, dynamic>?;
      _page = int.tryParse('${meta?['current_page']}') ?? _page + 1;
      _lastPage = int.tryParse('${meta?['last_page']}') ?? _page;
    } catch (e) {
      _error = 'Não foi possível carregar as notificações.';
      debugPrint('NotificationInbox: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (!notification.isUnread) return;

    _replace(notification.markedAsRead());
    _setUnread(_unreadCount > 0 ? _unreadCount - 1 : 0);

    try {
      await _apiService.dio.post('/notifications/${notification.id}/read');
    } catch (e) {
      debugPrint('NotificationInbox: falha ao marcar como lida: $e');
    }
  }

  Future<void> markAllAsRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].markedAsRead();
    }
    _setUnread(0);

    try {
      await _apiService.dio.post('/notifications/read-all');
    } catch (e) {
      debugPrint('NotificationInbox: falha ao marcar todas: $e');
    }
  }

  void _replace(AppNotification updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      _items[index] = updated;
    }
  }

  void _setUnread(int value) {
    _unreadCount = value;
    notifyListeners();
  }
}
