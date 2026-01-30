//
//  TextOnlyWidget.swift
//  NamazVaktiWidgets
//
//  Text-only minimal widget for iOS (no background card)
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct TextOnlyEntry: TimelineEntry {
    let date: Date
    let prayerData: PrayerTimeData
    let textColorMode: Int
    let textScalePercent: Int
    let locale: String
}

// MARK: - Timeline Provider
struct TextOnlyProvider: TimelineProvider {
    func placeholder(in context: Context) -> TextOnlyEntry {
        TextOnlyEntry(
            date: Date(),
            prayerData: .placeholder,
            textColorMode: 0,
            textScalePercent: 100,
            locale: "tr"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TextOnlyEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TextOnlyEntry>) -> Void) {
        let currentDate = Date()
        
        // Create entries for every minute for smooth countdown
        var entries: [TextOnlyEntry] = []
        
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            var entry = createEntry()
            entry = TextOnlyEntry(
                date: entryDate,
                prayerData: entry.prayerData,
                textColorMode: entry.textColorMode,
                textScalePercent: entry.textScalePercent,
                locale: entry.locale
            )
            entries.append(entry)
        }
        
        // Refresh timeline after 1 hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func createEntry() -> TextOnlyEntry {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            return TextOnlyEntry(
                date: Date(),
                prayerData: .placeholder,
                textColorMode: 0,
                textScalePercent: 100,
                locale: "tr"
            )
        }
        
        let prayerData = PrayerTimeData.load()
        let textColorMode = defaults.integer(forKey: "flutter.nv_textonly_text_color_mode")
        let textScalePercent = defaults.integer(forKey: "flutter.nv_textonly_text_scale_pct")
        let locale = WidgetLocalization.load()
        
        return TextOnlyEntry(
            date: Date(),
            prayerData: prayerData,
            textColorMode: textColorMode,
            textScalePercent: textScalePercent > 0 ? textScalePercent : 100,
            locale: locale
        )
    }
}

// MARK: - Widget View
struct TextOnlyWidgetView: View {
    var entry: TextOnlyEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 2) {
            // Prayer name
            Text(entry.prayerData.prayerName)
                .font(.system(size: scaledFontSize(15), weight: .light))
                .foregroundColor(textColor.opacity(0.9))
                .lineLimit(1)
            
            // Countdown
            Text(entry.prayerData.formattedCountdown())
                .font(.system(size: scaledFontSize(18), weight: .bold, design: .rounded))
                .foregroundColor(textColor.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .containerBackground(for: .widget) {
            // Transparent background for text-only widget
            Color.clear
        }
    }
    
    private var textColor: Color {
        Color.textColor(for: entry.textColorMode, colorScheme: colorScheme)
    }
    
    private func scaledFontSize(_ baseSize: CGFloat) -> CGFloat {
        return baseSize * (CGFloat(entry.textScalePercent) / 100.0)
    }
}

// MARK: - Widget Configuration
struct TextOnlyWidget: Widget {
    let kind: String = "TextOnlyWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TextOnlyProvider()) { entry in
            TextOnlyWidgetView(entry: entry)
        }
        .configurationDisplayName("Sadece Metin")
        .description("Arkaplan olmadan minimal namaz vakti gösterimi.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    TextOnlyWidget()
} timeline: {
    TextOnlyEntry(
        date: Date(),
        prayerData: .placeholder,
        textColorMode: 0,
        textScalePercent: 100,
        locale: "tr"
    )
}
