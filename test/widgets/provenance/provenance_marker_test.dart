import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/theme/provenance.dart';
import 'package:vehicle_maintenance/widgets/provenance/provenance_marker.dart';

void main() {
  testWidgets('verified marker uses verified key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProvenanceMarker(
            isVerified: true,
            workshopName: 'Oficina',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('provenance_marker_verified')), findsOneWidget);
  });

  testWidgets('declared marker uses declared key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProvenanceMarker(
            isVerified: false,
            authorName: 'João',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('provenance_marker_declared')), findsOneWidget);
  });

  testWidgets('declared owner marker shows PR with amber styling',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProvenanceMarker(
            isVerified: false,
            registeredByType: 'owner',
          ),
        ),
      ),
    );

    expect(find.text('PR'), findsOneWidget);
    expect(find.text('?'), findsNothing);

    final text = tester.widget<Text>(find.text('PR'));
    expect(text.style?.color, ProvenanceTheme.declaredInk);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.fontSize, 11);

    final surface = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('provenance_marker_declared')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, ProvenanceTheme.declaredSurface);
  });
}
