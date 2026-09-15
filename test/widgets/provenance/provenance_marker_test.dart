import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
