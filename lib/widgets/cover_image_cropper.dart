import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'cover_framing.dart';

class CoverImageCropper {
  Future<File?> cropLandscape(String sourcePath) {
    return crop(
      sourcePath,
      ratioX: CoverFramingLandscape.ratioX,
      ratioY: CoverFramingLandscape.ratioY,
      title: CoverFramingLandscape.title,
      maxWidth: CoverFramingLandscape.maxWidth,
      compressQuality: CoverFramingLandscape.compressQuality,
    );
  }

  Future<File?> cropPortrait(String sourcePath) {
    return crop(
      sourcePath,
      ratioX: CoverFramingPortrait.ratioX,
      ratioY: CoverFramingPortrait.ratioY,
      title: CoverFramingPortrait.title,
      maxWidth: CoverFramingPortrait.maxWidth,
      compressQuality: CoverFramingPortrait.compressQuality,
    );
  }

  Future<File?> crop(
    String sourcePath, {
    required double ratioX,
    required double ratioY,
    required String title,
    required int maxWidth,
    required int compressQuality,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: CropAspectRatio(
        ratioX: ratioX,
        ratioY: ratioY,
      ),
      maxWidth: maxWidth,
      compressQuality: compressQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFFC9956A),
          toolbarWidgetColor: const Color(0xFF141210),
          lockAspectRatio: true,
          hideBottomControls: true,
          aspectRatioPresets: [CropAspectRatioPreset.ratio16x9],
        ),
        IOSUiSettings(
          title: title,
          doneButtonTitle: CoverFramingLandscape.confirmLabel,
          cancelButtonTitle: CoverFramingLandscape.cancelLabel,
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

  /// Backward-compatible alias.
  Future<File?> cropLegacy(String sourcePath) => cropLandscape(sourcePath);
}
