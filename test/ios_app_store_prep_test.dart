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

  test('iOS app declares Portuguese (Brazil) so the App Store lists it', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(
      plist,
      matches(RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>\s*<string>pt-BR</string>')),
    );
    expect(project, contains('developmentRegion = "pt-BR";'));
    expect(project, contains('"pt-BR",'));
  });

  test('iOS AppDelegate registers plugins through the scene lifecycle', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(appDelegate, contains('FlutterPluginRegistrant'));
    expect(appDelegate, contains('pluginRegistrant = self'));
    expect(appDelegate,
        contains('func register(with registry: FlutterPluginRegistry)'));
    expect(appDelegate,
        isNot(contains('GeneratedPluginRegistrant.register(with: self)')));
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

  test('Meta SDK measures iOS installs and app opens without Login or sharing',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final facebookConfig =
        File('ios/Flutter/Facebook.xcconfig').readAsStringSync();
    final debugConfig = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    final releaseConfig =
        File('ios/Flutter/Release.xcconfig').readAsStringSync();

    expect(facebookConfig, contains('FACEBOOK_APP_ID = 2189828138277238'));
    expect(
      facebookConfig,
      contains('FACEBOOK_CLIENT_TOKEN = f2e99ff0a50e089f40d0ea7e65a3e9b6'),
    );
    expect(
        facebookConfig, isNot(contains('FACEBOOK_CLIENT_TOKEN_PLACEHOLDER')));
    expect(facebookConfig, contains('FACEBOOK_DISPLAY_NAME = RevisaLog'));
    expect(debugConfig, contains('#include "Facebook.xcconfig"'));
    expect(releaseConfig, contains('#include "Facebook.xcconfig"'));

    expect(plist, contains('<key>FacebookAppID</key>'));
    expect(plist, contains('<string>\$(FACEBOOK_APP_ID)</string>'));
    expect(plist, contains('<key>FacebookClientToken</key>'));
    expect(plist, contains('<string>\$(FACEBOOK_CLIENT_TOKEN)</string>'));
    expect(plist, contains('<key>FacebookDisplayName</key>'));
    expect(plist, contains('<string>\$(FACEBOOK_DISPLAY_NAME)</string>'));
    expect(
      plist,
      matches(RegExp(
        r'<key>FacebookAutoLogAppEventsEnabled</key>\s*<true\s*/>',
      )),
    );
    expect(
      plist,
      matches(RegExp(
        r'<key>FacebookAdvertiserIDCollectionEnabled</key>\s*<false\s*/>',
      )),
    );
    expect(plist, contains('<string>fb\$(FACEBOOK_APP_ID)</string>'));
    expect(plist, contains('v9wttpbfk9.skadnetwork'));
    expect(plist, contains('n38lu8286q.skadnetwork'));

    final trackingCopy = RegExp(
      '<key>NSUserTrackingUsageDescription</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    expect(trackingCopy, isNotNull);
    expect(trackingCopy!.group(1), contains('anúncios'));
    expect(trackingCopy.group(1), contains('RevisaLog'));

    expect(plist, isNot(contains('fbapi')));
    expect(plist, isNot(contains('fb-messenger-share-api')));
    expect(podfile, contains("pod 'FBSDKCoreKit', '18.0.3'"));
    expect(
      File('ios/Podfile.lock').readAsStringSync(),
      contains('FBSDKCoreKit (18.0.3)'),
    );
    expect(podfile, isNot(contains('FBSDKLoginKit')));
    expect(podfile, isNot(contains('FBSDKShareKit')));

    expect(appDelegate, contains('import FBSDKCoreKit'));
    expect(appDelegate, contains('ApplicationDelegate.shared.application'));
    expect(appDelegate,
        contains('ATTrackingManager.requestTrackingAuthorization'));
    expect(
        appDelegate, contains('isAdvertiserIDCollectionEnabled = authorized'));
    expect(appDelegate, contains('isAdvertiserTrackingEnabled = authorized'));
    expect(appDelegate, contains('isAutoLogAppEventsEnabled = true'));
    expect(appDelegate, contains('AppEvents.shared.activateApp()'));
    expect(appDelegate, contains('#unavailable(iOS 17)'));

    // UIScene: UIKit never calls the delegate method, so ATT was never asked.
    expect(
      appDelegate,
      isNot(contains('override func applicationDidBecomeActive')),
    );
    expect(appDelegate, contains('UIApplication.didBecomeActiveNotification'));
    expect(appDelegate, contains('isRequestingTrackingAuthorization'));
    expect(
      appDelegate.indexOf('observeMetaTrackingAuthorization()\n'),
      lessThan(appDelegate.indexOf('configureMetaAppEvents(application')),
    );

    expect(privacy, contains('<key>NSPrivacyTracking</key>'));
    expect(
      privacy,
      matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<true\s*/>')),
    );
    expect(privacy, contains('ep1.facebook.com'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeProductInteraction'));
  });

  test('Meta events channel only accepts the whitelisted names', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(appDelegate, contains('br.com.revisalog.app/meta_events'));
    expect(
      appDelegate,
      contains('"complete_registration": .completedRegistration'),
    );
    expect(appDelegate, contains('AppEvents.Name("VehicleAdded")'));
    expect(appDelegate, contains('FlutterMethodNotImplemented'));
    expect(appDelegate, contains('AppEvents.shared.logEvent(eventName)'));
    expect(appDelegate, isNot(contains('parameters:')));
    expect(
      appDelegate.indexOf('GeneratedPluginRegistrant.register(with: registry)'),
      lessThan(appDelegate.indexOf('registerMetaEventsChannel(with: registry)')),
    );
  });

  test('iOS permission texts describe camera and photo uses in pt-BR', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    for (final key in [
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
    ]) {
      final match = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
          .firstMatch(plist);

      expect(match, isNotNull, reason: key);
      expect(match!.group(1), contains('manutenç'), reason: key);
      expect(match.group(1), contains('capa do veículo'), reason: key);
    }
  });
}
