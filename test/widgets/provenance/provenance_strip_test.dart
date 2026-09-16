import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/provenance_segment.dart';
import 'package:vehicle_maintenance/widgets/provenance/provenance_strip.dart';

void main() {
  testWidgets('renders one segment per maintenance', (tester) async {
    final segments = [
      ProvenanceSegment(
          maintenanceId: 1, date: DateTime(2024, 1, 1), isVerified: true),
      ProvenanceSegment(
          maintenanceId: 2, date: DateTime(2024, 2, 1), isVerified: true),
      ProvenanceSegment(
          maintenanceId: 3, date: DateTime(2024, 3, 1), isVerified: true),
      ProvenanceSegment(
          maintenanceId: 4, date: DateTime(2024, 4, 1), isVerified: false),
      ProvenanceSegment(
          maintenanceId: 5, date: DateTime(2024, 5, 1), isVerified: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceStrip(
            segments: segments,
            totalMaintenances: 5,
            verifiedCount: 3,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('provenance_strip_segment_0')), findsOneWidget);
    expect(find.byKey(const Key('provenance_strip_segment_4')), findsOneWidget);
    expect(find.textContaining('5 manutenções'), findsOneWidget);
  });

  testWidgets('tap on second segment calls callback with id', (tester) async {
    int? tappedId;
    final segments = [
      ProvenanceSegment(
          maintenanceId: 10, date: DateTime(2024, 1, 1), isVerified: true),
      ProvenanceSegment(
          maintenanceId: 20, date: DateTime(2024, 2, 1), isVerified: true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceStrip(
            segments: segments,
            totalMaintenances: 2,
            verifiedCount: 2,
            onTapSegment: (id) => tappedId = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provenance_strip_segment_1')));
    await tester.pump();

    expect(tappedId, 20);
  });

  testWidgets('filter chips invoke onFilterChanged', (tester) async {
    bool? lastFilter;
    const segments = <ProvenanceSegment>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceStrip(
            segments: segments,
            totalMaintenances: 0,
            verifiedCount: 0,
            onFilterChanged: (value) => lastFilter = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provenance_filter_verified')));
    await tester.pump();
    expect(lastFilter, true);

    await tester.tap(find.byKey(const Key('provenance_filter_declared')));
    await tester.pump();
    expect(lastFilter, false);
  });
}
