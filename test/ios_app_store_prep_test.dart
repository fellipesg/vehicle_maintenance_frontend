import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Info.plist is ready for App Store review', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<string>RevisaLog</string>'));
    expect(plist, contains('ITSAppUsesNonExemptEncryption'));
    expect(plist, contains('remote-notification'));
    expect(plist, contains('NSUserNotificationsUsageDescription'));
    expect(plist, contains('UIApplicationSceneManifest'));
    expect(plist, contains('FlutterSceneDelegate'));
    expect(plist, contains('<key>UISceneStoryboardFile</key>'));
    expect(plist, contains('<string>Main</string>'));
  });

  test('iOS AppDelegate registers plugins through the scene lifecycle', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(appDelegate, contains('FlutterPluginRegistrant'));
    expect(appDelegate, contains('pluginRegistrant = self'));
    expect(appDelegate, contains('func register(with registry: FlutterPluginRegistry)'));
    expect(appDelegate, isNot(contains('GeneratedPluginRegistrant.register(with: self)')));
  });

  test('iOS privacy manifest and push entitlements are present', () {
    expect(File('ios/Runner/PrivacyInfo.xcprivacy').existsSync(), isTrue);
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('aps-environment'),
    );
  });

  test(
      'iOS marketing icon and iPhone-only family are set for first App Store submit',
      () {
    expect(
      File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
          .existsSync(),
      isTrue,
    );

    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbxproj, contains('TARGETED_DEVICE_FAMILY = 1;'));
    expect(pbxproj, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2";')));

    expect(
      File('ios/ExportOptions.plist').readAsStringSync(),
      contains('app-store-connect'),
    );

    expect(
      File('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png')
          .lengthSync(),
      greaterThan(1000),
    );
    expect(
      File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync(),
      contains('0.0431372549'),
    );
  });
}
