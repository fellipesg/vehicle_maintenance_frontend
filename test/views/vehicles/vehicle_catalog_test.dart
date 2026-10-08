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

  testWidgets('a brand outside the catalog keeps the field usable',
      (tester) async {
    final api = _CatalogApiService();

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    await tester.enterText(_brandField(), 'Troller');
    await tester.enterText(_modelField(), 'T4');
    await tester.pumpAndSettle();

    // Sugerir não é obrigar: o catálogo não cobre todo importado ou lançamento.
    expect(find.text('Troller'), findsOneWidget);
    expect(find.text('T4'), findsOneWidget);
  });

  testWidgets('a failing catalog does not break the form', (tester) async {
    final api = _CatalogApiService(brandsError: Exception('offline'));

    await tester.pumpWidget(_wrap(const VehicleFormPage(), api));
    await tester.pumpAndSettle();

    await tester.enterText(_brandField(), 'Fiat');
    await tester.pumpAndSettle();

    expect(find.text('Fiat'), findsOneWidget);
    expect(_brandField(), findsOneWidget);
  });

  testWidgets('editing a vehicle preloads the models of its brand',
      (tester) async {
    final api = _CatalogApiService();
    final vehicle = Vehicle(
      id: 7,
      licensePlate: 'ABC1D23',
      renavam: '12345678901',
      brand: 'Volkswagen',
      model: 'Gol',
      year: 2020,
      chassis: '9BWZZZ377VT004251',
      currentKilometers: 10000,
    );

    await tester.pumpWidget(_wrap(VehicleFormPage(vehicle: vehicle), api));
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
