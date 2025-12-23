import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'api_service.dart';

class FcmService {
  final ApiService _apiService;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_token_registered';

  FcmService(this._apiService);

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      print('🔔 Inicializando FCM...');

      // Request permission for notifications
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('🔔 Status da permissão: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        print(
            '🔔 Token FCM obtido: ${token != null ? token.substring(0, 50) + "..." : "null"}');

        if (token != null) {
          await _registerToken(token);
        } else {
          print('⚠️ Token FCM é null');
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 Token FCM atualizado, registrando novamente...');
          _registerToken(newToken);
        });
      } else {
        print(
            '❌ Permissão de notificações negada: ${settings.authorizationStatus}');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao inicializar FCM: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerToken(String token) async {
    try {
      print('📤 Registrando token FCM no backend...');
      final prefs = await SharedPreferences.getInstance();
      final lastRegisteredToken = prefs.getString(_tokenKey);

      // Only register if token changed or not registered yet
      if (lastRegisteredToken != token) {
        print(
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

        print('📤 Resposta do backend: ${response.statusCode}');
        print('📤 Dados: ${response.data}');

        if (response.data['success'] == true) {
          await prefs.setString(_tokenKey, token);
          print('✅ FCM token registrado com sucesso!');
        } else {
          print('⚠️ Backend retornou success=false: ${response.data}');
        }
      } else {
        print('ℹ️ Token já está registrado, pulando...');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao registrar token FCM: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - token registration failure shouldn't block app
    }
  }

  /// Register token after login/registration
  Future<void> registerTokenAfterAuth() async {
    try {
      print('🔐 Autenticação realizada, aguardando para registrar FCM...');
      // Small delay to ensure user is authenticated and API token is set
      await Future.delayed(const Duration(seconds: 2));
      print('🔐 Iniciando registro de FCM após autenticação...');
      await initialize();
    } catch (e, stackTrace) {
      print('❌ Erro ao registrar FCM após autenticação: $e');
      print('Stack trace: $stackTrace');
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
      print('Error removing FCM token: $e');
    }
  }
}
