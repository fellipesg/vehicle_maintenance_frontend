import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/cep_service.dart';
import 'package:vehicle_maintenance/views/auth/register_page.dart';

class FakeCepService extends CepService {
  FakeCepService({this.address});

  final CepAddress? address;
  final List<String> queries = <String>[];

  @override
  Future<CepAddress?> lookup(String value) async {
    final cep = CepService.sanitize(value);

    if (cep.length != CepService.cepLength) {
      return null;
    }

    queries.add(cep);

    return address;
  }
}

const _londrina = CepAddress(
  street: 'Rua Piauí',
  neighborhood: 'Centro',
  city: 'Londrina',
  state: 'PR',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cadastro: endereço preenchido pelo CEP', () {
    testWidgets('preenche rua, cidade e UF ao completar o CEP', (tester) async {
      final cepService = FakeCepService(address: _londrina);

      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: cepService)),
      );

      await tester.enterText(
        find.byKey(const Key('register_cep_field')),
        '86010-000',
      );
      await tester.pumpAndSettle();

      expect(cepService.queries, ['86010000']);
      expect(find.text('Rua Piauí'), findsOneWidget);
      expect(find.text('Londrina'), findsOneWidget);
      expect(find.text('PR'), findsOneWidget);
    });

    testWidgets('não consulta enquanto o CEP está incompleto', (tester) async {
      final cepService = FakeCepService(address: _londrina);

      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: cepService)),
      );

      await tester.enterText(
        find.byKey(const Key('register_cep_field')),
        '8601',
      );
      await tester.pumpAndSettle();

      expect(cepService.queries, isEmpty);
      expect(find.text('Rua Piauí'), findsNothing);
    });

    testWidgets('não repete a consulta do mesmo CEP', (tester) async {
      final cepService = FakeCepService(address: _londrina);

      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: cepService)),
      );

      final field = find.byKey(const Key('register_cep_field'));

      await tester.enterText(field, '86010000');
      await tester.pumpAndSettle();
      await tester.enterText(field, '86010-000');
      await tester.pumpAndSettle();

      expect(cepService.queries, ['86010000']);
    });

    testWidgets('consulta de novo depois que o CEP muda', (tester) async {
      final cepService = FakeCepService(address: _londrina);

      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: cepService)),
      );

      final field = find.byKey(const Key('register_cep_field'));

      await tester.enterText(field, '86010000');
      await tester.pumpAndSettle();
      await tester.enterText(field, '80000000');
      await tester.pumpAndSettle();

      expect(cepService.queries, ['86010000', '80000000']);
    });

    testWidgets('CEP desconhecido não apaga o que já estava preenchido',
        (tester) async {
      final cepService = FakeCepService();

      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: cepService)),
      );

      await tester.enterText(
        find.byKey(const Key('register_cep_field')),
        '00000000',
      );
      await tester.pumpAndSettle();

      expect(cepService.queries, ['00000000']);
      expect(find.text('Rua Piauí'), findsNothing);
    });

    testWidgets('falha de rede não derruba o formulário', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(cepService: _FailingCepService())),
      );

      await tester.enterText(
        find.byKey(const Key('register_cep_field')),
        '86010000',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('register_cep_field')), findsOneWidget);
    });
  });
}

class _FailingCepService extends CepService {
  @override
  Future<CepAddress?> lookup(String value) async {
    throw Exception('sem rede');
  }
}
