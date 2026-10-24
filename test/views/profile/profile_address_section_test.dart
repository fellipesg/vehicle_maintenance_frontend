import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';
import 'package:vehicle_maintenance/services/cep_service.dart';
import 'package:vehicle_maintenance/views/profile/profile_edit_page.dart';

class FakeAuthTokenStorage implements AuthTokenStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<void> writeToken(String value) async {}
}

class SilentCepService extends CepService {
  @override
  Future<CepAddress?> lookup(String value) async => null;
}

/// Guarda o corpo do PUT /me para o teste conferir o que o app mandou.
class RecordingApi {
  RecordingApi() {
    service = ApiService(baseUrl: 'http://test');
    service.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/me' && options.method == 'PUT') {
            lastBody = Map<String, dynamic>.from(options.data as Map);

            handler.resolve(
              Response(
                requestOptions: options,
                data: {'success': true, 'data': _user},
              ),
            );

            return;
          }

          handler.next(options);
        },
      ),
    );
  }

  late final ApiService service;
  Map<String, dynamic>? lastBody;
  Map<String, dynamic> _user = const {};

  void answerWith(Map<String, dynamic> user) => _user = user;
}

const _garage = {
  'name': 'Dev Lojista',
  'email': 'loja@vehicle-maintenance.test',
  'user_type': 'garage',
  'postal_code': '79010200',
  'street': 'Rua Treze de Junho',
  'number': '3000',
  'city': 'Campo Grande',
  'state': 'MS',
  'country': 'Brasil',
};

const _workshop = {
  'name': 'Dev Oficina',
  'email': 'oficina@vehicle-maintenance.test',
  'user_type': 'workshop',
};

/// As chaves que saem do corpo do PUT quando a conta é de empresa.
const _addressKeys = [
  'postal_code',
  'street',
  'number',
  'complement',
  'city',
  'state',
  'country',
];

const _owner = {
  'name': 'Maria Silva',
  'email': 'maria@vehicle-maintenance.test',
  'user_type': 'user',
  'postal_code': '79010200',
  'city': 'Campo Grande',
  'state': 'MS',
};

AuthService authFor(Map<String, dynamic> user, RecordingApi api) {
  api.answerWith(user);

  final authService = AuthService(
    api.service,
    tokenStorage: FakeAuthTokenStorage(),
  );

  authService.saveToken('test-token');
  authService.saveUser(user);

  return authService;
}

Widget buildApp(AuthService authService) {
  return Provider<AuthService>.value(
    value: authService,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileEditPage(cepService: SilentCepService()),
              ),
            ),
            child: const Text('Abrir Meus Dados'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openProfile(WidgetTester tester, AuthService authService) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(buildApp(authService));
  await tester.tap(find.text('Abrir Meus Dados'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Meus Dados: endereço só para o proprietário', () {
    testWidgets('proprietário continua com a seção Endereço', (tester) async {
      final api = RecordingApi();
      await openProfile(tester, authFor(_owner, api));

      expect(find.text('Endereço'), findsOneWidget);
      expect(find.byKey(const Key('profile_cep_field')), findsOneWidget);
    });

    testWidgets('loja não vê a seção Endereço', (tester) async {
      final api = RecordingApi();
      await openProfile(tester, authFor(_garage, api));

      expect(find.text('Endereço'), findsNothing);
      expect(find.byKey(const Key('profile_cep_field')), findsNothing);
      expect(find.text('Rua Treze de Junho'), findsNothing);
      expect(find.text('Nome *'), findsOneWidget);
      expect(find.text('Telefone'), findsOneWidget);
    });

    testWidgets('oficina não vê a seção Endereço', (tester) async {
      final api = RecordingApi();
      await openProfile(tester, authFor(_workshop, api));

      expect(find.text('Endereço'), findsNothing);
      expect(find.byKey(const Key('profile_cep_field')), findsNothing);
    });

    testWidgets('loja salva sem mandar endereço nenhum', (tester) async {
      final api = RecordingApi();
      await openProfile(tester, authFor(_garage, api));

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(api.lastBody, isNotNull);
      expect(api.lastBody!.keys, containsAll(['name', 'phone']));

      for (final key in _addressKeys) {
        expect(api.lastBody, isNot(contains(key)));
      }
    });

    testWidgets('proprietário continua mandando o endereço', (tester) async {
      final api = RecordingApi();
      await openProfile(tester, authFor(_owner, api));

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(api.lastBody, isNotNull);
      expect(api.lastBody!.keys, containsAll(_addressKeys));
      expect(api.lastBody!['postal_code'], '79010200');
      expect(api.lastBody!['city'], 'Campo Grande');
      expect(api.lastBody!['state'], 'MS');
    });
  });
}
