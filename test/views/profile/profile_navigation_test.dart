import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/services/notification_inbox.dart';
import 'package:vehicle_maintenance/theme/theme_controller.dart';
import 'package:vehicle_maintenance/views/auth/login_hub_page.dart';
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

class DeletingAuthService extends TestAuthService {
  bool deleted = false;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
  }
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> scrollSettingsTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
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
  final apiService = mockApiService();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeController>(
        create: (_) => ThemeController(initialMode: ThemeMode.light),
      ),
      Provider<AuthService>.value(value: authService),
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider<VehicleRepository>(
        create: (_) => VehicleRepository(apiService),
      ),
      ChangeNotifierProvider<NotificationInbox>(
        create: (_) => NotificationInbox(apiService),
      ),
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
      useTallSurface(tester);
      await tester.pumpWidget(buildProfileTestApp(TestAuthService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Aparência'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Segurança'));
      expect(find.text('Segurança'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Conta'));
      expect(find.text('Conta'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Notificações'));
      expect(find.text('Notificações'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Sair deste aparelho'));
      expect(find.text('Sair deste aparelho'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Excluir conta'));
      expect(find.text('Excluir conta'), findsOneWidget);
      await scrollSettingsTo(tester, find.text('Sobre'));
      expect(find.text('Sobre'), findsOneWidget);
    });

    testWidgets('delete account dialog can be cancelled', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildProfileTestApp(TestAuthService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();
      await scrollSettingsTo(tester, find.text('Excluir conta'));
      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('O histórico de manutenções permanece no chassi'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirming delete account returns to login hub',
        (tester) async {
      useTallSurface(tester);
      final authService = DeletingAuthService();
      await tester.pumpWidget(buildProfileTestApp(authService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();
      await scrollSettingsTo(tester, find.text('Excluir conta'));
      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir conta'));
      await tester.pumpAndSettle();

      expect(authService.deleted, isTrue);
      expect(find.byType(LoginHubPage), findsOneWidget);
      expect(find.text('Como você deseja entrar?'), findsOneWidget);
    });
  });
}
