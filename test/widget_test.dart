import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/views/auth/login_hub_page.dart';

void main() {
  testWidgets('login hub smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginHubPage(),
      ),
    );

    expect(find.text('Vehicle Maintenance'), findsOneWidget);
  });
}
