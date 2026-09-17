import 'package:flutter/material.dart';

import '../../theme/provenance.dart';

class ProvenanceMarker extends StatelessWidget {
  const ProvenanceMarker({
    super.key,
    required this.isVerified,
    this.workshopLogoUrl,
    this.workshopName,
    this.authorName,
    this.size = ProvenanceMarkerSize.md,
  });

  final bool isVerified;
  final String? workshopLogoUrl;
  final String? workshopName;
  final String? authorName;
  final ProvenanceMarkerSize size;

  double get _dimension {
    switch (size) {
      case ProvenanceMarkerSize.sm:
        return ProvenanceTheme.markerSizeSm;
      case ProvenanceMarkerSize.lg:
        return ProvenanceTheme.markerSizeLg;
      case ProvenanceMarkerSize.md:
        return ProvenanceTheme.markerSize;
    }
  }

  String get _initials {
    final source = (isVerified ? workshopName : authorName) ?? '?';
    final parts = source.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();
  }

  Widget _initialsText(Color color) {
    return Text(
      _initials,
      style: TextStyle(
        color: color,
        fontSize: _dimension * 0.32,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _verifiedMarker() {
    final hasLogo =
        workshopLogoUrl != null && workshopLogoUrl!.trim().isNotEmpty;
    final innerSize = _dimension - 4;

    return Container(
      key: const Key('provenance_marker_verified'),
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ProvenanceTheme.verifiedInk,
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: ProvenanceTheme.verifiedInk,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: hasLogo
            ? Image.network(
                workshopLogoUrl!,
                width: innerSize,
                height: innerSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: ProvenanceTheme.verifiedInk,
                  child: Center(child: _initialsText(Colors.white)),
                ),
              )
            : ColoredBox(
                color: ProvenanceTheme.verifiedInk,
                child: Center(child: _initialsText(Colors.white)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return _verifiedMarker();
    }

    return CustomPaint(
      key: const Key('provenance_marker_declared'),
      painter: _DeclaredRingPainter(dimension: _dimension),
      child: SizedBox(
        width: _dimension,
        height: _dimension,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: ProvenanceTheme.declaredSurface,
          ),
          child: Center(child: _initialsText(ProvenanceTheme.declaredInk)),
        ),
      ),
    );
  }
}

class _DeclaredRingPainter extends CustomPainter {
  _DeclaredRingPainter({required this.dimension});

  final double dimension;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ProvenanceTheme.declaredInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashCount = 16;
    const twoPi = 3.141592653589793 * 2;
    final radius = dimension / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * twoPi;
      final sweep = (twoPi / dashCount) * 0.42;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DeclaredRingPainter oldDelegate) =>
      oldDelegate.dimension != dimension;
}

enum ProvenanceMarkerSize { sm, md, lg }
