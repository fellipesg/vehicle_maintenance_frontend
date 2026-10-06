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
  bool _adminMode = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  DateTime? _lastSyncedAt;
  String? _etag;
  Object? _error;
  bool _hydratedFromSnapshot = false;
  int _loadedPage = 1;
  int? _lastPage;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  bool get isRefreshing => _isRefreshing;

  bool get isLoadingMore => _isLoadingMore;

  /// O backend pagina `/my-vehicles` e `/admin/vehicles`; sem isso a lista
  /// parava na primeira página sem nenhum sinal de que havia mais.
  bool get hasMore => _lastPage != null && _loadedPage < _lastPage!;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  Object? get error => _error;

  bool get hasCachedVehicles => _vehicles.isNotEmpty;

  bool get isAdminMode => _adminMode;

  void setAdminMode(bool enabled) {
    if (_adminMode == enabled) {
      return;
    }
    _adminMode = enabled;
    _etag = null;
    _resetPaging();
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    _error = null;

    if (!_hydratedFromSnapshot) {
      await _restoreSnapshot();
      _hydratedFromSnapshot = true;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      final response = _adminMode
          ? await _apiService.getAdminVehicles()
          : await _apiService.getMyVehicles(
              ifNoneMatch: force ? null : _etag,
            );

      // 304: nada mudou, então as páginas já carregadas seguem válidas.
      if (!_adminMode && response.statusCode == 304) {
        _lastSyncedAt = DateTime.now();
        return;
      }

      if (response.statusCode == 200 && response.data is Map) {
        final envelope = Map<String, dynamic>.from(response.data as Map);
        if (envelope['success'] == true) {
          final data = envelope['data'];
          if (data is List) {
            _vehicles = _parseVehicles(data);
          }
          _loadedPage = 1;
          _lastPage = _lastPageFrom(envelope);
          _etag = !_adminMode
              ? (response.headers.value('etag') ??
                  response.headers.value('ETag'))
              : null;
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

  /// Busca e acrescenta a próxima página. Não manda `If-None-Match`: o ETag
  /// guardado é o da primeira página (o fingerprint do backend inclui `page`).
  Future<void> loadMore() async {
    if (_isLoadingMore || _isRefreshing || !hasMore) {
      return;
    }

    _error = null;
    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _loadedPage + 1;

    try {
      final response = _adminMode
          ? await _apiService.getAdminVehicles(page: nextPage)
          : await _apiService.getMyVehicles(page: nextPage);

      if (response.statusCode == 200 && response.data is Map) {
        final envelope = Map<String, dynamic>.from(response.data as Map);
        if (envelope['success'] == true) {
          final data = envelope['data'];
          if (data is List) {
            _appendVehicles(_parseVehicles(data));
          }
          _loadedPage = nextPage;
          _lastPage = _lastPageFrom(envelope) ?? _lastPage;
          await _persistSnapshot();
        }
      }
    } catch (e) {
      _error = e;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> invalidate() async {
    _etag = null;
    _resetPaging();
    await load(force: true);
  }

  Future<void> clear() async {
    _vehicles = [];
    _etag = null;
    _lastSyncedAt = null;
    _error = null;
    _hydratedFromSnapshot = false;
    _adminMode = false;
    _resetPaging();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    notifyListeners();
  }

  void _resetPaging() {
    _loadedPage = 1;
    _lastPage = null;
  }

  List<Vehicle> _parseVehicles(List<dynamic> data) {
    return data
        .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Ignora o que já está na lista: a página seguinte pode repetir um veículo se
  /// a ordenação mudar no servidor entre as duas requisições.
  void _appendVehicles(List<Vehicle> incoming) {
    final knownIds = _vehicles.map((vehicle) => vehicle.id).toSet();

    _vehicles = [
      ..._vehicles,
      ...incoming.where((vehicle) => !knownIds.contains(vehicle.id)),
    ];
  }

  static int? _lastPageFrom(Map<String, dynamic> envelope) {
    final meta = envelope['meta'];
    if (meta is! Map) {
      return null;
    }

    final lastPage = meta['last_page'];
    if (lastPage is int) {
      return lastPage;
    }

    return int.tryParse(lastPage?.toString() ?? '');
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
        _vehicles = _parseVehicles(list);
        // Restaurados junto da lista: com ETag válido o refresh responde 304 e
        // não traz `meta`, e sem eles o "carregar mais" sumiria.
        _loadedPage = decoded['loadedPage'] is int ? decoded['loadedPage'] as int : 1;
        _lastPage = decoded['lastPage'] is int ? decoded['lastPage'] as int : null;
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
      'loadedPage': _loadedPage,
      'lastPage': _lastPage,
      'vehicles': _vehicles.map((vehicle) => vehicle.toJson()).toList(),
    };
    await prefs.setString(_snapshotKey, jsonEncode(payload));
  }
}
