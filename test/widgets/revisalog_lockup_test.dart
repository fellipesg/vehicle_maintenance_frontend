import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/widgets/revisalog_lockup.dart';

void main() {
  testWidgets('renders Revisa and Log wordmark with app icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RevisalogLockupHorizontal(),
        ),
      ),
    );

    expect(find.byType(RevisalogLockupHorizontal), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
