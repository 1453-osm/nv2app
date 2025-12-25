package com.osm.NamazVaktim

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Boot veya zaman değişimlerinde kanalları garanti et ve (opsiyonel) namaz alarmlarını tazele
        NotificationChannels.ensure(context)
        val mgr = AppWidgetManager.getInstance(context)
        val idsSmall = mgr.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
        if (idsSmall != null && idsSmall.isNotEmpty()) {
            idsSmall.forEach { id -> SmallPrayerWidgetProvider.updateAppWidget(context, mgr, id) }
        }

        val idsText = mgr.getAppWidgetIds(ComponentName(context, TextOnlyWidgetProvider::class.java))
        if (idsText != null && idsText.isNotEmpty()) {
            idsText.forEach { id -> TextOnlyWidgetProvider.updateAppWidget(context, mgr, id) }
        }
    }
}


