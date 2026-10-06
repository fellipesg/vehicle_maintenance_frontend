import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/login_portal.dart';
import 'package:vehicle_maintenance/models/login_result.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/apple_sign_in.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/services/notification_inbox.dart';
import 'package:vehicle_maintenance/views/auth/login_hub_page.dart';
import 'package:vehicle_maintenance/views/auth/login_page.dart';
import 'package:vehicle_maintenance/views/home_page.dart';

class FakeAuthTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}

class FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

class RecordingAuthService extends AuthService {
  RecordingAuthService({this.loginHandler})
      : super(
          ApiService(baseUrl: 'http://test'),
          tokenStorage: FakeAuthTokenStorage(),
          fcmService: FakeFcmService(),
        );

  Future<LoginResult> Function(
    String email,
    String password, {
    String? portal,
  })? loginHandler;

  String? lastEmail;
  String? lastPassword;
  String? lastPortal;
  String? lastAppleIdentityToken;
  String? lastAppleNonce;
  String? lastAppleName;
  String? lastApplePortal;
  String? lastGoogleIdToken;
  String? lastGooglePortal;

  @override
  Future<LoginResult> login(
    String email,
    String password, {
    String? portal,
  }) async {
    lastEmail = email;
    lastPassword = password;
    lastPortal = portal;

    if (loginHandler != null) {
      return loginHandler!(email, password, portal: portal);
    }

    return const LoginSuccess();
  }

  @override
  Future<LoginResult> loginWithApple({
    required String identityToken,
    required String rawNonce,
    String? name,
    String? portal,
  }) async {
    lastAppleIdentityToken = identityToken;
    lastAppleNonce = rawNonce;
    lastAppleName = name;
    lastApplePortal = portal;

    return const LoginSuccess();
  }

  @override
  Future<LoginResult> loginWithGoogle({
    required String idToken,
    String? portal,
  }) async {
    lastGoogleIdToken = idToken;
    lastGooglePortal = portal;

    return const LoginSuccess();
  }
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

Widget buildLoginTestApp({
  required Widget home,
  required AuthService authService,
  ApiService? apiService,
}) {
  final resolvedApi = apiService ?? mockApiService();

  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: authService),
      Provider<ApiService>.value(value: resolvedApi),
      ChangeNotifierProvider<VehicleRepository>(
        create: (_) => VehicleRepository(resolvedApi),
      ),
      ChangeNotifierProvider<NotificationInbox>(
        create: (_) => NotificationInbox(resolvedApi),
      ),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> submitLoginForm(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.tap(find.byKey(const Key('login_submit_button')));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginHubPage', () {
    testWidgets('shows hub copy and only app-visible portal cards',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginHubPage()),
      );

      expect(find.text('Como você deseja entrar?'), findsOneWidget);

      for (final portal in LoginPortal.values.where((p) => p.showInHub)) {
        expect(find.text(portal.hubTitle), findsOneWidget);
      }

      for (final portal in LoginPortal.values.where((p) => !p.showInHub)) {
        expect(find.text(portal.hubTitle), findsNothing);
      }
    });

    for (final portal in LoginPortal.values.where((p) => p.showInHub)) {
      testWidgets('navigates to ${portal.apiValue} login title',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LoginHubPage()),
        );

        await tester
            .ensureVisible(find.byKey(Key('login_hub_portal_${portal.name}')));
        await tester.tap(find.byKey(Key('login_hub_portal_${portal.name}')));
        await tester.pumpAndSettle();

        expect(find.text(portal.title), findsOneWidget);
      });
    }
  });

  group('LoginPage portal login', () {
    for (final portal in LoginPortal.values) {
      testWidgets(
        'submits credentials with portal ${portal.apiValue}',
        (tester) async {
          final authService = RecordingAuthService();

          await tester.pumpWidget(
            buildLoginTestApp(
              home: LoginPage(portal: portal),
              authService: authService,
            ),
          );

          expect(find.text(portal.title), findsOneWidget);

          await submitLoginForm(
            tester,
            email: '${portal.apiValue}@test.com',
            password: 'password123',
          );

          expect(authService.lastEmail, '${portal.apiValue}@test.com');
          expect(authService.lastPassword, 'password123');
          expect(authService.lastPortal, portal.apiValue);
          expect(find.byType(HomePage), findsOneWidget);
        },
      );
    }

    testWidgets(
      'lojista portal shows portal access snackbar on 403-style error',
      (tester) async {
        final authService = RecordingAuthService(
          loginHandler: (_, __, {portal}) async {
            throw Exception('403: acesso a este portal negado');
          },
        );

        await tester.pumpWidget(
          buildLoginTestApp(
            home: const LoginPage(portal: LoginPortal.lojista),
            authService: authService,
          ),
        );

        await submitLoginForm(
          tester,
          email: 'owner@test.com',
          password: 'password123',
        );

        expect(authService.lastPortal, LoginPortal.lojista.apiValue);
        expect(
          find.text('Esta conta não tem acesso a este portal.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('offers Sign in with Apple above the other social logins',
        (tester) async {
      final authService = RecordingAuthService();

      await tester.pumpWidget(
        buildLoginTestApp(
          home: LoginPage(
            portal: LoginPortal.usuario,
            appleSignInEnabled: true,
            loadAppleCredential: () async => const AppleSignInCredential(
              identityToken: 'apple-token',
              rawNonce: 'raw-nonce',
              givenName: 'Ana',
              familyName: 'Silva',
            ),
          ),
          authService: authService,
        ),
      );

      expect(find.text('Continuar com a Apple'), findsOneWidget);
      expect(find.text('Continuar com Google'), findsOneWidget);

      final appleTop =
          tester.getTopLeft(find.byKey(const Key('login_apple_button'))).dy;
      final googleTop = tester.getTopLeft(find.text('Continuar com Google')).dy;
      expect(appleTop, lessThan(googleTop));

      await tester.ensureVisible(find.byKey(const Key('login_apple_button')));
      await tester.tap(find.byKey(const Key('login_apple_button')));
      await tester.pumpAndSettle();

      expect(authService.lastAppleIdentityToken, 'apple-token');
      expect(authService.lastAppleNonce, 'raw-nonce');
      expect(authService.lastAppleName, 'Ana Silva');
      expect(authService.lastApplePortal, 'usuario');
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('hides Sign in with Apple when it is disabled', (tester) async {
      await tester.pumpWidget(
        buildLoginTestApp(
          home: const LoginPage(
            portal: LoginPortal.usuario,
            appleSignInEnabled: false,
          ),
          authService: RecordingAuthService(),
        ),
      );

      expect(find.text('Continuar com a Apple'), findsNothing);
      expect(find.text('Continuar com Google'), findsOneWidget);
    });

    testWidgets('signs in with Google using the native id token',
        (tester) async {
      final authService = RecordingAuthService();

      await tester.pumpWidget(
        buildLoginTestApp(
          home: LoginPage(
            portal: LoginPortal.usuario,
            appleSignInEnabled: false,
            loadGoogleToken: () async => 'google-id-token',
          ),
          authService: authService,
        ),
      );

      await tester.ensureVisible(find.text('Continuar com Google'));
      await tester.tap(find.text('Continuar com Google'));
      await tester.pumpAndSettle();

      expect(authService.lastGoogleIdToken, 'google-id-token');
      expect(authService.lastGooglePortal, 'usuario');
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('stays on the login page when Google sign-in is cancelled',
        (tester) async {
      final authService = RecordingAuthService();

      await tester.pumpWidget(
        buildLoginTestApp(
          home: LoginPage(
            portal: LoginPortal.usuario,
            appleSignInEnabled: false,
            loadGoogleToken: () async => null,
          ),
          authService: authService,
        ),
      );

      await tester.ensureVisible(find.text('Continuar com Google'));
      await tester.tap(find.text('Continuar com Google'));
      await tester.pumpAndSettle();

      expect(authService.lastGoogleIdToken, isNull);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('hides browser-based Facebook and X login by default',
        (tester) async {
      await tester.pumpWidget(
        buildLoginTestApp(
          home: const LoginPage(
            portal: LoginPortal.usuario,
            appleSignInEnabled: false,
          ),
          authService: RecordingAuthService(),
        ),
      );

      expect(find.text('Continuar com Google'), findsOneWidget);
      expect(find.text('Continuar com Facebook'), findsNothing);
      expect(find.text('Continuar com Twitter/X'), findsNothing);
    });

    testWidgets('oficina login does not offer social buttons', (tester) async {
      await tester.pumpWidget(
        buildLoginTestApp(
          home: const LoginPage(
            portal: LoginPortal.oficina,
            appleSignInEnabled: true,
          ),
          authService: RecordingAuthService(),
        ),
      );

      expect(find.text('Continuar com a Apple'), findsNothing);
      expect(find.text('Continuar com Google'), findsNothing);
    });
  });
}
