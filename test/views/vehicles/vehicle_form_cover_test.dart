import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/views/vehicles/vehicle_form_page.dart';
import 'package:vehicle_maintenance/widgets/cover_framing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('landscape cover framing is 16:9', () {
    expect(CoverFramingLandscape.aspectRatio, closeTo(16 / 9, 0.001));
    expect(CoverFramingLandscape.title, 'Enquadrar capa — deitada');
  });

  test('portrait cover framing is 9:16', () {
    expect(CoverFramingPortrait.aspectRatio, closeTo(9 / 16, 0.001));
    expect(CoverFramingPortrait.title, 'Enquadrar capa — em pé');
  });

  testWidgets('vehicle form asks for landscape and portrait covers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VehicleFormPage()));

    expect(find.text(CoverFramingLandscape.pickLabel), findsOneWidget);
    expect(find.text(CoverFramingPortrait.pickLabel), findsOneWidget);
    expect(find.text(CoverFramingLandscape.hint), findsOneWidget);
    expect(find.text(CoverFramingPortrait.hint), findsOneWidget);
    expect(find.text('Capa paisagem (celular deitado)'), findsOneWidget);
    expect(find.text('Capa retrato (celular em pé)'), findsOneWidget);
  });
}
