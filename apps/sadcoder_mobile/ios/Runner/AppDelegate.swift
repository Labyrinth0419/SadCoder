import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var realtimeAudioBridge: RealtimeAudioBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let bridge = RealtimeAudioBridge()
      bridge.register(with: controller.binaryMessenger)
      realtimeAudioBridge = bridge
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
