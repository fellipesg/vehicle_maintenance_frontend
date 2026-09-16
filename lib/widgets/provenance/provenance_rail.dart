import 'package:flutter/material.dart';

import '../../theme/provenance.dart';

class ProvenanceRail extends StatelessWidget {
  const ProvenanceRail({
    super.key,
    required this.isVerified,
    this.height = 48,
    this.expand = false,
  });

  final bool isVerified;

  /// Fixed height when [expand] is false.
  final double height;

  /// Fill remaining vertical space (e.g. timeline connector between markers).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final painter = _ProvenanceRailPainter(isVerified: isVerified);

    if (expand) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final railHeight = constraints.maxHeight;
          if (!railHeight.isFinite || railHeight <= 0) {
            return const SizedBox.shrink();
          }

          return CustomPaint(
            size: Size(ProvenanceTheme.railWidth, railHeight),
            painter: painter,
          );
        },
      );
    }

    return CustomPaint(
      size: Size(ProvenanceTheme.railWidth, height),
      painter: painter,
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
