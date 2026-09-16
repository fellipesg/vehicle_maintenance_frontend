import 'package:flutter/material.dart';

import '../../theme/provenance.dart';

class ProvenanceRail extends StatelessWidget {
  const ProvenanceRail({
    super.key,
    required this.isVerified,
    this.height = 48,
  });

  final bool isVerified;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(ProvenanceTheme.railWidth, height),
      painter: _ProvenanceRailPainter(isVerified: isVerified),
    );
  }
}

class _ProvenanceRailPainter extends CustomPainter {
  _ProvenanceRailPainter({required this.isVerified});

  final bool isVerified;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          isVerified ? ProvenanceTheme.verifiedInk : ProvenanceTheme.declaredInk
      ..strokeWidth = ProvenanceTheme.railWidth;

    if (isVerified) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint..style = PaintingStyle.stroke,
      );
      return;
    }

    paint.style = PaintingStyle.stroke;
    var y = 0.0;
    while (y < size.height) {
      final end = (y + ProvenanceTheme.dashLength).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, end),
        paint,
      );
      y += ProvenanceTheme.dashLength + ProvenanceTheme.dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _ProvenanceRailPainter oldDelegate) =>
      oldDelegate.isVerified != isVerified;
}
