import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';
import 'notification_navigation.dart';

/// O título do push é conteúdo do usuário: fica fora de builds de release.
void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class PushNotificationSetup {
  static bool _configured = false;

  /// Chamado a cada push recebido com o app aberto (atualiza o badge do sino).
  static void Function()? onPushReceived;

  static Future<void> configure() async {
    if (_configured) {
      return;
    }

    await LocalNotificationService.instance.initialize(
      onTap: NotificationNavigation.openFromPayloadString,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];

      if (title == null || body == null) {
        _log('🔔 Mensagem FCM recebida sem título/corpo.');
        return;
      }

      _log('🔔 FCM recebido: $title');
      onPushReceived?.call();

      await LocalNotificationService.instance.show(
        id: message.hashCode,
        title: title,
        body: body,
        payload: NotificationNavigation.encodePayload(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onPushReceived?.call();
      NotificationNavigation.openFromMessage(message);
    });

    _configured = true;
  }

  static Future<void> handleInitialMessage() async {
    final launchDetails =
        await LocalNotificationService.instance.launchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      NotificationNavigation.openFromPayloadString(
        launchDetails!.notificationResponse?.payload,
      );
      return;
    }

    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      NotificationNavigation.openFromMessage(message);
    }
  }
}
