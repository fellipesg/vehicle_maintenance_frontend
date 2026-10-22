import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance.dart';
import '../../models/maintenance_photo.dart';
import '../../services/api_service.dart';
import 'maintenance_photo_image.dart';

/// Faixa de fotos do card da timeline: até duas miniaturas (antes → depois
/// quando é um par), "+N" se há mais fotos que a prévia e, quando as fotos
/// existem mas o usuário ainda não pode vê-las, um cadeado com o aviso.
///
/// Não trata toque: o card inteiro já abre o detalhe da manutenção.
class TimelinePhotoStrip extends StatelessWidget {
  const TimelinePhotoStrip({
    super.key,
    required this.maintenanceId,
    required this.preview,
    required this.photosCount,
    required this.locked,
    this.refresher,
  });

  /// Lê `photo_preview`, `photos_count` e `photos_locked` de um evento de
  /// manutenção da timeline; `null` quando não há nada a mostrar.
  static TimelinePhotoStrip? fromEvent(Map<String, dynamic> event) {
    final preview = Maintenance.parsePhotos(event['photo_preview']);
    final count = int.tryParse('${event['photos_count'] ?? ''}') ?? 0;
    final locked = event['photos_locked'] == true;
    final id = int.tryParse('${event['id'] ?? ''}');

    if (id == null || (!locked && preview.isEmpty && count <= 0)) {
      return null;
    }

    return TimelinePhotoStrip(
      maintenanceId: id,
      preview: preview,
      photosCount: count < preview.length ? preview.length : count,
      locked: locked,
    );
  }

  final int maintenanceId;
  final List<MaintenancePhoto> preview;
  final int photosCount;
  final bool locked;

  /// Se nulo, usa o `ApiService` do contexto para reler a manutenção.
  final PhotoRefresher? refresher;

  static const double _size = 44;

  PhotoRefresher? _defaultRefresher(BuildContext context) {
    ApiService? api;
    try {
      api = context.read<ApiService>();
    } catch (_) {
      return null;
    }

    return (photo) async {
      try {
        final response = await api!.getMaintenance(maintenanceId.toString());
        final data = response.data is Map ? response.data['data'] : null;
        if (data is! Map) {
          return null;
        }

        for (final fresh in Maintenance.parsePhotos(data['photos'])) {
          if (fresh.id == photo.id) {
            return fresh;
          }
        }
      } catch (_) {
        // Fica no placeholder.
      }

      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (locked) {
      final label = photosCount > 0
          ? (photosCount == 1
              ? '1 foto aguardando aceite do proprietário'
              : '$photosCount fotos aguardando aceite do proprietário')
          : 'Fotos aguardando aceite do proprietário';

      return Padding(
        key: const Key('timeline_photos_locked'),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: textTheme.bodySmall),
              ),
            ],
          ),
        ),
      );
    }

    final extra = photosCount - preview.length;
    final isPair = preview.length == 2 &&
        preview[0].stage == PhotoStage.before &&
        preview[1].stage == PhotoStage.after;
    final effectiveRefresher = refresher ?? _defaultRefresher(context);

    final summary = isPair ? 'Fotos de antes e depois' : 'Fotos da manutenção';

    return Padding(
      key: const Key('timeline_photo_strip'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Semantics(
        label: extra > 0 ? '$summary, mais $extra' : summary,
        excludeSemantics: true,
        child: Row(
          children: [
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0)
                isPair
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          key: const Key('timeline_photo_arrow'),
                          size: 16,
                          color: scheme.outline,
                        ),
                      )
                    : const SizedBox(width: 6),
              SizedBox(
                width: _size,
                height: _size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: MaintenancePhotoImage(
                    key: Key('timeline_photo_${preview[i].id}'),
                    photo: preview[i],
                    refresher: effectiveRefresher,
                    memCacheWidth: 150,
                  ),
                ),
              ),
            ],
            if (extra > 0) ...[
              const SizedBox(width: 8),
              Text(
                '+$extra',
                key: const Key('timeline_photo_more'),
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
