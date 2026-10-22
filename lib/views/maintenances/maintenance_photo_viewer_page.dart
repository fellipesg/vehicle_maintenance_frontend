import 'package:flutter/material.dart';

import '../../models/maintenance_photo.dart';
import '../../widgets/photos/maintenance_photo_image.dart';

/// "Antes · Veículo" ou "Depois · Peça: Filtro de óleo".
String photoGroupLabel(
  MaintenancePhoto photo, [
  Map<int, String> itemNames = const {},
]) {
  final subject = photo.subject == PhotoSubject.part
      ? (itemNames[photo.maintenanceItemId] != null
          ? 'Peça: ${itemNames[photo.maintenanceItemId]}'
          : 'Peça')
      : 'Veículo';

  return '${photo.stage.label} · $subject';
}

/// "Foto 2 de 6 — Antes · Veículo".
String photoCaption(
  MaintenancePhoto photo, {
  required int position,
  required int total,
  Map<int, String> itemNames = const {},
}) {
  return 'Foto $position de $total — ${photoGroupLabel(photo, itemNames)}';
}

/// Visualizador em tela cheia das fotos de uma seção.
///
/// Desliza entre as fotos, dá zoom com pinça (ou toque duplo) e carrega a
/// variante `master` só quando o usuário aproxima; até lá usa a `display`.
/// Fecha devolvendo `true` se alguma foto foi excluída.
class MaintenancePhotoViewerPage extends StatefulWidget {
  const MaintenancePhotoViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.itemNames = const {},
    this.refresher,
    this.onDelete,
  });

  final List<MaintenancePhoto> photos;
  final int initialIndex;
  final Map<int, String> itemNames;
  final PhotoRefresher? refresher;

  /// Exclui a foto no servidor; `true` se excluiu. Nulo esconde o botão.
  final Future<bool> Function(MaintenancePhoto photo)? onDelete;

  @override
  State<MaintenancePhotoViewerPage> createState() =>
      _MaintenancePhotoViewerPageState();
}

class _MaintenancePhotoViewerPageState
    extends State<MaintenancePhotoViewerPage> {
  late List<MaintenancePhoto> _photos = List.of(widget.photos);
  late final PageController _controller;
  late int _index;
  bool _zoomed = false;
  bool _deletedAny = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_deletedAny);

  Future<void> _confirmDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _photos.isEmpty) {
      return;
    }

    final photo = _photos[_index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir foto'),
        content: const Text('Esta foto será removida da manutenção.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('photo_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await onDelete(photo);
    if (!deleted || !mounted) {
      return;
    }

    _deletedAny = true;
    if (_photos.length == 1) {
      _close();
      return;
    }

    setState(() {
      _photos = List.of(_photos)..removeAt(_index);
      _index = _index.clamp(0, _photos.length - 1);
      _zoomed = false;
    });
    _controller.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final total = _photos.length;
    final photo = _photos[_index];
    final caption = photoCaption(
      photo,
      position: _index + 1,
      total: total,
      itemNames: widget.itemNames,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            key: const Key('photo_viewer_pages'),
            controller: _controller,
            itemCount: total,
            // Com zoom, o arrasto move a imagem em vez de trocar de foto.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (value) => setState(() {
              _index = value;
              _zoomed = false;
            }),
            itemBuilder: (context, i) => _ZoomablePhoto(
              key: ValueKey('viewer-photo-${_photos[i].id}'),
              photo: _photos[i],
              refresher: widget.refresher,
              semanticLabel: photoCaption(
                _photos[i],
                position: i + 1,
                total: total,
                itemNames: widget.itemNames,
              ),
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed && i == _index) {
                  setState(() => _zoomed = zoomed);
                }
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('photo_viewer_close'),
                    tooltip: 'Fechar',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: _close,
                  ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    IconButton(
                      key: const Key('photo_viewer_delete'),
                      tooltip: 'Excluir foto',
                      color: Colors.white,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _confirmDelete,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black54,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    caption,
                    key: const Key('photo_viewer_caption'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.photo,
    required this.semanticLabel,
    required this.onZoomChanged,
    this.refresher,
  });

  final MaintenancePhoto photo;
  final String semanticLabel;
  final PhotoRefresher? refresher;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  static const double _masterScale = 1.5;
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  bool _useMaster = false;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;

    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }

    if (!_useMaster && scale >= _masterScale) {
      setState(() => _useMaster = true);
    }
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }

    final size = context.size ?? Size.zero;
    final dx = size.width * (1 - _doubleTapScale) / 2;
    final dy = size.height * (1 - _doubleTapScale) / 2;
    _transform.value = Matrix4.diagonal3Values(
      _doubleTapScale,
      _doubleTapScale,
      1,
    )..setTranslationRaw(dx, dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.photo.aspectRatio;
    final layers = Stack(
      fit: StackFit.expand,
      children: [
        MaintenancePhotoImage(
          photo: widget.photo,
          variant: PhotoVariant.display,
          fit: BoxFit.contain,
          refresher: widget.refresher,
        ),
        if (_useMaster)
          MaintenancePhotoImage(
            key: const Key('photo_viewer_master'),
            photo: widget.photo,
            variant: PhotoVariant.master,
            fit: BoxFit.contain,
            showPlaceholder: false,
          ),
      ],
    );

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: InteractiveViewer(
          key: const Key('photo_viewer_interactive'),
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: ratio != null
                ? AspectRatio(aspectRatio: ratio, child: layers)
                : SizedBox.expand(child: layers),
          ),
        ),
      ),
    );
  }
}
