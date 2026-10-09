import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'api_service.dart';

/// Diagnóstico de push só em debug. Estes logs chegavam a builds de release
/// carregando o token do aparelho e o corpo da resposta do backend.
void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class FcmService {
  final ApiService _apiService;
  final FirebaseMessaging? _firebaseMessaging;
  static const String _tokenKey = 'fcm_token_registered';

  FcmService(this._apiService)
      : _firebaseMessaging =
            Firebase.apps.isEmpty ? null : FirebaseMessaging.instance;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    final messaging = _firebaseMessaging;
    if (messaging == null) {
      return;
    }
    try {
      _log('🔔 Inicializando FCM...');

      if (const bool.fromEnvironment('SCREENSHOTS')) {
        _log('🔔 Permissão de notificações ignorada nesta execução.');
        return;
      }

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _log('🔔 Status da permissão: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (Platform.isIOS) {
          await _waitForApnsToken(messaging);
        }

        // Get FCM token
        String? token = await messaging.getToken();
        // O valor do token não vai para o log: ele identifica o aparelho e
        // chegava a aparecer em builds de release.
        _log(token != null
            ? '🔔 Token FCM obtido.'
            : '⚠️ Token FCM indisponível.');

        if (token != null) {
          await _registerToken(token);
        } else {
          _log('⚠️ Token FCM é null');
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _log('🔄 Token FCM atualizado, registrando novamente...');
          _registerToken(newToken);
        });
      } else {
        _log(
            '❌ Permissão de notificações negada: ${settings.authorizationStatus}');
      }
    } catch (e, stackTrace) {
      _log('❌ Erro ao inicializar FCM: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) {
        _log('🔔 APNS token disponível.');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    _log('⚠️ APNS token ainda indisponível após aguardar.');
  }

  /// Register FCM token with backend
  Future<void> _registerToken(String token) async {
    try {
      _log('📤 Registrando token FCM no backend...');
      final prefs = await SharedPreferences.getInstance();
      final lastRegisteredToken = prefs.getString(_tokenKey);

      // Only register if token changed or not registered yet
      if (lastRegisteredToken != token) {
        _log(
            '📤 Token mudou ou não foi registrado ainda, enviando para o backend...');
        final response = await _apiService.dio.post(
          '/fcm-tokens',
          data: {
            'token': token,
            'device_type': Platform.isAndroid
                ? 'android'
                : (Platform.isIOS ? 'ios' : 'web'),
          },
        );

        _log('📤 Resposta do backend: ${response.statusCode}');

        if (response.data['success'] == true) {
          await prefs.setString(_tokenKey, token);
          _log('✅ FCM token registrado com sucesso!');
        } else {
          _log('⚠️ Backend recusou o registro do token FCM.');
        }
      } else {
        _log('ℹ️ Token já está registrado, pulando...');
      }
    } catch (e, stackTrace) {
      _log('❌ Erro ao registrar token FCM: $e');
      _log('Stack trace: $stackTrace');
      // Don't throw - token registration failure shouldn't block app
    }
  }

  /// Register token after login/registration
  Future<void> registerTokenAfterAuth() async {
    try {
      _log('🔐 Autenticação realizada, aguardando para registrar FCM...');
      // Small delay to ensure user is authenticated and API token is set
      await Future.delayed(const Duration(seconds: 2));
      _log('🔐 Iniciando registro de FCM após autenticação...');
      await initialize();
    } catch (e, stackTrace) {
      _log('❌ Erro ao registrar FCM após autenticação: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  /// Remove token (on logout)
  Future<void> removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (token != null) {
        await _apiService.dio.delete('/fcm-tokens/$token');
        await prefs.remove(_tokenKey);
      }
    } catch (e) {
      _log('Error removing FCM token: $e');
    }
  }
}
