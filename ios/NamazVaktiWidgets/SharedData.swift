//
//  SharedData.swift
//  NamazVaktiWidgets
//
//  Shared data models and utilities for widgets
//

import Foundation
import WidgetKit

// MARK: - App Group Identifier
struct AppGroupConfig {
    /// App Group identifier - Must match the one configured in Xcode
    static let identifier = "group.com.osm.namazvaktim"
    
    /// UserDefaults for App Group
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

// MARK: - Prayer Time Data
struct PrayerTimeData {
    let prayerName: String
    let countdownText: String
    let nextEpochMs: Int64
    let themeColor: Int
    
    static func load() -> PrayerTimeData {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return PrayerTimeData.placeholder
        }
        
        let prayerName = defaults.string(forKey: "nv_next_prayer_name") ?? "Yükleniyor"
        let countdownText = defaults.string(forKey: "nv_countdown_text") ?? "--:--"
        let nextEpochStr = defaults.string(forKey: "nv_next_epoch_ms") ?? "0"
        let nextEpochMs = Int64(nextEpochStr) ?? 0
        let themeColor = defaults.integer(forKey: "flutter.current_theme_color")
        
        return PrayerTimeData(
            prayerName: prayerName,
            countdownText: countdownText,
            nextEpochMs: nextEpochMs,
            themeColor: themeColor
        )
    }
    
    static var placeholder: PrayerTimeData {
        PrayerTimeData(
            prayerName: "Öğle",
            countdownText: "02:45:30",
            nextEpochMs: 0,
            themeColor: 0xFF588065
        )
    }
    
    /// Calculate remaining time from epoch
    func remainingTime() -> TimeInterval {
        let now = Date().timeIntervalSince1970 * 1000
        let remaining = Double(nextEpochMs) - now
        return max(0, remaining / 1000)
    }
    
    /// Format remaining time as HH:MM:SS or MM:SS
    func formattedCountdown() -> String {
        let remaining = remainingTime()
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Calendar Data
struct CalendarData {
    let hijriDate: String
    let gregorianDate: String
    let displayMode: Int // 0: Both, 1: Hijri only, 2: Gregorian only
    
    static func load() -> CalendarData {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return CalendarData.placeholder
        }
        
        let hijri = defaults.string(forKey: "flutter.nv_calendar_hijri_date") ?? "Yükleniyor"
        let gregorian = defaults.string(forKey: "flutter.nv_calendar_gregorian_date") ?? "--"
        let mode = defaults.integer(forKey: "flutter.nv_calendar_display_mode")
        
        return CalendarData(
            hijriDate: hijri,
            gregorianDate: gregorian,
            displayMode: mode
        )
    }
    
    static var placeholder: CalendarData {
        CalendarData(
            hijriDate: "1 Recep 1446",
            gregorianDate: "27 Ocak 2026",
            displayMode: 0
        )
    }
}

// MARK: - Widget Settings
struct WidgetSettings {
    let cardOpacity: Double
    let gradientEnabled: Bool
    let cornerRadius: CGFloat
    let textColorMode: Int // 0: System, 1: Dark, 2: Light
    let backgroundColorMode: Int // 0: System, 1: Light, 2: Dark
    
    static func loadForSmallWidget() -> WidgetSettings {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return WidgetSettings.defaultSettings
        }
        
        let alpha = defaults.integer(forKey: "flutter.nv_card_alpha")
        let opacity = alpha > 0 ? Double(alpha) / 255.0 : 0.8
        let gradient = defaults.object(forKey: "flutter.nv_gradient_on") as? Bool ?? true
        let radius = defaults.integer(forKey: "flutter.nv_card_radius_dp")
        let cornerRadius = radius > 0 ? CGFloat(radius) : 20.0
        let textMode = defaults.integer(forKey: "flutter.nv_text_color_mode")
        let bgMode = defaults.integer(forKey: "flutter.nv_bg_color_mode")
        
        return WidgetSettings(
            cardOpacity: opacity,
            gradientEnabled: gradient,
            cornerRadius: cornerRadius,
            textColorMode: textMode,
            backgroundColorMode: bgMode
        )
    }
    
    static func loadForCalendarWidget() -> WidgetSettings {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return WidgetSettings.defaultSettings
        }
        
        let alpha = defaults.integer(forKey: "flutter.nv_calendar_card_alpha")
        let opacity = alpha > 0 ? Double(alpha) / 255.0 : 0.8
        let gradient = defaults.object(forKey: "flutter.nv_calendar_gradient_on") as? Bool ?? true
        let radius = defaults.integer(forKey: "flutter.nv_calendar_card_radius_dp")
        let cornerRadius = radius > 0 ? CGFloat(radius) : 20.0
        let textMode = defaults.integer(forKey: "flutter.nv_calendar_text_color_mode")
        let bgMode = defaults.integer(forKey: "flutter.nv_calendar_bg_color_mode")
        
        return WidgetSettings(
            cardOpacity: opacity,
            gradientEnabled: gradient,
            cornerRadius: cornerRadius,
            textColorMode: textMode,
            backgroundColorMode: bgMode
        )
    }
    
    static var defaultSettings: WidgetSettings {
        WidgetSettings(
            cardOpacity: 0.8,
            gradientEnabled: true,
            cornerRadius: 20.0,
            textColorMode: 0,
            backgroundColorMode: 0
        )
    }
}

// MARK: - Localization Helper
struct WidgetLocalization {
    static func load() -> String {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return "tr"
        }
        return defaults.string(forKey: "flutter.nv_widget_locale") ?? "tr"
    }
    
    /// Localized prayer names
    static func localizedPrayerName(_ englishName: String, locale: String) -> String {
        let translations: [String: [String: String]] = [
            "tr": [
                "Fajr": "İmsak",
                "Sunrise": "Güneş",
                "Dhuhr": "Öğle",
                "Asr": "İkindi",
                "Maghrib": "Akşam",
                "Isha": "Yatsı"
            ],
            "en": [
                "Fajr": "Fajr",
                "Sunrise": "Sunrise",
                "Dhuhr": "Dhuhr",
                "Asr": "Asr",
                "Maghrib": "Maghrib",
                "Isha": "Isha"
            ],
            "ar": [
                "Fajr": "الفجر",
                "Sunrise": "الشروق",
                "Dhuhr": "الظهر",
                "Asr": "العصر",
                "Maghrib": "المغرب",
                "Isha": "العشاء"
            ],
            "de": [
                "Fajr": "Fadschr",
                "Sunrise": "Sonnenaufgang",
                "Dhuhr": "Dhuhr",
                "Asr": "Asr",
                "Maghrib": "Maghrib",
                "Isha": "Ischa"
            ]
        ]
        
        let langDict = translations[locale] ?? translations["tr"]!
        return langDict[englishName] ?? englishName
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
    
    /// Theme color from Flutter app
    static func themeColor(from value: Int) -> Color {
        if value == 0 {
            // Default theme color
            return Color(hex: 0x588065)
        }
        // Extract RGB from ARGB int
        let rgb = value & 0x00FFFFFF
        return Color(hex: rgb)
    }
    
    /// Dynamic text color based on mode
    static func textColor(for mode: Int, colorScheme: ColorScheme) -> Color {
        switch mode {
        case 1: // Dark
            return .black
        case 2: // Light
            return .white
        default: // System
            return colorScheme == .dark ? .white : .black
        }
    }
    
    /// Dynamic background color based on mode
    static func backgroundColor(for mode: Int, colorScheme: ColorScheme, opacity: Double) -> Color {
        switch mode {
        case 1: // Light
            return Color.white.opacity(opacity)
        case 2: // Dark
            return Color.black.opacity(opacity)
        default: // System
            return colorScheme == .dark ? Color.black.opacity(opacity) : Color.white.opacity(opacity)
        }
    }
}
