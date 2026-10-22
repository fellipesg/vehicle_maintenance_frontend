import 'package:flutter/painting.dart';

/// Sobre o que é a foto: o veículo inteiro ou uma peça (item) da manutenção.
enum PhotoSubject {
  vehicle('vehicle', 'Veículo'),
  part('part', 'Peça');

  const PhotoSubject(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PhotoSubject fromApi(Object? value) =>
      value == 'part' ? PhotoSubject.part : PhotoSubject.vehicle;
}

/// Momento do serviço em que a foto foi tirada.
enum PhotoStage {
  before('before', 'Antes'),
  during('during', 'Durante'),
  after('after', 'Depois');

  const PhotoStage(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PhotoStage fromApi(Object? value) {
    return PhotoStage.values.firstWhere(
      (stage) => stage.apiValue == value,
      orElse: () => PhotoStage.after,
    );
  }
}

/// Tamanhos entregues pelo backend em `variants`.
enum PhotoVariant {
  thumb,
  display,
  master;

  String get apiKey => name;
}

/// Foto de manutenção (`MaintenancePhotoResource`).
///
/// As URLs de `variants` são pré-assinadas e valem ~10 min; o arquivo de um id
/// nunca muda. Por isso o cache de imagem usa [cacheKey] (id + variante) e
/// nunca a URL, cuja assinatura troca a cada resposta.
class MaintenancePhoto {
  const MaintenancePhoto({
    required this.id,
    required this.maintenanceId,
    this.maintenanceItemId,
    this.subject = PhotoSubject.vehicle,
    this.stage = PhotoStage.after,
    this.originalName = '',
    this.sort = 0,
    this.createdBy,
    this.createdAt,
    this.width,
    this.height,
    this.dominantColor,
    this.processed = true,
    this.variants = const {},
    this.expiresAt,
    this.legacyUrl,
  });

  final int id;
  final int maintenanceId;
  final int? maintenanceItemId;
  final PhotoSubject subject;
  final PhotoStage stage;
  final String originalName;
  final int sort;
  final int? createdBy;
  final DateTime? createdAt;
  final int? width;
  final int? height;

  /// `#rrggbb` calculado no backend; serve de placeholder enquanto carrega.
  final Color? dominantColor;
  final bool processed;
  final Map<PhotoVariant, String> variants;
  final DateTime? expiresAt;

  /// Rota autorizada antiga (`/api/v1/maintenance-photos/{id}`), que exige
  /// Bearer. Não serve para exibir a imagem.
  final String? legacyUrl;

  factory MaintenancePhoto.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'];
    final variants = <PhotoVariant, String>{};

    if (rawVariants is Map) {
      for (final variant in PhotoVariant.values) {
        final value = rawVariants[variant.apiKey];
        if (value is String && value.isNotEmpty) {
          variants[variant] = value;
        }
      }
    }

    return MaintenancePhoto(
      id: _asInt(json['id']) ?? 0,
      maintenanceId: _asInt(json['maintenance_id']) ?? 0,
      maintenanceItemId: _asInt(json['maintenance_item_id']),
      subject: PhotoSubject.fromApi(json['subject']),
      stage: PhotoStage.fromApi(json['stage']),
      originalName: json['original_name']?.toString() ?? '',
      sort: _asInt(json['sort']) ?? 0,
      createdBy: _asInt(json['created_by']),
      createdAt: _asDate(json['created_at']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      dominantColor: _parseColor(json['dominant_color']),
      processed: json['processed'] != false,
      variants: variants,
      expiresAt: _asDate(json['expires_at']),
      legacyUrl: json['url']?.toString(),
    );
  }

  /// Largura / altura, quando o backend já mediu a imagem.
  double? get aspectRatio {
    final w = width;
    final h = height;

    if (w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }

    return w / h;
  }

  /// URL pré-assinada da variante; cai para a próxima menor disponível.
  String? urlFor(PhotoVariant variant) {
    final direct = variants[variant];
    if (direct != null) {
      return direct;
    }

    final order = switch (variant) {
      PhotoVariant.thumb => const [PhotoVariant.display, PhotoVariant.master],
      PhotoVariant.display => const [PhotoVariant.master, PhotoVariant.thumb],
      PhotoVariant.master => const [PhotoVariant.display, PhotoVariant.thumb],
    };

    for (final candidate in order) {
      final url = variants[candidate];
      if (url != null) {
        return url;
      }
    }

    return null;
  }

  String? get thumbUrl => urlFor(PhotoVariant.thumb);
  String? get displayUrl => urlFor(PhotoVariant.display);
  String? get masterUrl => urlFor(PhotoVariant.master);

  /// Chave de cache estável: o arquivo de um id é imutável, a URL não.
  String cacheKey(PhotoVariant variant) => 'photo:$id:${variant.apiKey}';

  /// O limite de 4 fotos do backend vale por assunto + momento (o item não
  /// entra na conta).
  bool sameGroupAs(PhotoSubject otherSubject, PhotoStage otherStage) =>
      subject == otherSubject && stage == otherStage;

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    return value == null ? null : int.tryParse(value.toString());
  }

  static DateTime? _asDate(Object? value) {
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  static Color? _parseColor(Object? value) {
    if (value is! String) {
      return null;
    }

    final hex = value.replaceFirst('#', '');
    if (hex.length != 6) {
      return null;
    }

    final parsed = int.tryParse(hex, radix: 16);

    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}
