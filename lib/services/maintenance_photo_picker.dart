import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Escolha de fotos no aparelho. Isolado para os testes não abrirem o seletor
/// nativo.
///
/// A compressão acontece aqui, no aparelho: lado maior de 2048 px e qualidade
/// 85, que fica bem abaixo do limite de 5 MB do backend.
class MaintenancePhotoPicker {
  const MaintenancePhotoPicker();

  static const double maxDimension = 2048;
  static const int imageQuality = 85;

  /// Caminhos dos arquivos escolhidos; vazio se o usuário cancelou.
  Future<List<String>> pick(PhotoSource source) async {
    final picker = ImagePicker();

    if (source == PhotoSource.camera) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: imageQuality,
      );

      return file == null ? const [] : [file.path];
    }

    final files = await picker.pickMultiImage(
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: imageQuality,
    );

    return files.map((file) => file.path).toList();
  }
}
