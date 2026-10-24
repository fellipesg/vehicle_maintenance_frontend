import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance.dart';
import '../../models/maintenance_photo.dart';
import '../../services/api_error.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/maintenance_photos_feature.dart';
import '../../services/maintenance_photo_picker.dart';
import '../../views/maintenances/maintenance_photo_viewer_page.dart';
import 'maintenance_photo_image.dart';
import 'photo_upload_sheet.dart';

/// Seção "Fotos" do detalhe da manutenção.
///
/// Estados: bloqueada (fotos existem mas o proprietário ainda não aceitou),
/// com fotos (Antes | Durante | Depois, grade por Veículo e por peça), vazia
/// com envio liberado ("Adicionar fotos") e oculta para quem nada pode ver nem
/// enviar — quem decide ocultar é [shouldShow].
class MaintenancePhotosSection extends StatefulWidget {
  const MaintenancePhotosSection({
    super.key,
    required this.maintenance,
    required this.canManage,
    required this.onChanged,
    this.refresher,
    this.picker = const MaintenancePhotoPicker(),
  });

  final Maintenance maintenance;

  /// Pode enviar e excluir (mesma regra da nota fiscal: `MaintenancePolicy`).
  final bool canManage;

  /// Recarrega a manutenção depois de enviar ou excluir.
  final Future<void> Function() onChanged;
  final PhotoRefresher? refresher;
  final MaintenancePhotoPicker picker;

  static bool shouldShow(Maintenance maintenance, {required bool canManage}) {
    return maintenance.photosLocked ||
        maintenance.photos.isNotEmpty ||
        canManage;
  }

  @override
  State<MaintenancePhotosSection> createState() =>
      _MaintenancePhotosSectionState();
}

class _MaintenancePhotosSectionState extends State<MaintenancePhotosSection> {
  PhotoStage? _selectedStage;

  List<MaintenancePhoto> get _photos => widget.maintenance.photos;

  Map<int, String> get _itemNames => {
        for (final item in widget.maintenance.items ?? const [])
          if (item.id != null) item.id!: item.name,
      };

  List<MaintenancePhoto> _photosOf(PhotoStage stage) {
    final list = _photos.where((photo) => photo.stage == stage).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));

    return list;
  }

  List<PhotoStage> get _visibleStages => [
        for (final stage in PhotoStage.values)
          if (widget.canManage || _photosOf(stage).isNotEmpty) stage,
      ];

  PhotoStage get _stage {
    final visible = _visibleStages;
    final selected = _selectedStage;

    if (selected != null && visible.contains(selected)) {
      return selected;
    }

    for (final stage in PhotoStage.values) {
      if (_photosOf(stage).isNotEmpty) {
        return stage;
      }
    }

    return visible.isEmpty ? PhotoStage.before : visible.first;
  }

  /// Fotos de uma etapa na ordem exibida: veículo primeiro, depois cada peça.
  List<MaintenancePhoto> _orderedPhotos(PhotoStage stage) {
    final all = _photosOf(stage);
    final vehicle =
        all.where((photo) => photo.subject == PhotoSubject.vehicle).toList();
    final parts = all.where((photo) => photo.subject == PhotoSubject.part);

    final byItem = <int?, List<MaintenancePhoto>>{};
    for (final photo in parts) {
      byItem.putIfAbsent(photo.maintenanceItemId, () => []).add(photo);
    }

    return [...vehicle, for (final group in byItem.values) ...group];
  }

  Future<void> _openViewer(
    List<MaintenancePhoto> photos,
    MaintenancePhoto tapped,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaintenancePhotoViewerPage(
          photos: photos,
          initialIndex: photos.indexWhere((p) => p.id == tapped.id),
          itemNames: _itemNames,
          refresher: widget.refresher,
          onDelete: widget.canManage ? _deletePhoto : null,
        ),
      ),
    );
  }

  Future<bool> _deletePhoto(MaintenancePhoto photo) async {
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.deleteMaintenancePhoto(
        maintenanceId: photo.maintenanceId,
        photoId: photo.id,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(error, fallback: 'Erro ao excluir a foto'),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Foto excluída.')));
    await widget.onChanged();

    return true;
  }

  Future<void> _openUpload() async {
    var uploaded = false;
    var featureDisabled = false;
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PhotoUploadSheet(
        api: context.read<ApiService>(),
        maintenance: widget.maintenance,
        initialStage: _stage,
        picker: widget.picker,
        onUploaded: () => uploaded = true,
        onFeatureDisabled: () => featureDisabled = true,
      ),
    );

    if (featureDisabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text(MaintenancePhotosFeature.disabledMessage)),
      );
      await auth.getCurrentUser();
      if (mounted) {
        await widget.onChanged();
      }
      return;
    }

    if (uploaded && mounted) {
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = widget.maintenance;
    final theme = Theme.of(context);

    if (!MaintenancePhotosFeature.of(context)) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('photos_section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fotos',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (maintenance.photosLocked)
              _buildLocked(context)
            else if (_photos.isEmpty)
              _buildEmpty(context)
            else
              ..._buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLocked(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.maintenance.photosCount;

    return Container(
      key: const Key('photos_locked_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fotos aguardando aceite do proprietário',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (count > 0)
                  Text(
                    count == 1 ? '1 foto' : '$count fotos',
                    key: const Key('photos_locked_count'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nenhuma foto ainda.'),
        const SizedBox(height: 8),
        if (widget.canManage) _addButton(filled: true),
      ],
    );
  }

  Widget _addButton({required bool filled}) {
    const label = Text('Adicionar fotos');
    const icon = Icon(Icons.add_a_photo_outlined);

    return filled
        ? FilledButton.icon(
            key: const Key('add_photos_button'),
            onPressed: _openUpload,
            icon: icon,
            label: label,
          )
        : TextButton.icon(
            key: const Key('add_photos_button'),
            onPressed: _openUpload,
            icon: icon,
            label: label,
          );
  }

  List<Widget> _buildContent(BuildContext context) {
    final stage = _stage;
    final stagePhotos = _photosOf(stage);
    final ordered = _orderedPhotos(stage);

    return [
      _buildBeforeAfter(context),
      SegmentedButton<PhotoStage>(
        key: const Key('photos_stage_selector'),
        showSelectedIcon: false,
        segments: [
          for (final candidate in _visibleStages)
            ButtonSegment(
              value: candidate,
              label: Text(
                '${candidate.label} (${_photosOf(candidate).length})',
              ),
            ),
        ],
        selected: {stage},
        onSelectionChanged: (value) =>
            setState(() => _selectedStage = value.first),
      ),
      const SizedBox(height: 12),
      if (stagePhotos.isEmpty)
        Text(
          'Nenhuma foto de "${stage.label}" ainda.',
          style: Theme.of(context).textTheme.bodyMedium,
        )
      else
        ..._buildGroups(context, stagePhotos, ordered),
      if (widget.canManage) ...[
        const SizedBox(height: 4),
        _addButton(filled: false),
      ],
    ];
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<MaintenancePhoto> stagePhotos,
    List<MaintenancePhoto> ordered,
  ) {
    final vehicle =
        stagePhotos.where((p) => p.subject == PhotoSubject.vehicle).toList();
    final byItem = <int?, List<MaintenancePhoto>>{};
    for (final photo in stagePhotos.where(
      (p) => p.subject == PhotoSubject.part,
    )) {
      byItem.putIfAbsent(photo.maintenanceItemId, () => []).add(photo);
    }

    return [
      if (vehicle.isNotEmpty) _group(context, 'Veículo', vehicle, ordered),
      for (final entry in byItem.entries)
        _group(context, _itemNames[entry.key] ?? 'Peça', entry.value, ordered),
    ];
  }

  Widget _group(
    BuildContext context,
    String title,
    List<MaintenancePhoto> photos,
    List<MaintenancePhoto> ordered,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final photo in photos)
                _Thumb(
                  key: Key('photo_thumb_${photo.id}'),
                  photo: photo,
                  label: photoCaption(
                    photo,
                    position: ordered.indexWhere((p) => p.id == photo.id) + 1,
                    total: ordered.length,
                    itemNames: _itemNames,
                  ),
                  refresher: widget.refresher,
                  onTap: () => _openViewer(ordered, photo),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Primeira foto do veículo antes e depois, lado a lado, quando as duas
  /// existem.
  Widget _buildBeforeAfter(BuildContext context) {
    MaintenancePhoto? first(PhotoStage stage) {
      for (final photo in _photosOf(stage)) {
        if (photo.subject == PhotoSubject.vehicle) {
          return photo;
        }
      }

      return null;
    }

    final before = first(PhotoStage.before);
    final after = first(PhotoStage.after);

    if (before == null || after == null) {
      return const SizedBox.shrink();
    }

    final pair = [before, after];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        key: const Key('photos_before_after'),
        children: [
          for (var i = 0; i < pair.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair[i].stage.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  _Thumb(
                    key: Key('photo_compare_${pair[i].id}'),
                    photo: pair[i],
                    aspectRatio: 4 / 3,
                    label: photoCaption(
                      pair[i],
                      position: i + 1,
                      total: pair.length,
                      itemNames: _itemNames,
                    ),
                    variant: PhotoVariant.display,
                    refresher: widget.refresher,
                    onTap: () => _openViewer(pair, pair[i]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.photo,
    required this.label,
    required this.onTap,
    this.refresher,
    this.aspectRatio = 1,
    this.variant = PhotoVariant.thumb,
  });

  final MaintenancePhoto photo;
  final String label;
  final VoidCallback onTap;
  final PhotoRefresher? refresher;
  final double aspectRatio;
  final PhotoVariant variant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      image: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MaintenancePhotoImage(
                photo: photo,
                variant: variant,
                refresher: refresher,
                memCacheWidth: 400,
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
