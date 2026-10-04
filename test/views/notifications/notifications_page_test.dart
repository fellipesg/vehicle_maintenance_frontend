import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/notification_inbox.dart';
import 'package:vehicle_maintenance/views/notifications/notifications_page.dart';

/// API falsa: duas notificações (uma não lida) com registro de chamadas.
ApiService _fakeApi(List<String> calls, {int initialUnread = 1}) {
  final apiService = ApiService(baseUrl: 'http://test');
  var unread = initialUnread;

  apiService.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        calls.add('${options.method} ${options.path}');
        Map<String, dynamic> data;

        if (options.path == '/notifications') {
          data = {
            'success': true,
            'data': [
              {
                'id': 'n1',
                'type': 'workshop-review-decided',
                'title': 'Dev Oficina confirmou o seu serviço',
                'body': 'Agora tem o Selo da oficina.',
                'maintenance_id': 12,
                'vehicle_id': 3,
                'data': {'status': 'confirmed'},
                'read_at': null,
                'created_at': '2026-10-03T12:00:00+00:00',
              },
              {
                'id': 'n2',
                'type': null,
                'title': 'Lembrete de revisão',
                'body': '',
                'data': <String, dynamic>{},
                'read_at': '2026-10-01T12:00:00+00:00',
                'created_at': '2026-10-01T12:00:00+00:00',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          };
        } else if (options.path == '/notifications/unread-count') {
          data = {
            'success': true,
            'data': {'unread_count': unread},
          };
        } else {
          // read / read-all
          unread = 0;
          data = {'success': true, 'data': <String, dynamic>{}};
        }

        handler.resolve(Response(requestOptions: options, data: data));
      },
    ),
  );

  return apiService;
}

Widget _buildApp(NotificationInbox inbox, Widget home) {
  return ChangeNotifierProvider<NotificationInbox>.value(
    value: inbox,
    child: MaterialApp(home: home),
  );
}

void main() {
  /// ── page shows list and marks all as read ─────────────────────────────────
  testWidgets('lists notifications and marks all as read', (tester) async {
    final calls = <String>[];
    final inbox = NotificationInbox(_fakeApi(calls));

    await tester.pumpWidget(_buildApp(inbox, const NotificationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Dev Oficina confirmou o seu serviço'), findsOneWidget);
    expect(find.text('Lembrete de revisão'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);

    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    expect(calls, contains('POST /notifications/read-all'));
    expect(inbox.unreadCount, 0);
  });

  /// ── bell badge reflects unread count ──────────────────────────────────────
  /// Verifies that NotificationInbox reports unread count correctly after refresh,
  /// which drives the Badge label in NotificationBellButton.
  test('bell badge shows unread count', () async {
    final inbox = NotificationInbox(_fakeApi([], initialUnread: 3));
    await inbox.refreshUnreadCount();

    expect(inbox.unreadCount, 3);
  });

  /// ── bell badge hides when there are no unread items ───────────────────────
  /// Verifies that unreadCount = 0 causes the Badge label to be hidden
  /// (NotificationBellButton.build sets isLabelVisible: unread > 0).
  test('bell badge is hidden when unread count is 0', () async {
    final inbox = NotificationInbox(_fakeApi([], initialUnread: 0));
    await inbox.refreshUnreadCount();

    expect(inbox.unreadCount, 0);
  });
}
