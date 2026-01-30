//
//  CalendarWidget.swift
//  NamazVaktiWidgets
//
//  Hijri and Gregorian calendar widget for iOS
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let calendarData: CalendarData
    let settings: WidgetSettings
}

// MARK: - Timeline Provider
struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(
            date: Date(),
            calendarData: .placeholder,
            settings: .defaultSettings
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let entry = CalendarWidgetEntry(
            date: Date(),
            calendarData: CalendarData.load(),
            settings: WidgetSettings.loadForCalendarWidget()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let currentDate = Date()
        let calendarData = CalendarData.load()
        let settings = WidgetSettings.loadForCalendarWidget()
        
        // Calendar widget only needs to update once a day
        let entry = CalendarWidgetEntry(
            date: currentDate,
            calendarData: calendarData,
            settings: settings
        )
        
        // Refresh at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget View
struct CalendarWidgetView: View {
    var entry: CalendarWidgetEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
        // Use a subtle green gradient for calendar
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x588065).opacity(0.25),
                Color(hex: 0x588065).opacity(0.08),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: entry.settings.cornerRadius))
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 6) {
            // Hijri date (if mode allows)
            if entry.calendarData.displayMode != 2 {
                Text(entry.calendarData.hijriDate)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // Gregorian date (if mode allows)
            if entry.calendarData.displayMode != 1 {
                Text(entry.calendarData.gregorianDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding()
    }
    
    private var textColor: Color {
        Color.textColor(for: entry.settings.textColorMode, colorScheme: colorScheme)
    }
}

// MARK: - Widget Configuration
struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Takvim")
        .description("Hicri ve Miladi tarihi gösterir.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CalendarWidget()
} timeline: {
    CalendarWidgetEntry(
        date: Date(),
        calendarData: .placeholder,
        settings: .defaultSettings
    )
}
