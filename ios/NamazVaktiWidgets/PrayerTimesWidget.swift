//
//  PrayerTimesWidget.swift
//  NamazVaktiWidgets
//
//  Prayer times countdown widget for iOS
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct PrayerTimesEntry: TimelineEntry {
    let date: Date
    let prayerData: PrayerTimeData
    let settings: WidgetSettings
    let locale: String
}

// MARK: - Timeline Provider
struct PrayerTimesProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerTimesEntry {
        PrayerTimesEntry(
            date: Date(),
            prayerData: .placeholder,
            settings: .defaultSettings,
            locale: "tr"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
        let entry = PrayerTimesEntry(
            date: Date(),
            prayerData: PrayerTimeData.load(),
            settings: WidgetSettings.loadForSmallWidget(),
            locale: WidgetLocalization.load()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
        let currentDate = Date()
        let prayerData = PrayerTimeData.load()
        let settings = WidgetSettings.loadForSmallWidget()
        let locale = WidgetLocalization.load()
        
        // Create entries for every minute for smooth countdown
        var entries: [PrayerTimesEntry] = []
        
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = PrayerTimesEntry(
                date: entryDate,
                prayerData: prayerData,
                settings: settings,
                locale: locale
            )
            entries.append(entry)
        }
        
        // Refresh timeline after 1 hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct PrayerTimesWidgetView: View {
    var entry: PrayerTimesEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                
                // Gradient overlay
                if entry.settings.gradientEnabled {
                    gradientOverlay
                }
                
                // Content
                contentView
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: entry.settings.cornerRadius)
            .fill(Color.backgroundColor(
                for: entry.settings.backgroundColorMode,
                colorScheme: colorScheme,
                opacity: entry.settings.cardOpacity
            ))
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
        let themeColor = Color.themeColor(from: entry.prayerData.themeColor)
        
        LinearGradient(
            gradient: Gradient(colors: [
                themeColor.opacity(0.3),
                themeColor.opacity(0.1),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: entry.settings.cornerRadius))
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 4) {
            // Prayer name
            Text(entry.prayerData.prayerName)
                .font(.system(size: family == .systemSmall ? 15 : 17, weight: .light))
                .foregroundColor(textColor.opacity(0.9))
                .lineLimit(1)
            
            // Countdown
            Text(entry.prayerData.formattedCountdown())
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if family == .systemMedium {
                // Show additional info on medium widget
                Text(formattedNextPrayerTime)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(textColor.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding()
    }
    
    private var textColor: Color {
        Color.textColor(for: entry.settings.textColorMode, colorScheme: colorScheme)
    }
    
    private var formattedNextPrayerTime: String {
        if entry.prayerData.nextEpochMs > 0 {
            let date = Date(timeIntervalSince1970: Double(entry.prayerData.nextEpochMs) / 1000)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return "--:--"
    }
}

// MARK: - Widget Configuration
struct PrayerTimesWidget: Widget {
    let kind: String = "PrayerTimesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimesProvider()) { entry in
            PrayerTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("Namaz Vakti")
        .description("Sonraki namaz vaktine kalan süreyi gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    PrayerTimesWidget()
} timeline: {
    PrayerTimesEntry(
        date: Date(),
        prayerData: .placeholder,
        settings: .defaultSettings,
        locale: "tr"
    )
}

#Preview(as: .systemMedium) {
    PrayerTimesWidget()
} timeline: {
    PrayerTimesEntry(
        date: Date(),
        prayerData: .placeholder,
        settings: .defaultSettings,
        locale: "tr"
    )
}
