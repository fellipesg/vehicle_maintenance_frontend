import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../views/vehicles/vehicle_detail_page.dart';

class NotificationNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static int? vehicleIdFromPayload(Map<String, dynamic> data) {
    final raw = data['vehicle_id'];

    if (raw == null) {
      return null;
    }

    return int.tryParse(raw.toString());
  }

  static void openVehicleFromPayload(Map<String, dynamic> data) {
    final vehicleId = vehicleIdFromPayload(data);
    if (vehicleId == null) {
      return;
    }

    openVehicle(vehicleId);
  }

  static void openVehicleFromMessage(RemoteMessage message) {
    openVehicleFromPayload(message.data);
  }

  static void openVehicleFromPayloadString(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final vehicleId = int.tryParse(payload);
    if (vehicleId == null) {
      return;
    }

    openVehicle(vehicleId);
  }

  static void openVehicle(int vehicleId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => VehicleDetailPage(vehicleId: vehicleId),
      ),
    );
  }
}
