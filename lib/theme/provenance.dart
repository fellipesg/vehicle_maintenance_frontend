import 'package:flutter/material.dart';

/// Tokens alinhados a backend/.ai/rules/theme.md e resources/css/provenance.css
abstract final class ProvenanceTheme {
  static const Color verifiedInk = Color(0xFF0F766E);
  static const Color declaredInk = Color(0xFF92400E);
  static const Color declaredSurface = Color(0xFFFFFBEB);
  static const Color verifiedSurface = Colors.white;

  static const double markerSize = 28;
  static const double markerSizeSm = 20;
  static const double railWidth = 3;
  static const double stripHeight = 8;
  static const double dashLength = 6;
  static const double dashGap = 4;

  static const String sealLabel = 'Selo da oficina';
  static const String declaredOwnerLabel = 'Declarada pelo proprietário';
  static const String declaredGarageLabel = 'Declarada pelo lojista';
  static const String verifiedMeta = 'verificada';
  static const String unverifiedMeta = 'não verificada';
}
