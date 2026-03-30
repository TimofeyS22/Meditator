import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    SiriShortcuts.donateAll()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let route = userActivity.userInfo?["route"] as? String {
      if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: "com.meditatorapp.meditator/deeplink",
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("navigate", arguments: route)
      }
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
