import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';
import 'package:vehicle_maintenance/widgets/cover_framing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cover framing is landscape 16:9', () {
    expect(CoverFraming.aspectRatio, closeTo(16 / 9, 0.001));
    expect(CoverFraming.title, 'Enquadrar capa');
  });

  testWidgets('vehicle form asks to frame the cover photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VehicleFormPage()));

    expect(find.text(CoverFraming.pickLabel), findsOneWidget);
    expect(find.text(CoverFraming.hint), findsOneWidget);
  });
}
