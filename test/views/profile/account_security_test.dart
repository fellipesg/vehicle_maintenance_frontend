import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/fcm_service.dart';
import 'package:vehicle_maintenance/views/auth/forgot_password_page.dart';
import 'package:vehicle_maintenance/views/profile/change_password_page.dart';
import 'package:vehicle_maintenance/views/profile/two_factor_page.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}

class _FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> removeToken() async {}

  @override
  Future<void> registerTokenAfterAuth() async {}
}

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'http://test');

  Object? error;

  String? resetEmail;
  String? sentCurrentPassword;
  String? sentNewPassword;
  String? confirmedCode;
  String? disablePassword;
  String? disableCode;

  bool enableCalled = false;
  bool regenerateCalled = false;
  bool twoFactorEnabled = false;

  Response<dynamic> _ok(Map<String, dynamic> body, String path) {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, ...body},
      statusCode: 200,
    );
  }

  @override
  Future<Response> requestPasswordReset(String email) async {
    resetEmail = email;

    if (error != null) {
      throw error!;
    }

    return _ok(
      {'message': 'Se este e-mail estiver cadastrado, você receberá um link.'},
      '/password/forgot',
    );
  }

  @override
  Future<Response> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    sentCurrentPassword = currentPassword;
    sentNewPassword = password;

    if (error != null) {
      throw error!;
    }

    return _ok({'message': 'Senha alterada.'}, '/me/password');
  }

  @override
  Future<Response> enableTwoFactor() async {
    enableCalled = true;

    if (error != null) {
      throw error!;
    }

    return _ok({
      'data': {
        'secret': 'JBSWY3DPEHPK3PXP',
        'otpauth_uri': 'otpauth://totp/RevisaLog:owner@test.com',
      },
    }, '/two-factor/enable');
  }

  @override
  Future<Response> confirmTwoFactor(String code) async {
    confirmedCode = code;

    if (error != null) {
      throw error!;
    }

    twoFactorEnabled = true;

    return _ok({
      'data': {
        'recovery_codes': ['aaa-111', 'bbb-222'],
      },
    }, '/two-factor/confirm');
  }

  @override
  Future<Response> disableTwoFactor({
    required String password,
    required String code,
  }) async {
    disablePassword = password;
    disableCode = code;

    if (error != null) {
      throw error!;
    }

    twoFactorEnabled = false;

    return _ok(const {}, '/two-factor/disable');
  }

  @override
  Future<Response> regenerateTwoFactorRecoveryCodes({
    required String password,
    required String code,
  }) async {
    regenerateCalled = true;

    if (error != null) {
      throw error!;
    }

    return _ok({
      'data': {
        'recovery_codes': ['ccc-333'],
      },
    }, '/two-factor/recovery-codes');
  }

}

/// O AuthService real faz GET /me pelo Dio; aqui o estado do usuário é direto.
class _FakeAuthService extends AuthService {
  _FakeAuthService(this._api)
      : super(
          _api,
          tokenStorage: _FakeTokenStorage(),
          fcmService: _FakeFcmService(),
        );

  final _FakeApiService _api;

  Map<String, dynamic> userData = {
    'email': 'owner@test.com',
    'has_two_factor_enabled': false,
  };

  int refreshCount = 0;

  @override
  Map<String, dynamic>? get user => userData;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    refreshCount++;
    userData = {
      ...userData,
      'has_two_factor_enabled': _api.twoFactorEnabled,
    };

    return userData;
  }
}

DioException _dioError(int statusCode, Map<String, dynamic>? body) {
  final options = RequestOptions(path: '/me/password');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

Widget _wrap(Widget child, _FakeApiService api, _FakeAuthService auth) {
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      Provider<AuthService>.value(value: auth),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ForgotPasswordPage', () {
    testWidgets('requires an e-mail', (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ForgotPasswordPage(), api, auth));

      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pump();

      expect(find.text('Informe o e-mail da sua conta'), findsOneWidget);
      expect(api.resetEmail, isNull);
    });

    testWidgets('shows the neutral message the backend returns',
        (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ForgotPasswordPage(), api, auth));

      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'owner@test.com',
      );
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(api.resetEmail, 'owner@test.com');
      expect(find.byKey(const Key('forgot_sent_card')), findsOneWidget);
      // A tela não pode dizer se a conta existe.
      expect(
        find.textContaining('Se este e-mail estiver cadastrado'),
        findsOneWidget,
      );
    });
  });

  group('ChangePasswordPage', () {
    testWidgets('validates length, confirmation and reuse', (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ChangePasswordPage(), api, auth));

      await tester.enterText(
        find.byKey(const Key('current_password_field')),
        'senha-atual',
      );
      await tester.enterText(
        find.byKey(const Key('new_password_field')),
        'curta',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'outra',
      );
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pump();

      expect(
        find.text('A senha nova deve ter no mínimo 8 caracteres'),
        findsOneWidget,
      );
      expect(
        find.text('A confirmação da senha nova não confere'),
        findsOneWidget,
      );
      expect(api.sentNewPassword, isNull);
    });

    testWidgets('refuses a new password equal to the current one',
        (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ChangePasswordPage(), api, auth));

      await tester.enterText(
        find.byKey(const Key('current_password_field')),
        'senha-atual-123',
      );
      await tester.enterText(
        find.byKey(const Key('new_password_field')),
        'senha-atual-123',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'senha-atual-123',
      );
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pump();

      expect(
        find.text('A senha nova precisa ser diferente da atual'),
        findsOneWidget,
      );
      expect(api.sentNewPassword, isNull);
    });

    testWidgets('sends the current and the new password', (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ChangePasswordPage(), api, auth));

      await tester.enterText(
        find.byKey(const Key('current_password_field')),
        'senha-atual-123',
      );
      await tester.enterText(
        find.byKey(const Key('new_password_field')),
        'senha-nova-456',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'senha-nova-456',
      );
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pump();

      expect(api.sentCurrentPassword, 'senha-atual-123');
      expect(api.sentNewPassword, 'senha-nova-456');
    });

    testWidgets('surfaces the field error for a wrong current password',
        (tester) async {
      final api = _FakeApiService()
        ..error = _dioError(422, {
          'message': 'The given data was invalid.',
          'errors': {
            'current_password': ['A senha atual não confere.'],
          },
        });
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ChangePasswordPage(), api, auth));

      await tester.enterText(
        find.byKey(const Key('current_password_field')),
        'chute',
      );
      await tester.enterText(
        find.byKey(const Key('new_password_field')),
        'senha-nova-456',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'senha-nova-456',
      );
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();

      expect(find.text('A senha atual não confere.'), findsOneWidget);
    });

    testWidgets('offers the e-mail link for accounts without a known password',
        (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const ChangePasswordPage(), api, auth));

      await tester.ensureVisible(
        find.byKey(const Key('change_password_forgot_link')),
      );
      await tester.tap(find.byKey(const Key('change_password_forgot_link')));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      // O e-mail da conta já vem preenchido.
      expect(find.text('owner@test.com'), findsOneWidget);
    });
  });

  group('TwoFactorPage', () {
    testWidgets('enable shows the secret and then the recovery codes',
        (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const TwoFactorPage(), api, auth));

      expect(find.text('Desativada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('two_factor_enable_button')));
      await tester.pumpAndSettle();

      expect(api.enableCalled, isTrue);
      expect(find.byKey(const Key('two_factor_enroll_card')), findsOneWidget);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('two_factor_confirm_code_field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('two_factor_confirm_button')));
      await tester.pumpAndSettle();

      expect(api.confirmedCode, '123456');
      expect(auth.refreshCount, 1);
      expect(find.byKey(const Key('two_factor_recovery_card')), findsOneWidget);
      expect(find.textContaining('aaa-111'), findsOneWidget);
      expect(find.text('Ativa'), findsOneWidget);
    });

    testWidgets('confirm without a code does not call the API', (tester) async {
      final api = _FakeApiService();
      final auth = _FakeAuthService(api);

      await tester.pumpWidget(_wrap(const TwoFactorPage(), api, auth));

      await tester.tap(find.byKey(const Key('two_factor_enable_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('two_factor_confirm_button')));
      await tester.pumpAndSettle();

      expect(api.confirmedCode, isNull);
      expect(
        find.text('Informe o código do aplicativo autenticador.'),
        findsOneWidget,
      );
    });

    testWidgets('disable asks for password and code', (tester) async {
      final api = _FakeApiService()..twoFactorEnabled = true;
      final auth = _FakeAuthService(api)
        ..userData = {
          'email': 'owner@test.com',
          'has_two_factor_enabled': true,
        };

      await tester.pumpWidget(_wrap(const TwoFactorPage(), api, auth));

      expect(find.text('Ativa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('two_factor_disable_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('two_factor_password_field')),
        'minha-senha',
      );
      await tester.enterText(
        find.byKey(const Key('two_factor_code_field')),
        '654321',
      );
      await tester.tap(find.text('Desativar').last);
      await tester.pumpAndSettle();

      expect(api.disablePassword, 'minha-senha');
      expect(api.disableCode, '654321');
      expect(find.text('Desativada'), findsOneWidget);
    });

    testWidgets('cancelling the dialog does not call the API', (tester) async {
      final api = _FakeApiService()..twoFactorEnabled = true;
      final auth = _FakeAuthService(api)
        ..userData = {
          'email': 'owner@test.com',
          'has_two_factor_enabled': true,
        };

      await tester.pumpWidget(_wrap(const TwoFactorPage(), api, auth));

      await tester.tap(find.byKey(const Key('two_factor_disable_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.disablePassword, isNull);
    });
  });
}
