import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/maintenance.dart';
import '../../theme/provenance.dart';
import 'provenance_marker.dart';

class ProvenanceSeal extends StatelessWidget {
  const ProvenanceSeal({super.key, required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    if (maintenance.isVerified) {
      return _VerifiedSeal(maintenance: maintenance);
    }
    return _DeclaredSeal(maintenance: maintenance);
  }
}

class _VerifiedSeal extends StatelessWidget {
  const _VerifiedSeal({required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    final verifiedAt = maintenance.verifiedAt != null
        ? DateFormat('dd/MM/yyyy').format(maintenance.verifiedAt!)
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ProvenanceTheme.verifiedInk, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: ProvenanceTheme.verifiedInk),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProvenanceMarker(
              isVerified: true,
              workshopLogoUrl: maintenance.verifiedWorkshop?.logoUrl,
              workshopName: maintenance.verifiedWorkshop?.name,
            ),
            const SizedBox(height: 8),
            Text(
              maintenance.verifiedWorkshop?.name ??
                  maintenance.workshopName ??
                  '',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Text('Registro verificado'),
            Text('${ProvenanceTheme.verifiedMeta} em $verifiedAt'),
            if (maintenance.verificationCode != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                maintenance.verificationCode!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: maintenance.verificationCode!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código'),
              ),
            ],
            if (maintenance.verificationQrMatrix != null) ...[
              const SizedBox(height: 8),
              CustomPaint(
                size: const Size(120, 120),
                painter: _QrPainter(matrix: maintenance.verificationQrMatrix!),
              ),
            ],
            if (maintenance.verificationUrl != null)
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(maintenance.verificationUrl!);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('Abrir verificação'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeclaredSeal extends StatelessWidget {
  const _DeclaredSeal({required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    final label = maintenance.registeredByType == 'garage'
        ? ProvenanceTheme.declaredGarageLabel
        : ProvenanceTheme.declaredOwnerLabel;
    final invoiceCount = maintenance.invoices?.length ?? 0;

    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: ProvenanceTheme.declaredSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProvenanceMarker(
                  isVerified: false,
                  authorName: maintenance.ownerName,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Este registro foi feito pelo dono do veículo e não passou por uma oficina cadastrada.',
            ),
            if (invoiceCount > 0) Text('NF-e $invoiceCount'),
            if (maintenance.workshopName != null &&
                maintenance.verifiedWorkshop == null)
              Text(
                'Oficina informada: ${maintenance.workshopName} (não confirmada)',
              ),
          ],
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.matrix});

  final List<List<int>> matrix;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = matrix.length;
    if (moduleCount == 0) {
      return;
    }
    const quiet = 2;
    final total = moduleCount + quiet * 2;
    final moduleSize = size.width / total;
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < moduleCount; y++) {
      for (var x = 0; x < matrix[y].length; x++) {
        if (matrix[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              (x + quiet) * moduleSize,
              (y + quiet) * moduleSize,
              moduleSize,
              moduleSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.matrix != matrix;
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ProvenanceTheme.declaredInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = ProvenanceTheme.dashLength;
    const gap = ProvenanceTheme.dashGap;
    _drawDashedLine(
        canvas, const Offset(0, 0), Offset(size.width, 0), paint, dash, gap);
    _drawDashedLine(canvas, Offset(size.width, 0),
        Offset(size.width, size.height), paint, dash, gap);
    _drawDashedLine(canvas, Offset(size.width, size.height),
        Offset(0, size.height), paint, dash, gap);
    _drawDashedLine(
        canvas, Offset(0, size.height), const Offset(0, 0), paint, dash, gap);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      double dash, double gap) {
    final total = (end - start).distance;
    final direction = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final next = drawn + dash;
      canvas.drawLine(
        start + direction * drawn,
        start + direction * next.clamp(0, total),
        paint,
      );
      drawn = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
