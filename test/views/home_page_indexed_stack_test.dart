import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/repositories/vehicle_repository.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching tabs does not recreate VehiclesPage', (tester) async {
    VehiclesPage.initStateCallCount = 0;

    final apiService = ApiService(baseUrl: 'http://localhost/api/v1');
    final authService = AuthService(apiService);
    final repository = VehicleRepository(apiService);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            Provider<AuthService>.value(value: authService),
            ChangeNotifierProvider<VehicleRepository>.value(value: repository),
          ],
          child: const HomePage(),
        ),
      ),
    );

    await tester.pump();
    expect(VehiclesPage.initStateCallCount, 1);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Veículos'));
    await tester.pumpAndSettle();

    expect(VehiclesPage.initStateCallCount, 1);
  });
}
