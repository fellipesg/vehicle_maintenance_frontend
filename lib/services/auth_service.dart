import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_result.dart';
import 'api_service.dart';
import 'auth_token_storage.dart';
import 'fcm_service.dart';

class AuthService {
  final ApiService _apiService;
  final AuthTokenStorage _tokenStorage;
  FcmService? _fcmService;
  static const String _legacyTokenKey = SecureAuthTokenStorage.tokenKey;
  static const String _userKey = 'user_data';

  AuthService(
    this._apiService, {
    AuthTokenStorage? tokenStorage,
    FcmService? fcmService,
  })  : _tokenStorage = tokenStorage ?? SecureAuthTokenStorage() {
    _fcmService = fcmService ?? FcmService(_apiService);
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
    await _tokenStorage.writeToken(token);
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

  Future<void> _migrateLegacyTokenIfNeeded(SharedPreferences prefs) async {
    final legacyToken = prefs.getString(_legacyTokenKey);
    if (legacyToken == null) {
      return;
    }

    await _tokenStorage.writeToken(legacyToken);
    await prefs.remove(_legacyTokenKey);
  }

  Future<void> loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTokenIfNeeded(prefs);

    final token = await _tokenStorage.readToken();
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
    String userType = 'user',
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
          'user_type': userType,
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

  Future<LoginResult> login(String email, String password,
      {String? portal}) async {
    try {
      final response = await _apiService.dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          if (portal != null) 'portal': portal,
        },
      );

      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      throw Exception(message ?? 'Erro ao fazer login');
    } catch (e) {
      throw Exception('Erro ao fazer login: $e');
    }
  }

  Future<bool> completeTwoFactorChallenge({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/two-factor/challenge',
        data: {
          'challenge_token': challengeToken,
          if (code != null) 'code': code,
          if (recoveryCode != null) 'recovery_code': recoveryCode,
        },
      );

      final result = await _parseAuthResponse(response.data);
      return result is LoginSuccess;
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      throw Exception(message ?? 'Código de verificação inválido');
    } catch (e) {
      throw Exception('Erro ao verificar autenticação em duas etapas: $e');
    }
  }

  Future<LoginResult> _parseAuthResponse(dynamic data) async {
    if (data is! Map) {
      return const LoginFailure();
    }

    if (data['success'] != true) {
      return const LoginFailure();
    }

    if (data['requires_two_factor'] == true) {
      final challengeToken = data['challenge_token']?.toString();
      if (challengeToken == null || challengeToken.isEmpty) {
        return const LoginFailure();
      }

      return LoginNeedsTwoFactor(challengeToken: challengeToken);
    }

    final tokenData = data['data'];
    if (tokenData is! Map || tokenData['token'] == null) {
      return const LoginFailure();
    }

    await _saveToken(tokenData['token'].toString());
    await _saveUser(Map<String, dynamic>.from(tokenData['user'] as Map));

    _fcmService?.registerTokenAfterAuth();

    return const LoginSuccess();
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

  Future<LoginResult> processOAuthCallback(
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

      final result = await _parseAuthResponse(response.data);
      if (result is LoginFailure) {
        final message = response.data is Map
            ? response.data['message']?.toString()
            : null;
        throw Exception(message ?? 'Erro ao processar login');
      }

      return result;
    } catch (e) {
      throw Exception('Erro ao processar callback OAuth: $e');
    }
  }

  Future<void> logout() async {
    try {
      // Remove FCM token while the Bearer token is still valid
      await _fcmService?.removeToken();

      if (_token != null) {
        await _apiService.dio.post('/logout');
      }
    } catch (e) {
      // Continue with logout even if API call fails
    } finally {
      _token = null;
      _user = null;
      final prefs = await SharedPreferences.getInstance();
      await _tokenStorage.deleteToken();
      await prefs.remove(_legacyTokenKey);
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

  Future<bool> updateProfile({
    required String name,
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
      final response = await _apiService.updateProfile({
        'name': name,
        'phone': phone,
        'postal_code': postalCode,
        'street': street,
        'number': number,
        'complement': complement,
        'city': city,
        'state': state,
        'country': country,
      });

      if (response.data['success'] == true) {
        await _saveUser(Map<String, dynamic>.from(response.data['data'] as Map));
        return true;
      }

      return false;
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      throw Exception(message ?? 'Erro ao atualizar perfil');
    } catch (e) {
      throw Exception('Erro ao atualizar perfil: $e');
    }
  }

  Future<bool> uploadAvatar(File file) async {
    try {
      final response = await _apiService.uploadAvatar(file);

      if (response.data['success'] == true) {
        final userData = response.data['data'];
        if (userData is Map) {
          await _saveUser(Map<String, dynamic>.from(userData));
        } else if (_user != null && response.data['avatar_url'] != null) {
          final updatedUser = Map<String, dynamic>.from(_user!);
          updatedUser['avatar_url'] = response.data['avatar_url'];
          await _saveUser(updatedUser);
        }
        return true;
      }

      return false;
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      throw Exception(message ?? 'Erro ao enviar foto');
    } catch (e) {
      throw Exception('Erro ao enviar foto: $e');
    }
  }
}
