import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle.dart';
import '../services/api_service.dart';

class VehicleRepository extends ChangeNotifier {
  VehicleRepository(this._apiService);

  static const String _snapshotKey = 'vehicles.snapshot.v1';

  final ApiService _apiService;

  List<Vehicle> _vehicles = [];
  bool _isRefreshing = false;
  DateTime? _lastSyncedAt;
  String? _etag;
  Object? _error;
  bool _hydratedFromSnapshot = false;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  bool get isRefreshing => _isRefreshing;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  Object? get error => _error;

  bool get hasCachedVehicles => _vehicles.isNotEmpty;

  Future<void> load({bool force = false}) async {
    _error = null;

    if (!_hydratedFromSnapshot) {
      await _restoreSnapshot();
      _hydratedFromSnapshot = true;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      final response = await _apiService.getMyVehicles(
        ifNoneMatch: force ? null : _etag,
      );

      if (response.statusCode == 304) {
        _lastSyncedAt = DateTime.now();
        return;
      }

      if (response.statusCode == 200 && response.data is Map) {
        final envelope = Map<String, dynamic>.from(response.data as Map);
        if (envelope['success'] == true) {
          final data = envelope['data'];
          if (data is List) {
            _vehicles = data
                .map((item) => Vehicle.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList();
          }
          _etag =
              response.headers.value('etag') ?? response.headers.value('ETag');
          _lastSyncedAt = DateTime.now();
          await _persistSnapshot();
        }
      }
    } catch (e) {
      _error = e;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> invalidate() async {
    _etag = null;
    await load(force: true);
  }

  Future<void> clear() async {
    _vehicles = [];
    _etag = null;
    _lastSyncedAt = null;
    _error = null;
    _hydratedFromSnapshot = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    notifyListeners();
  }

  Vehicle? findById(int id) {
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }

    return null;
  }

  Future<void> _restoreSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = decoded['savedAt'] as String?;
      _etag = decoded['etag'] as String?;
      final list = decoded['vehicles'];
      if (list is List) {
        _vehicles = list
            .map((item) => Vehicle.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
        if (savedAt != null) {
          _lastSyncedAt = DateTime.tryParse(savedAt);
        }
        notifyListeners();
      }
    } catch (_) {
      await prefs.remove(_snapshotKey);
    }
  }

  Future<void> _persistSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'savedAt': (_lastSyncedAt ?? DateTime.now()).toIso8601String(),
      'etag': _etag,
      'vehicles': _vehicles.map((vehicle) => vehicle.toJson()).toList(),
    };
    await prefs.setString(_snapshotKey, jsonEncode(payload));
  }
}
