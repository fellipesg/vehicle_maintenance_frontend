import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/utils/pdf_download_file_name.dart';

void main() {
  test('keeps an ascii pdf name from the API', () {
    expect(
      pdfDownloadFileName(
        fromApi: 'historico_manutencoes_QOS6H54_Mercedes-Benz_2026-09-14.pdf',
        fallback: 'historico_manutencoes.pdf',
      ),
      'historico_manutencoes_QOS6H54_Mercedes-Benz_2026-09-14.pdf',
    );
  });

  test('appends .pdf when the API omits the extension', () {
    expect(
      pdfDownloadFileName(
        fromApi: 'historico_QOS6H54_garantias',
        fallback: 'historico_manutencoes.pdf',
      ),
      'historico_QOS6H54_garantias.pdf',
    );
  });

  test('strips path separators and uses fallback when empty', () {
    expect(
      pdfDownloadFileName(fromApi: 'a/b\\c', fallback: 'historico.pdf'),
      'a_b_c.pdf',
    );
    expect(
      pdfDownloadFileName(fromApi: '   ', fallback: 'historico.pdf'),
      'historico.pdf',
    );
  });
}
