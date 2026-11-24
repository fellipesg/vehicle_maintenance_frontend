import AppTrackingTransparency
import FBSDKCoreKit
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  /// Holds automatic install/activate logging until the first ATT answer, so that
  /// event is not sent before the advertiser-tracking flag is known.
  private var logActivationAfterTrackingPrompt = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    configureMetaAppEvents(application, launchOptions: launchOptions)

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    application.registerForRemoteNotifications()
    return launched
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    requestMetaTrackingAuthorization()
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }

  /// FBSDKCoreKit only: automatic install and app-open events. No Login, no sharing.
  private func configureMetaAppEvents(
    _ application: UIApplication,
    launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) {
    let status = ATTrackingManager.trackingAuthorizationStatus
    applyMetaAdvertiserTracking(status)

    if status == .notDetermined {
      Settings.shared.isAutoLogAppEventsEnabled = false
      logActivationAfterTrackingPrompt = true
    } else {
      Settings.shared.isAutoLogAppEventsEnabled = true
    }

    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  private func requestMetaTrackingAuthorization() {
    ATTrackingManager.requestTrackingAuthorization { status in
      DispatchQueue.main.async {
        self.applyMetaAdvertiserTracking(status)
        guard self.logActivationAfterTrackingPrompt else {
          return
        }
        self.logActivationAfterTrackingPrompt = false
        Settings.shared.isAutoLogAppEventsEnabled = true
        AppEvents.shared.activateApp()
      }
    }
  }

  /// On iOS 17 and later, FBSDKCoreKit 17+ reads ATT itself and ignores this setter.
  /// On iOS 15 and 16 the setter is still the Advertiser Tracking Enabled flag.
  private func applyMetaAdvertiserTracking(_ status: ATTrackingManager.AuthorizationStatus) {
    let authorized = status == .authorized
    Settings.shared.isAdvertiserIDCollectionEnabled = authorized
    if #unavailable(iOS 17) {
      Settings.shared.isAdvertiserTrackingEnabled = authorized
    }
  }
}
