import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../views/maintenances/maintenance_detail_page.dart';
import '../views/notifications/notifications_page.dart';
import '../views/vehicles/vehicle_detail_page.dart';

/// Para onde um push (ou um item da lista de notificações) leva.
enum NotificationTarget { maintenance, vehicle, inbox }

class NotificationNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Tipos que abrem a manutenção citada (resposta da oficina à validação).
  static const Set<String> maintenanceTypes = {'workshop-review-decided'};

  static int? vehicleIdFromPayload(Map<String, dynamic> data) {
    return _toInt(data['vehicle_id']);
  }

  static int? maintenanceIdFromPayload(Map<String, dynamic> data) {
    return _toInt(data['maintenance_id']);
  }

  static NotificationTarget targetFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();

    if (maintenanceTypes.contains(type) &&
        maintenanceIdFromPayload(data) != null) {
      return NotificationTarget.maintenance;
    }

    if (vehicleIdFromPayload(data) != null) {
      return NotificationTarget.vehicle;
    }

    return NotificationTarget.inbox;
  }

  /// Payload da notificação local: o data do push em JSON. Aceita também o formato antigo
  /// (só o vehicle_id como texto).
  static String encodePayload(Map<String, dynamic> data) => jsonEncode(data);

  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final legacyVehicleId = int.tryParse(payload);
    if (legacyVehicleId != null) {
      return {'vehicle_id': legacyVehicleId};
    }

    try {
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static void openFromData(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    switch (targetFor(data)) {
      case NotificationTarget.maintenance:
        navigator.push(MaterialPageRoute<void>(
          builder: (context) => MaintenanceDetailPage(
            maintenanceId: maintenanceIdFromPayload(data)!,
          ),
        ));
      case NotificationTarget.vehicle:
        openVehicle(vehicleIdFromPayload(data)!);
      case NotificationTarget.inbox:
        navigator.push(MaterialPageRoute<void>(
          builder: (context) => const NotificationsPage(),
        ));
    }
  }

  static void openFromMessage(RemoteMessage message) {
    openFromData(message.data);
  }

  static void openFromPayloadString(String? payload) {
    final data = decodePayload(payload);
    if (data != null) {
      openFromData(data);
    }
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

  static int? _toInt(dynamic raw) {
    if (raw == null) {
      return null;
    }

    return int.tryParse(raw.toString());
  }
}
