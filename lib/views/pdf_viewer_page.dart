import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';

class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({
    super.key,
    required this.title,
    required this.bytes,
    this.fileName = 'historico_manutencoes.pdf',
    this.filePath,
  });

  final String title;
  final Uint8List bytes;
  final String fileName;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (filePath != null && filePath!.isNotEmpty)
            IconButton(
              tooltip: 'Abrir no leitor do sistema',
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  OpenFilex.open(filePath!, type: 'application/pdf'),
            ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: fileName,
        dynamicLayout: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        loadingWidget: const SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Carregando PDF…'),
              ],
            ),
          ),
        ),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Não foi possível exibir o PDF neste leitor.',
                  textAlign: TextAlign.center,
                ),
                if (filePath != null && filePath!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        OpenFilex.open(filePath!, type: 'application/pdf'),
                    child: const Text('Abrir no leitor do sistema'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
