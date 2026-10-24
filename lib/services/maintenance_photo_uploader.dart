import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/maintenance_photo.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'maintenance_photos_feature.dart';

/// Limite de fotos por grupo (assunto + momento) imposto pelo backend.
const int maxPhotosPerGroup = 4;

enum PhotoUploadStatus { pending, uploading, done, failed }

class PhotoUploadItem {
  PhotoUploadItem({required this.path});

  final String path;
  PhotoUploadStatus status = PhotoUploadStatus.pending;

  /// 0.0 a 1.0 enquanto envia.
  double progress = 0;
  String? error;

  String get name => path.split('/').last;
}

/// Fila de envio de fotos de uma manutenção, um arquivo por vez.
///
/// Cada arquivo tem progresso e erro próprios, então uma falha (rede, 422 de
/// limite por grupo) não derruba os demais e pode ser repetida com [retry].
class MaintenancePhotoUploader extends ChangeNotifier {
  MaintenancePhotoUploader({
    required this.api,
    required this.maintenanceId,
    required this.subject,
    required this.stage,
    required List<String> paths,
    this.maintenanceItemId,
  }) : items = paths.map((path) => PhotoUploadItem(path: path)).toList();

  final ApiService api;
  final int maintenanceId;
  final PhotoSubject subject;
  final PhotoStage stage;
  final int? maintenanceItemId;
  final List<PhotoUploadItem> items;

  /// O backend respondeu 403: a conta não tem o recurso de fotos. Interrompe a
  /// fila, porque os demais envios receberiam a mesma resposta.
  bool featureDisabled = false;

  bool _running = false;
  bool _disposed = false;

  bool get isRunning => _running;
  bool get hasFailures =>
      items.any((item) => item.status == PhotoUploadStatus.failed);
  bool get hasUploaded =>
      items.any((item) => item.status == PhotoUploadStatus.done);
  bool get isFinished =>
      !_running &&
      items.every(
        (item) =>
            item.status == PhotoUploadStatus.done ||
            item.status == PhotoUploadStatus.failed,
      );

  /// Quantos arquivos ainda cabem no grupo, dado quantos já existem nele.
  static int remainingSlots(int existingInGroup) {
    final remaining = maxPhotosPerGroup - existingInGroup;

    return remaining < 0 ? 0 : remaining;
  }

  /// Envia todos os pendentes e os que falharam antes.
  Future<void> start() async {
    if (_running) {
      return;
    }

    _running = true;
    _notify();

    for (final item in items) {
      if (item.status == PhotoUploadStatus.done) {
        continue;
      }

      await _send(item);
      if (featureDisabled) {
        break;
      }
    }

    _running = false;
    _notify();
  }

  /// Repete só os arquivos que falharam.
  Future<void> retryFailed() => start();

  Future<void> _send(PhotoUploadItem item) async {
    item
      ..status = PhotoUploadStatus.uploading
      ..progress = 0
      ..error = null;
    _notify();

    try {
      await api.uploadMaintenancePhoto(
        maintenanceId: maintenanceId,
        filePath: item.path,
        subject: subject,
        stage: stage,
        maintenanceItemId: maintenanceItemId,
        onSendProgress: (sent, total) {
          if (total > 0) {
            item.progress = sent / total;
            _notify();
          }
        },
      );

      item
        ..status = PhotoUploadStatus.done
        ..progress = 1;
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 403) {
        featureDisabled = true;
      }
      item
        ..status = PhotoUploadStatus.failed
        ..error = featureDisabled
            ? MaintenancePhotosFeature.disabledMessage
            : apiErrorMessage(error, fallback: 'Erro ao enviar a foto');
    }

    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
