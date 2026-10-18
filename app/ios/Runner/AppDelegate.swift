import Flutter
import UIKit

// iOS 27 stops apps that do not adopt the UIScene lifecycle at launch, so the window belongs
// to FlutterSceneDelegate (Info.plist, UIApplicationSceneManifest) and `window` here stays
// nil: plugins and channels are registered once the implicit engine exists.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications (README, "iOS setup"): the delegate must be set so
    // scheduled reminders are shown while the app is open.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The wall display keeps its screen on while the week board is shown (specs/09 "The
    // wall display"); every other register lets the device sleep as usual.
    FlutterMethodChannel(
      name: "wuselwall/kiosk", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    .setMethodCallHandler { call, result in
      if call.method == "keepScreenOn" {
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
