import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'cover_framing.dart';

class CoverImageCropper {
  Future<File?> crop(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(
        ratioX: CoverFraming.ratioX,
        ratioY: CoverFraming.ratioY,
      ),
      maxWidth: CoverFraming.maxWidth,
      compressQuality: CoverFraming.compressQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: CoverFraming.title,
          toolbarColor: const Color(0xFFC9956A),
          toolbarWidgetColor: const Color(0xFF141210),
          lockAspectRatio: true,
          hideBottomControls: true,
          aspectRatioPresets: [CropAspectRatioPreset.ratio16x9],
        ),
        IOSUiSettings(
          title: CoverFraming.title,
          doneButtonTitle: CoverFraming.confirmLabel,
          cancelButtonTitle: CoverFraming.cancelLabel,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: [CropAspectRatioPreset.ratio16x9],
        ),
      ],
    );

    if (cropped == null) {
      return null;
    }

    return File(cropped.path);
  }
}
