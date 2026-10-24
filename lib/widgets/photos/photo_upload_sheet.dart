import 'package:flutter/material.dart';

import '../../models/maintenance.dart';
import '../../models/maintenance_item.dart';
import '../../models/maintenance_photo.dart';
import '../../services/api_service.dart';
import '../../services/maintenance_photo_picker.dart';
import '../../services/maintenance_photo_uploader.dart';

/// Folha para enviar fotos: pergunta assunto (veículo/peça), item e momento,
/// abre câmera ou galeria e mostra o progresso de cada arquivo, com nova
/// tentativa para os que falharam.
class PhotoUploadSheet extends StatefulWidget {
  const PhotoUploadSheet({
    super.key,
    required this.api,
    required this.maintenance,
    required this.onUploaded,
    this.onFeatureDisabled,
    this.initialStage = PhotoStage.before,
    this.picker = const MaintenancePhotoPicker(),
  });

  final ApiService api;
  final Maintenance maintenance;
  final PhotoStage initialStage;
  final MaintenancePhotoPicker picker;

  /// Chamado quando ao menos um arquivo subiu, para a tela atualizar a seção.
  final VoidCallback onUploaded;

  /// Chamado quando o envio volta 403 (conta sem o recurso de fotos). A folha
  /// se fecha em seguida.
  final VoidCallback? onFeatureDisabled;

  @override
  State<PhotoUploadSheet> createState() => _PhotoUploadSheetState();
}

class _PhotoUploadSheetState extends State<PhotoUploadSheet> {
  PhotoSubject _subject = PhotoSubject.vehicle;
  late PhotoStage _stage = widget.initialStage;
  int? _itemId;
  String? _notice;
  MaintenancePhotoUploader? _uploader;

  List<MaintenanceItem> get _items => (widget.maintenance.items ?? const [])
      .where((item) => item.id != null)
      .toList();

  int get _existingInGroup => widget.maintenance.photos
      .where((photo) => photo.sameGroupAs(_subject, _stage))
      .length;

  @override
  void dispose() {
    _uploader?.dispose();
    super.dispose();
  }

  void _selectSubject(PhotoSubject subject) {
    setState(() {
      _subject = subject;
      _itemId = subject == PhotoSubject.part && _items.isNotEmpty
          ? (_itemId ?? _items.first.id)
          : null;
      _notice = null;
    });
  }

  Future<void> _pick(PhotoSource source) async {
    final remaining = MaintenancePhotoUploader.remainingSlots(_existingInGroup);

    if (remaining == 0) {
      setState(() {
        _notice = 'Este grupo já tem $maxPhotosPerGroup fotos, que é o máximo. '
            'Exclua uma foto para enviar outra.';
      });
      return;
    }

    var paths = await widget.picker.pick(source);
    if (paths.isEmpty || !mounted) {
      return;
    }

    String? notice;
    if (paths.length > remaining) {
      paths = paths.take(remaining).toList();
      notice = 'Só cabem mais $remaining foto(s) neste grupo '
          '(máximo $maxPhotosPerGroup). As demais foram ignoradas.';
    }

    final uploader = MaintenancePhotoUploader(
      api: widget.api,
      maintenanceId: widget.maintenance.id!,
      subject: _subject,
      stage: _stage,
      maintenanceItemId: _subject == PhotoSubject.part ? _itemId : null,
      paths: paths,
    );

    setState(() {
      _notice = notice;
      _uploader = uploader;
    });

    await _run(uploader);
  }

  Future<void> _run(MaintenancePhotoUploader uploader) async {
    await uploader.start();

    if (uploader.hasUploaded) {
      widget.onUploaded();
    }

    if (uploader.featureDisabled) {
      widget.onFeatureDisabled?.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploader = _uploader;

    return PopScope(
      canPop: uploader == null || !uploader.isRunning,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: uploader == null
                ? _buildForm(context)
                : _buildProgress(context, uploader),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final remaining = MaintenancePhotoUploader.remainingSlots(_existingInGroup);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Adicionar fotos', style: textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('O que aparece na foto?', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<PhotoSubject>(
          key: const Key('upload_subject'),
          showSelectedIcon: false,
          segments: [
            for (final subject in PhotoSubject.values)
              ButtonSegment(value: subject, label: Text(subject.label)),
          ],
          selected: {_subject},
          onSelectionChanged: (value) => _selectSubject(value.first),
        ),
        if (_subject == PhotoSubject.part && _items.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('upload_item'),
            initialValue: _itemId ?? _items.first.id,
            decoration: const InputDecoration(labelText: 'Peça'),
            items: [
              for (final item in _items)
                DropdownMenuItem(value: item.id, child: Text(item.name)),
            ],
            onChanged: (value) => setState(() => _itemId = value),
          ),
        ],
        const SizedBox(height: 16),
        Text('Momento', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<PhotoStage>(
          key: const Key('upload_stage'),
          showSelectedIcon: false,
          segments: [
            for (final stage in PhotoStage.values)
              ButtonSegment(value: stage, label: Text(stage.label)),
          ],
          selected: {_stage},
          onSelectionChanged: (value) => setState(() {
            _stage = value.first;
            _notice = null;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          remaining == 0
              ? 'Este grupo está cheio ($maxPhotosPerGroup de '
                  '$maxPhotosPerGroup).'
              : 'Cabem mais $remaining foto(s) neste grupo '
                  '(máximo $maxPhotosPerGroup).',
          key: const Key('upload_group_hint'),
          style: textTheme.bodySmall,
        ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(
            _notice!,
            key: const Key('upload_notice'),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('upload_camera'),
                onPressed: () => _pick(PhotoSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tirar foto'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('upload_gallery'),
                onPressed: () => _pick(PhotoSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress(
    BuildContext context,
    MaintenancePhotoUploader uploader,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: uploader,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enviando fotos', style: textTheme.titleLarge),
            if (_notice != null) ...[
              const SizedBox(height: 8),
              Text(_notice!, style: textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < uploader.items.length; i++)
              _UploadRow(index: i, item: uploader.items[i]),
            const SizedBox(height: 12),
            if (uploader.isFinished && uploader.hasFailures)
              FilledButton.icon(
                key: const Key('photo_upload_retry'),
                onPressed: () => _run(uploader),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            if (uploader.isFinished)
              TextButton(
                key: const Key('photo_upload_done'),
                onPressed: () =>
                    Navigator.of(context).pop(uploader.hasUploaded),
                child: Text(uploader.hasFailures ? 'Fechar' : 'Concluir'),
              ),
          ],
        );
      },
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.index, required this.item});

  final int index;
  final PhotoUploadItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color) = switch (item.status) {
      PhotoUploadStatus.done => (Icons.check_circle, Colors.green),
      PhotoUploadStatus.failed => (Icons.error_outline, scheme.error),
      _ => (Icons.cloud_upload_outlined, scheme.primary),
    };

    return Padding(
      key: Key('upload_row_$index'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (item.status == PhotoUploadStatus.uploading ||
                    item.status == PhotoUploadStatus.pending)
                  LinearProgressIndicator(
                    key: Key('upload_progress_$index'),
                    value: item.status == PhotoUploadStatus.uploading
                        ? item.progress
                        : 0,
                  ),
                if (item.status == PhotoUploadStatus.done)
                  const Text('Enviada'),
                if (item.status == PhotoUploadStatus.failed)
                  Text(
                    item.error ?? 'Erro ao enviar a foto',
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
