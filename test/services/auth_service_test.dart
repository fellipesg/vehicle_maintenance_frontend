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
