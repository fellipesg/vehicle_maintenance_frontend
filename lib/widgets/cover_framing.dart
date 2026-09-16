class CoverFramingLandscape {
  static const double ratioX = 16;
  static const double ratioY = 9;
  static const double aspectRatio = ratioX / ratioY;
  static const String title = 'Enquadrar capa — deitada';
  static const String confirmLabel = 'Usar esta foto';
  static const String cancelLabel = 'Cancelar';
  static const String pickLabel = 'Capa paisagem (deitada)';
  static const String hint = 'Enquadre o carro na moldura paisagem 16:9';
  static const int maxWidth = 1600;
  static const int compressQuality = 85;
}

class CoverFramingPortrait {
  static const double ratioX = 9;
  static const double ratioY = 16;
  static const double aspectRatio = ratioX / ratioY;
  static const String title = 'Enquadrar capa — em pé';
  static const String confirmLabel = 'Usar esta foto';
  static const String cancelLabel = 'Cancelar';
  static const String pickLabel = 'Capa retrato (em pé)';
  static const String hint = 'Enquadre o carro na moldura retrato 9:16';
  static const int maxWidth = 1200;
  static const int compressQuality = 85;
}

/// Backward-compatible alias for landscape framing.
typedef CoverFraming = CoverFramingLandscape;
