import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/invoice.dart';
import 'package:vehicle_maintenance/models/maintenance.dart';
import 'package:vehicle_maintenance/widgets/provenance/provenance_seal.dart';

void main() {
  testWidgets('verified seal copy code shows snackbar', (tester) async {
    final maintenance = Maintenance(
      vehicleId: 1,
      maintenanceType: 'Revisão',
      maintenanceDate: DateTime(2025, 1, 1),
      isVerified: true,
      verificationCode: 'RVL-TEST-01',
      verifiedAt: DateTime(2025, 1, 2),
      verifiedWorkshop: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceSeal(maintenance: maintenance),
        ),
      ),
    );

    await tester.tap(find.text('Copiar código'));
    await tester.pump();

    expect(find.text('Código copiado'), findsOneWidget);
  });

  testWidgets('declared seal lists invoice evidence', (tester) async {
    final maintenance = Maintenance(
      vehicleId: 1,
      maintenanceType: 'Pastilhas',
      maintenanceDate: DateTime(2025, 6, 1),
      isVerified: false,
      registeredByType: 'owner',
      ownerName: 'João',
      invoices: [
        Invoice(
          id: 1,
          maintenanceId: 1,
          invoiceType: 'general',
          filePath: 'invoices/1.xml',
          fileName: 'nfe.xml',
        ),
        Invoice(
          id: 2,
          maintenanceId: 1,
          invoiceType: 'general',
          filePath: 'invoices/2.xml',
          fileName: 'nfe2.xml',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvenanceSeal(maintenance: maintenance),
        ),
      ),
    );

    expect(find.textContaining('NF-e 2'), findsOneWidget);
    expect(
      find.textContaining('não passou por uma oficina cadastrada'),
      findsOneWidget,
    );
  });
}
