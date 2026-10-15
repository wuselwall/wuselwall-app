import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // flutter_local_notifications (README, "iOS setup"): the delegate must be set so
    // scheduled reminders are shown while the app is open.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // The wall display keeps its screen on while the week board is shown (specs/09 "The
    // wall display"); every other register lets the device sleep as usual.
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "wuselwall/kiosk", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          if call.method == "keepScreenOn" {
            application.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
            result(nil)
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
