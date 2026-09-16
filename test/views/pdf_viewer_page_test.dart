import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/views/pdf_viewer_page.dart';

void main() {
  testWidgets('pdf viewer shows the document title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerPage(
          title: 'Histórico de manutenções',
          fileName: 'historico.pdf',
          bytes: Uint8List.fromList('%PDF-1.4\n'.codeUnits),
        ),
      ),
    );

    expect(find.text('Histórico de manutenções'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
