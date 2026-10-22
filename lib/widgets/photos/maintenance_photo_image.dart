import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/maintenance_photo.dart';

/// Busca de novo o JSON dono da foto (detalhe da manutenção ou timeline) e
/// devolve a mesma foto com URLs recém-assinadas, ou `null` se não achar.
typedef PhotoRefresher = Future<MaintenancePhoto?> Function(
  MaintenancePhoto photo,
);

/// Imagem de uma variante de [MaintenancePhoto].
///
/// - Não manda `Authorization`: as variantes são URLs pré-assinadas de S3/R2 e
///   o Bearer quebra a assinatura. `CachedNetworkImage` só envia o que está em
///   `httpHeaders`, que aqui fica vazio de propósito.
/// - O cache usa `photo:<id>:<variante>` e não a URL, porque a assinatura muda a
///   cada resposta mas o arquivo de um id é imutável.
/// - Se a imagem falha (URL expirada, 403), pede uma vez [refresher] e tenta de
///   novo com a URL nova. Enquanto isso mostra a cor dominante (ou superfície
///   neutra) e reserva o espaço pela proporção width/height quando existe.
class MaintenancePhotoImage extends StatefulWidget {
  const MaintenancePhotoImage({
    super.key,
    required this.photo,
    this.variant = PhotoVariant.thumb,
    this.fit = BoxFit.cover,
    this.refresher,
    this.useAspectRatio = false,
    this.memCacheWidth,
    this.showPlaceholder = true,
  });

  final MaintenancePhoto photo;
  final PhotoVariant variant;
  final BoxFit fit;
  final PhotoRefresher? refresher;

  /// Reserva o espaço pela proporção da foto. Em grades de células quadradas
  /// fica desligado.
  final bool useAspectRatio;
  final int? memCacheWidth;

  /// Falso deixa a imagem transparente enquanto carrega ou se falha. Usado na
  /// `master` do visualizador, que fica por cima da `display` já carregada.
  final bool showPlaceholder;

  @override
  State<MaintenancePhotoImage> createState() => _MaintenancePhotoImageState();
}

class _MaintenancePhotoImageState extends State<MaintenancePhotoImage> {
  late MaintenancePhoto _photo = widget.photo;
  int _attempt = 0;
  bool _refreshRequested = false;
  bool _failed = false;

  @override
  void didUpdateWidget(MaintenancePhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.photo.id != oldWidget.photo.id) {
      _photo = widget.photo;
      _attempt = 0;
      _refreshRequested = false;
      _failed = false;
      return;
    }

    final nextUrl = widget.photo.urlFor(widget.variant);
    if (nextUrl != _photo.urlFor(widget.variant)) {
      _photo = widget.photo;
      if (_failed) {
        _retryWithNewUrl();
      }
    }
  }

  void _retryWithNewUrl() {
    setState(() {
      _failed = false;
      _attempt++;
    });
  }

  void _onError() {
    if (_failed || _refreshRequested || widget.refresher == null) {
      _failed = true;
      return;
    }

    _refreshRequested = true;
    _failed = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fresh = await widget.refresher!(_photo);
      if (!mounted) {
        return;
      }

      if (fresh != null && fresh.urlFor(widget.variant) != null) {
        _photo = fresh;
        _retryWithNewUrl();
      }
    });
  }

  Color get _placeholderColor =>
      _photo.dominantColor ??
      Theme.of(context).colorScheme.surfaceContainerHighest;

  Widget _placeholder({IconData? icon}) {
    if (!widget.showPlaceholder) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: _placeholderColor,
      child: icon == null
          ? null
          : Center(
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _photo.urlFor(widget.variant);

    Widget child;
    if (url == null) {
      child = _placeholder(icon: Icons.image_not_supported_outlined);
    } else {
      child = CachedNetworkImage(
        key: ValueKey('photo-${_photo.id}-${widget.variant.name}-$_attempt'),
        imageUrl: url,
        cacheKey: _photo.cacheKey(widget.variant),
        httpHeaders: const {},
        fit: widget.fit,
        memCacheWidth: widget.memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) {
          _onError();
          return _placeholder(icon: Icons.broken_image_outlined);
        },
      );
    }

    final ratio = _photo.aspectRatio;
    if (widget.useAspectRatio && ratio != null) {
      child = AspectRatio(aspectRatio: ratio, child: child);
    }

    return child;
  }
}
