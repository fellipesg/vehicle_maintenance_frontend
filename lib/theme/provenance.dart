import 'package:flutter/material.dart';

/// Tokens alinhados a backend/.ai/rules/theme.md e resources/css/provenance.css
abstract final class ProvenanceTheme {
  static const Color verifiedInk = Color(0xFF0F766E);
  static const Color declaredInk = Color(0xFF92400E);
  static const Color declaredSurface = Color(0xFFFFFBEB);
  static const Color verifiedSurface = Colors.white;

  /// Legível em [verifiedSurface] com o app em tema escuro global.
  static const Color verifiedTitle = Color(0xFF0B1C2C);
  static const Color verifiedBody = Color(0xFF1E293B);
  static const Color verifiedMetaColor = Color(0xFF64748B);

  static const Color declaredTitle = Color(0xFF1F2937);
  static const Color declaredBody = Color(0xFF374151);
  static const Color declaredMeta = Color(0xFF6B7280);

  static const double markerSize = 36;
  static const double markerSizeSm = 24;
  static const double markerSizeLg = 44;
  static const double dotSize = 10;
  static const double dotGap = 4;
  static const double railWidth = 3;
  static const double dashLength = 6;
  static const double dashGap = 4;

  static const String sealLabel = 'Selo da oficina';
  static const String declaredOwnerLabel = 'Declarada pelo proprietário';
  static const String declaredGarageLabel = 'Declarada pelo lojista';
  static const String verifiedMeta = 'verificada';
  static const String unverifiedMeta = 'não verificada';
}
