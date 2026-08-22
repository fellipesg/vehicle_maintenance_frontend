import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';
import 'notification_navigation.dart';

class PushNotificationSetup {
  static bool _configured = false;

  static Future<void> configure() async {
    if (_configured) {
      return;
    }

    await LocalNotificationService.instance.initialize(
      onTap: NotificationNavigation.openVehicleFromPayloadString,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];

      if (title == null || body == null) {
        print('🔔 Mensagem FCM recebida sem título/corpo.');
        return;
      }

      print('🔔 FCM recebido: $title');

      await LocalNotificationService.instance.show(
        id: message.hashCode,
        title: title,
        body: body,
        payload: message.data['vehicle_id']?.toString(),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
      NotificationNavigation.openVehicleFromMessage,
    );

    _configured = true;
  }

  static Future<void> handleInitialMessage() async {
    final launchDetails =
        await LocalNotificationService.instance.launchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      NotificationNavigation.openVehicleFromPayloadString(
        launchDetails!.notificationResponse?.payload,
      );
      return;
    }

    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      NotificationNavigation.openVehicleFromMessage(message);
    }
  }
}
