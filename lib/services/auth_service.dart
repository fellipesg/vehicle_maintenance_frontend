import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import 'dart:convert';

class AuthService {
  final ApiService _apiService;
  FcmService? _fcmService;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthService(this._apiService) {
    _fcmService = FcmService(_apiService);
  }

  // Expose _apiService for OAuth callback handling
  ApiService get apiService => _apiService;

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _apiService.setAuthToken(token);
  }

  // Expose _saveToken and _saveUser for OAuth callback
  Future<void> saveToken(String token) => _saveToken(token);
  Future<void> saveUser(Map<String, dynamic> user) => _saveUser(user);

  Future<void> _saveUser(Map<String, dynamic> user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userStr = prefs.getString(_userKey);

    if (token != null) {
      _token = token;
      _apiService.setAuthToken(token);

      // Register FCM token if user is already authenticated
      _fcmService?.registerTokenAfterAuth();
    }

    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? postalCode,
    String? street,
    String? number,
    String? complement,
    String? city,
    String? state,
    String? country,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'phone': phone,
          'postal_code': postalCode,
          'street': street,
          'number': number,
          'complement': complement,
          'city': city,
          'state': state,
          'country': country,
        },
      );

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        final user = response.data['data']['user'];
        await _saveToken(token);
        await _saveUser(user);

        // Register FCM token after successful registration
        _fcmService?.registerTokenAfterAuth();

        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Erro ao registrar: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        final user = response.data['data']['user'];
        await _saveToken(token);
        await _saveUser(user);

        // Register FCM token after successful login
        _fcmService?.registerTokenAfterAuth();

        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Erro ao fazer login: $e');
    }
  }

  Future<String?> getOAuthRedirectUrl(String provider,
      {bool forceAccountSelection = false}) async {
    try {
      // Get redirect URL from backend
      final redirectResponse = await _apiService.dio.get(
        '/auth/$provider/redirect',
      );

      if (redirectResponse.data['success'] == true) {
        String redirectUrl = redirectResponse.data['data']['redirect_url'];

        // For Google OAuth, add prompt parameter to force account selection
        // This ensures users can choose a different account even if already logged in
        if (provider == 'google' && forceAccountSelection) {
          final uri = Uri.parse(redirectUrl);
          final queryParams = Map<String, String>.from(uri.queryParameters);
          queryParams['prompt'] = 'select_account';
          redirectUrl = uri.replace(queryParameters: queryParams).toString();
        }

        return redirectUrl;
      }

      // Handle error response
      if (redirectResponse.data['error_code'] == 'OAUTH_NOT_CONFIGURED') {
        throw Exception('Login com $provider não está configurado no servidor. '
            'Por favor, use o login normal com email e senha.');
      }

      return null;
    } catch (e) {
      throw Exception('Erro ao obter URL de redirecionamento: $e');
    }
  }

  Future<bool> loginWithSSO(String provider) async {
    // This method is kept for backward compatibility
    // The actual OAuth flow is handled by opening the URL in native browser
    final redirectUrl = await getOAuthRedirectUrl(provider);
    return redirectUrl != null;
  }

  Future<void> processOAuthCallback(
      String provider, Map<String, String> queryParams) async {
    try {
      // Build the callback URL with query parameters
      // Laravel Socialite needs the code parameter in the URL
      final callbackPath = '/auth/$provider/callback';
      final queryString = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final callbackUrl =
          queryString.isNotEmpty ? '$callbackPath?$queryString' : callbackPath;

      // Make the request to the callback endpoint
      // Note: We need to use the full URL path with query parameters
      final response = await _apiService.dio.get(callbackUrl);

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        final user = response.data['data']['user'];
        await _saveToken(token);
        await _saveUser(user);

        // Register FCM token after successful OAuth login
        _fcmService?.registerTokenAfterAuth();
      } else {
        throw Exception(response.data['message'] ?? 'Erro ao processar login');
      }
    } catch (e) {
      throw Exception('Erro ao processar callback OAuth: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _apiService.dio.post('/logout');
      }
    } catch (e) {
      // Continue with logout even if API call fails
    } finally {
      // Remove FCM token on logout
      await _fcmService?.removeToken();

      _token = null;
      _user = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _apiService.setAuthToken(null);
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_token == null) {
      return null;
    }

    try {
      final response = await _apiService.dio.get('/me');
      if (response.data['success'] == true) {
        final user = response.data['data'];
        await _saveUser(user);
        return user;
      }
      return null;
    } catch (e) {
      return _user;
    }
  }
}
