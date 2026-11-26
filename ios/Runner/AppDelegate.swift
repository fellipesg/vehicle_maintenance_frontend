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

  /// True while the system ATT prompt is on screen, so a second activation
  /// does not ask again.
  private var isRequestingTrackingAuthorization = false

  private static let metaEventsChannelName = "br.com.revisalog.app/meta_events"

  /// Only these names cross the channel. Value is the Meta event name.
  /// No parameters and no personal data are ever attached.
  private static let metaEventNames: [String: AppEvents.Name] = [
    "complete_registration": .completedRegistration,
    "vehicle_added": AppEvents.Name("VehicleAdded"),
  ]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    observeMetaTrackingAuthorization()
    configureMetaAppEvents(application, launchOptions: launchOptions)

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    application.registerForRemoteNotifications()
    return launched
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
    registerMetaEventsChannel(with: registry)
  }

  /// Dart-to-native bridge for the two conversion events. The argument is a
  /// string looked up in `metaEventNames`; anything else is not implemented.
  private func registerMetaEventsChannel(with registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "MetaAppEventsChannel")?.messenger() else {
      return
    }

    let channel = FlutterMethodChannel(
      name: AppDelegate.metaEventsChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "log",
        let key = call.arguments as? String,
        let eventName = AppDelegate.metaEventNames[key]
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      AppEvents.shared.logEvent(eventName)
      result(nil)
    }
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

  /// The Info.plist adopts UIScene, so UIKit never calls
  /// `applicationDidBecomeActive(_:)` on the app delegate: overriding it left
  /// the ATT prompt unasked and automatic event logging off forever. The
  /// `UIApplication.didBecomeActiveNotification` is posted in both lifecycles.
  private func observeMetaTrackingAuthorization() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleApplicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func handleApplicationDidBecomeActive() {
    requestMetaTrackingAuthorization()
  }

  /// Runs on every activation. Asks only while the status is `.notDetermined`;
  /// if the user already answered (here or in Settings) it just syncs the
  /// Meta flags and releases the held automatic logging.
  private func requestMetaTrackingAuthorization() {
    let status = ATTrackingManager.trackingAuthorizationStatus

    if status != .notDetermined {
      finishMetaTrackingAuthorization(status)
      return
    }

    guard !isRequestingTrackingAuthorization else {
      return
    }
    isRequestingTrackingAuthorization = true

    ATTrackingManager.requestTrackingAuthorization { _ in
      DispatchQueue.main.async {
        self.isRequestingTrackingAuthorization = false
        let current = ATTrackingManager.trackingAuthorizationStatus
        if current != .notDetermined {
          self.finishMetaTrackingAuthorization(current)
        }
        // Still .notDetermined (prompt not shown): the flag stays pending
        // and the next activation tries again.
      }
    }
  }

  private func finishMetaTrackingAuthorization(_ status: ATTrackingManager.AuthorizationStatus) {
    applyMetaAdvertiserTracking(status)
    guard logActivationAfterTrackingPrompt else {
      return
    }
    logActivationAfterTrackingPrompt = false
    Settings.shared.isAutoLogAppEventsEnabled = true
    AppEvents.shared.activateApp()
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
