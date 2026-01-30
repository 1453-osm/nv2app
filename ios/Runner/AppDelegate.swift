import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  /// App Group identifier for sharing data with widgets
  private let appGroupId = "group.com.osm.namazvaktim"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS 10+ için bildirim izinleri
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Setup MethodChannel for widget communication
    setupWidgetChannel()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Widget Channel Setup
  private func setupWidgetChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let widgetChannel = FlutterMethodChannel(
      name: "com.osm.namazvaktim/widgets",
      binaryMessenger: controller.binaryMessenger
    )
    
    widgetChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
        return
      }
      
      switch call.method {
      case "saveWidgetData":
        self.handleSaveWidgetData(call: call, result: result)
      case "updateSmallWidget", "updateCalendarWidget", "updateTextOnlyWidget", "reloadAllWidgets":
        self.reloadWidgets(result: result)
      case "savePrayerTimes":
        self.handleSavePrayerTimes(call: call, result: result)
      case "saveCalendarData":
        self.handleSaveCalendarData(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // MARK: - Widget Data Handlers
  private func handleSaveWidgetData(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: appGroupId) else {
      result(false)
      return
    }
    
    if let prayerName = args["nextPrayerName"] as? String {
      defaults.set(prayerName, forKey: "nv_next_prayer_name")
    }
    if let countdown = args["countdownText"] as? String {
      defaults.set(countdown, forKey: "nv_countdown_text")
    }
    if let epochMs = args["nextEpochMs"] as? Int64 {
      defaults.set(String(epochMs), forKey: "nv_next_epoch_ms")
    }
    if let themeColor = args["currentThemeColor"] as? Int {
      defaults.set(themeColor, forKey: "flutter.current_theme_color")
    }
    if let locale = args["locale"] as? String {
      defaults.set(locale, forKey: "flutter.nv_widget_locale")
    }
    
    defaults.synchronize()
    reloadWidgets(result: result)
  }
  
  private func handleSavePrayerTimes(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: appGroupId) else {
      result(false)
      return
    }
    
    // Save all prayer times
    if let fajr = args["fajr"] as? String { defaults.set(fajr, forKey: "flutter.nv_fajr") }
    if let sunrise = args["sunrise"] as? String { defaults.set(sunrise, forKey: "flutter.nv_sunrise") }
    if let dhuhr = args["dhuhr"] as? String { defaults.set(dhuhr, forKey: "flutter.nv_dhuhr") }
    if let asr = args["asr"] as? String { defaults.set(asr, forKey: "flutter.nv_asr") }
    if let maghrib = args["maghrib"] as? String { defaults.set(maghrib, forKey: "flutter.nv_maghrib") }
    if let isha = args["isha"] as? String { defaults.set(isha, forKey: "flutter.nv_isha") }
    if let todayIso = args["todayIso"] as? String { defaults.set(todayIso, forKey: "flutter.nv_today_date_iso") }
    
    defaults.synchronize()
    result(true)
  }
  
  private func handleSaveCalendarData(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: appGroupId) else {
      result(false)
      return
    }
    
    if let hijri = args["hijriDate"] as? String {
      defaults.set(hijri, forKey: "flutter.nv_calendar_hijri_date")
    }
    if let gregorian = args["gregorianDate"] as? String {
      defaults.set(gregorian, forKey: "flutter.nv_calendar_gregorian_date")
    }
    
    defaults.synchronize()
    reloadWidgets(result: result)
  }
  
  private func reloadWidgets(result: @escaping FlutterResult) {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
      result(true)
    } else {
      result(false)
    }
  }
  
  // iOS 10+ için foreground bildirimleri göstermek için
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }
}
