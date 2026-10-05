import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release uses the Play Store package and upload key', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/br/com/revisalog/app/MainActivity.kt',
    ).readAsStringSync();
    final example =
        File('android/app/google-services.json.example').readAsStringSync();

    expect(gradle, contains('namespace "br.com.revisalog.app"'));
    expect(gradle, contains('applicationId "br.com.revisalog.app"'));
    expect(gradle, contains("rootProject.file('key.properties')"));
    expect(gradle, contains('signingConfig signingConfigs.release'));
    expect(gradle, isNot(contains('signingConfigs.debug')));
    expect(manifest, contains('android:label="RevisaLog"'));
    expect(activity, contains('package br.com.revisalog.app'));
    expect(example, contains('br.com.revisalog.app'));
    expect(
      File(
        'android/app/src/main/kotlin/com/example/vehicle_maintenance/MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });
}
