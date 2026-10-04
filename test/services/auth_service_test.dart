import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/models/login_result.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';

class FakeAuthTokenStorage implements AuthTokenStorage {
  String? token;

  @override
  Future<void> deleteToken() async {
    token = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value;
  }
}

class FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService token storage', () {
    late FakeAuthTokenStorage tokenStorage;
    late ApiService apiService;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = FakeAuthTokenStorage();
      apiService = ApiService(baseUrl: 'http://localhost:8000/api/v1');
      authService = AuthService(
        apiService,
        tokenStorage: tokenStorage,
        fcmService: FakeFcmService(),
      );
    });

    test('saveToken stores token in secure storage only', () async {
      await authService.saveToken('secret-token');

      expect(tokenStorage.token, 'secret-token');
      expect(authService.token, 'secret-token');
      expect(authService.isAuthenticated, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureAuthTokenStorage.tokenKey), isNull);
    });

    test('loadStoredAuth reads token from secure storage', () async {
      tokenStorage.token = 'stored-token';

      await authService.loadStoredAuth();

      expect(authService.token, 'stored-token');
      expect(authService.isAuthenticated, isTrue);
    });

    test('loadStoredAuth migrates legacy SharedPreferences token', () async {
      SharedPreferences.setMockInitialValues({
        SecureAuthTokenStorage.tokenKey: 'legacy-token',
      });

      await authService.loadStoredAuth();

      expect(tokenStorage.token, 'legacy-token');
      expect(authService.token, 'legacy-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureAuthTokenStorage.tokenKey), isNull);
    });

    test('logout deletes secure token and clears auth state', () async {
      await authService.saveToken('secret-token');
      await authService.saveUser({'id': 1, 'name': 'Test User'});

      await authService.logout();

      expect(tokenStorage.token, isNull);
      expect(authService.token, isNull);
      expect(authService.user, isNull);
      expect(authService.isAuthenticated, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureAuthTokenStorage.tokenKey), isNull);
      expect(prefs.getString('user_data'), isNull);
    });

    test('deleteAccount on success clears token and user', () async {
      await authService.saveToken('secret-token');
      await authService.saveUser({'id': 1, 'name': 'Test User'});

      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/me' && options.method == 'DELETE') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'message': 'Account deleted successfully',
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      await authService.deleteAccount();

      expect(tokenStorage.token, isNull);
      expect(authService.token, isNull);
      expect(authService.user, isNull);
      expect(authService.isAuthenticated, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_data'), isNull);
    });

    test('deleteAccount on failure keeps the local session', () async {
      await authService.saveToken('secret-token');
      await authService.saveUser({'id': 1, 'name': 'Test User'});

      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/me' && options.method == 'DELETE') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 422,
                    data: {
                      'success': false,
                      'message': 'Não foi possível excluir a conta',
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      await expectLater(authService.deleteAccount(), throwsA(isA<Exception>()));

      expect(tokenStorage.token, 'secret-token');
      expect(authService.token, 'secret-token');
      expect(authService.isAuthenticated, isTrue);
    });

    test('login success persists token with full user payload', () async {
      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/login' && options.method == 'POST') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'token': 'login-token',
                      'token_type': 'Bearer',
                      'user': {
                        'id': 3,
                        'email': 'fgoncalves2008@gmail.com',
                        'user_type': 'user',
                        'vehicles': [
                          {'id': 1, 'license_plate': 'QOS6H54'},
                        ],
                      },
                    },
                    'message': 'Login successful',
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      final result = await authService.login(
        'fgoncalves2008@gmail.com',
        'password123',
        portal: 'usuario',
      );

      expect(result, isA<LoginSuccess>());
      expect(tokenStorage.token, 'login-token');
      expect(authService.user?['email'], 'fgoncalves2008@gmail.com');
    });

    test('loginWithApple posts the identity token and stores the session',
        () async {
      Map<String, dynamic>? body;
      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/auth/apple' && options.method == 'POST') {
              body = Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'token': 'apple-session',
                      'token_type': 'Bearer',
                      'user': {
                        'id': 9,
                        'email': 'relay@privaterelay.appleid.com',
                        'user_type': 'user',
                      },
                    },
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      final result = await authService.loginWithApple(
        identityToken: 'identity',
        rawNonce: 'nonce-raw',
        name: 'Ana Silva',
        portal: 'usuario',
      );

      expect(result, isA<LoginSuccess>());
      expect(body?['identity_token'], 'identity');
      expect(body?['nonce'], 'nonce-raw');
      expect(body?['name'], 'Ana Silva');
      expect(body?['portal'], 'usuario');
      expect(tokenStorage.token, 'apple-session');
      expect(authService.user?['email'], 'relay@privaterelay.appleid.com');
    });

    test('loadStoredAuth keeps user profile in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'user_data': '{"id":1,"name":"Test User"}',
      });

      await authService.loadStoredAuth();

      expect(authService.user, {'id': 1, 'name': 'Test User'});
    });
  });

  group('AuthService two-factor authentication', () {
    late FakeAuthTokenStorage tokenStorage;
    late ApiService apiService;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = FakeAuthTokenStorage();
      apiService = ApiService(baseUrl: 'http://localhost:8000/api/v1');
      authService = AuthService(
        apiService,
        tokenStorage: tokenStorage,
        fcmService: FakeFcmService(),
      );
    });

    test('login with requires_two_factor does not save token', () async {
      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/login' && options.method == 'POST') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'requires_two_factor': true,
                    'challenge_token': 'test-challenge-token',
                    'message': 'Two-factor authentication required.',
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      final result = await authService.login('user@test.com', 'password123');

      expect(result, isA<LoginNeedsTwoFactor>());
      expect(
        (result as LoginNeedsTwoFactor).challengeToken,
        'test-challenge-token',
      );
      expect(tokenStorage.token, isNull);
      expect(authService.token, isNull);
      expect(authService.isAuthenticated, isFalse);
    });

    test('completeTwoFactorChallenge success saves token', () async {
      apiService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/two-factor/challenge' &&
                options.method == 'POST') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'token': 'verified-token',
                      'user': {'id': 1, 'name': 'Test User'},
                      'token_type': 'Bearer',
                    },
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      final success = await authService.completeTwoFactorChallenge(
        challengeToken: 'test-challenge-token',
        code: '123456',
      );

      expect(success, isTrue);
      expect(tokenStorage.token, 'verified-token');
      expect(authService.token, 'verified-token');
      expect(authService.isAuthenticated, isTrue);
      expect(authService.user, {'id': 1, 'name': 'Test User'});
    });
  });
}
