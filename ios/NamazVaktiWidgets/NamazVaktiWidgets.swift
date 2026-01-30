//
//  NamazVaktiWidgets.swift
//  NamazVaktiWidgets
//
//  Created for Namaz Vakti iOS Widgets
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle
@main
struct NamazVaktiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        CalendarWidget()
        TextOnlyWidget()
    }
}
