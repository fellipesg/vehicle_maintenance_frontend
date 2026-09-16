import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/invoice.dart';
import 'package:vehicle_maintenance/models/maintenance.dart';
import 'package:vehicle_maintenance/theme/provenance.dart';
import 'package:vehicle_maintenance/widgets/provenance/provenance_card.dart';

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(),
);

void main() {
  testWidgets('shows NF anexada count when invoices exist', (tester) async {
    final maintenance = Maintenance(
      vehicleId: 1,
      maintenanceType: 'Troca de óleo',
      maintenanceDate: DateTime(2025, 3, 1),
      isVerified: true,
      provenanceLabel: 'Selo da oficina',
      provenanceSublabel: 'verificada',
      invoices: [
        Invoice(
          id: 1,
          maintenanceId: 1,
          invoiceType: 'general',
          filePath: 'invoices/a.pdf',
          fileName: 'a.pdf',
        ),
        Invoice(
          id: 2,
          maintenanceId: 1,
          invoiceType: 'general',
          filePath: 'invoices/b.pdf',
          fileName: 'b.pdf',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceCard(maintenance: maintenance),
        ),
      ),
    );

    expect(find.textContaining('NF anexada (2)'), findsOneWidget);
  });

  testWidgets('verified card uses dark text on white surface in dark app theme',
      (tester) async {
    final maintenance = Maintenance(
      vehicleId: 1,
      maintenanceType: 'Revisão',
      maintenanceDate: DateTime(2025, 3, 1),
      isVerified: true,
      provenanceLabel: 'Selo da oficina',
      provenanceSublabel: 'verificada',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: _darkTheme,
        home: Scaffold(
          body: ProvenanceCard(maintenance: maintenance),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Revisão'));
    expect(title.style?.color, ProvenanceTheme.verifiedTitle);
  });
}
