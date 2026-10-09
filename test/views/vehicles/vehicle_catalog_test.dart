import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';
import 'package:vehicle_maintenance/widgets/catalog_autocomplete.dart';

class _CatalogApiService extends ApiService {
  _CatalogApiService({this.brandsError}) : super(baseUrl: 'http://test');

  static const brands = ['Fiat', 'Ford', 'Volkswagen'];
  static const modelsByBrand = {
    'Fiat': ['Argo', 'Mobi', 'Uno'],
    'Volkswagen': ['Gol', 'Polo'],
  };

  final Object? brandsError;

  final List<String> modelRequests = [];

  @override
  Future<List<String>> getCatalogBrands() async {
    if (brandsError != null) {
      throw brandsError!;
    }

    return brands;
  }

  @override
  Future<List<String>> getCatalogModels(String brand) async {
    modelRequests.add(brand);

    return modelsByBrand[brand] ?? const [];
  }

  @override
  Future<Response<dynamic>> getTermsOfUse() async {
    return Response(
      requestOptions: RequestOptions(path: '/legal/terms-of-use'),
      data: {
        'success': true,
        'data': {'content': 'Termos de teste'},
      },
      statusCode: 200,
    );
  }
}

Widget _wrap(Widget child, ApiService apiService) {
  return Provider<ApiService>.value(
    value: apiService,
    child: MaterialApp(home: child),
  );
}

Finder _brandField() => find.descendant(
      of: find.byKey(const Key('vehicle_brand_field')),
      matching: find.byType(TextFormField),
    );

Finder _modelField() => find.descendant(
      of: find.byKey(const Key('vehicle_model_field')),
      matching: find.byType(TextFormField),
    );

Vehicle _vehicle() => Vehicle(
      id: 7,
      licensePlate: 'ABC1D23',
      renavam: '12345678901',
      brand: 'Volkswagen',
      model: 'Gol',
      year: 2020,
      chassis: '9BWZZZ377VT004251',
      currentKilometers: 10000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('brand suggestions come from the catalog', (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    await tester.tap(_brandField());
    await tester.enterText(_brandField(), 'fi');
    await tester.pumpAndSettle();

    expect(find.text('Fiat'), findsOneWidget);
    // Filtra: Ford não contém "fi".
    expect(find.text('Ford'), findsNothing);
  });

  testWidgets('selecting a brand loads its models with the canonical name',
      (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    await tester.tap(_brandField());
    // Caixa diferente de propósito: o endpoint de modelos resolve por chave
    // exata, então tem de ir o nome do catálogo, não o que foi digitado.
    await tester.enterText(_brandField(), 'fiat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiat').last);
    await tester.pumpAndSettle();

    expect(api.modelRequests, contains('Fiat'));

    await tester.tap(_modelField());
    await tester.enterText(_modelField(), 'ar');
    await tester.pumpAndSettle();

    expect(find.text('Argo'), findsOneWidget);
  });

  // Pelo fluxo de edição: no cadastro novo o botão só habilita depois do aceite
  // dos termos, e o tap não chegaria a validar nada.
  testWidgets('a brand outside the catalog is refused', (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: _vehicle()), api));
    await tester.pumpAndSettle();

    await tester.enterText(_brandField(), 'Troller');
    await tester.pumpAndSettle();

    // Lista fechada, como o <select> do portal web: o que não está no catálogo
    // entra pelo /admin/marcas, não digitando no formulário.
    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha uma marca da lista'), findsOneWidget);
  });

  testWidgets('the model field waits for a brand', (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    expect(find.text('Selecione a marca primeiro'), findsOneWidget);
    expect(tester.widget<TextFormField>(_modelField()).enabled, isFalse);

    await tester.enterText(_brandField(), 'Fiat');
    await tester.pumpAndSettle();

    expect(tester.widget<TextFormField>(_modelField()).enabled, isTrue);
  });

  testWidgets('changing the brand drops the model chosen for the previous one',
      (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    await tester.tap(_brandField());
    await tester.enterText(_brandField(), 'Fiat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiat').last);
    await tester.pumpAndSettle();

    await tester.tap(_modelField());
    await tester.enterText(_modelField(), 'Argo');
    await tester.pumpAndSettle();

    await tester.tap(_brandField());
    await tester.enterText(_brandField(), 'Volkswagen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volkswagen').last);
    await tester.pumpAndSettle();

    // Argo não é modelo de Volkswagen.
    expect(find.text('Argo'), findsNothing);
  });

  testWidgets('a failing catalog does not block the form', (tester) async {
    final api = _CatalogApiService(brandsError: Exception('offline'));

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: _vehicle()), api));
    await tester.pumpAndSettle();

    await tester.enterText(_brandField(), 'Troller');
    await tester.enterText(_modelField(), '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Atualizar'));
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    // Lista de marcas não carregou: não há contra o que validar, e travar a
    // edição por falha de rede seria pior que aceitar o texto.
    expect(find.text('Escolha uma marca da lista'), findsNothing);

    // Mas a validação rodou — o modelo, apagado, foi cobrado.
    expect(find.text('Por favor, selecione o modelo'), findsOneWidget);
  });

  testWidgets('editing a vehicle preloads the models of its brand',
      (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: _vehicle()), api));
    await tester.pumpAndSettle();

    expect(api.modelRequests, contains('Volkswagen'));

    await tester.tap(_modelField());
    await tester.enterText(_modelField(), 'po');
    await tester.pumpAndSettle();

    expect(find.text('Polo'), findsOneWidget);
  });

  group('CatalogAutocomplete', () {
    testWidgets('shows the head of the list when the field is empty',
        (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CatalogAutocomplete(
            controller: controller,
            focusNode: focusNode,
            options: const ['Fiat', 'Ford'],
            decoration: const InputDecoration(labelText: 'Marca'),
            requiredMessage: 'Informe a marca',
            invalidMessage: 'Escolha uma marca da lista',
          ),
        ),
      ));

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(find.text('Fiat'), findsOneWidget);
      expect(find.text('Ford'), findsOneWidget);
    });
  });
}
