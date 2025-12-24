import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Plugin kaydını güvenli bir şekilde yap
    // AltStore ile kurulumda Swift/Objective-C bridge sorunlarını önlemek için
    // SafePluginRegistrant kullanıyoruz
    SafePluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
