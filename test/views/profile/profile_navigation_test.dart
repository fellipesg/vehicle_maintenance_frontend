import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/views/home_page.dart';
import 'package:vehicle_maintenance/views/profile/profile_edit_page.dart';
import 'package:vehicle_maintenance/views/profile/settings_page.dart';

class FakeAuthTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<void> writeToken(String value) async {}
}

class FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

class TestAuthService extends AuthService {
  TestAuthService()
      : super(
          ApiService(baseUrl: 'http://test'),
          tokenStorage: FakeAuthTokenStorage(),
          fcmService: FakeFcmService(),
        ) {
    saveToken('test-token');
    saveUser(const {
      'name': 'Maria Silva',
      'email': 'maria@test.com',
      'avatar_url': null,
    });
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => user;
}

ApiService mockApiService() {
  final apiService = ApiService(baseUrl: 'http://test');
  apiService.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/my-vehicles') {
          handler.resolve(
            Response(
              requestOptions: options,
              data: const {'success': true, 'data': []},
            ),
          );
          return;
        }

        handler.next(options);
      },
    ),
  );

  return apiService;
}

Widget buildProfileTestApp(AuthService authService) {
  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: authService),
      Provider<ApiService>.value(value: mockApiService()),
    ],
    child: MaterialApp(
      home: const HomePage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile navigation', () {
    testWidgets('opens Meus Dados from profile tab', (tester) async {
      await tester.pumpWidget(buildProfileTestApp(TestAuthService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('Meus Dados'), findsOneWidget);

      await tester.tap(find.text('Meus Dados'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileEditPage), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('opens Configurações from profile tab', (tester) async {
      await tester.pumpWidget(buildProfileTestApp(TestAuthService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Segurança'), findsOneWidget);
      expect(find.text('Notificações'), findsOneWidget);
      expect(find.text('Sobre'), findsOneWidget);
      expect(find.text('Sair deste aparelho'), findsOneWidget);
    });
  });
}
