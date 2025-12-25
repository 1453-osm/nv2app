package com.osm.NamazVaktim

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class ThemeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_CONFIGURATION_CHANGED ||
            action == "android.app.action.UI_MODE_CHANGED") {
            // Hafif ve güvenli: ağır RemoteViews güncellemelerini WorkManager'a devret
            val pending = goAsync()
            val appContext = context.applicationContext
            try {
                // 1) Anında güncelle (kullanıcı gecikme görmesin)
                try {
                    val mgr = AppWidgetManager.getInstance(appContext)
                    val ids = mgr.getAppWidgetIds(ComponentName(appContext, SmallPrayerWidgetProvider::class.java))
                    if (ids != null && ids.isNotEmpty()) {
                        ids.forEach { id -> SmallPrayerWidgetProvider.updateAppWidget(appContext, mgr, id) }
                    }
                } catch (_: Exception) { }

                enqueueWidgetRefreshWork(appContext, initialDelayMs = 150L)
                // Tema değişimine anında tepki veren hafif yenileme
                SmallPrayerWidgetProvider.requestThemeAwareRefresh(appContext)
            } finally {
                // Broadcast işleme bitti
                pending.finish()
            }
        }
    }

    private fun enqueueWidgetRefreshWork(context: Context, initialDelayMs: Long = 0L) {
        val work = OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
            .setInitialDelay(initialDelayMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .addTag(UNIQUE_THEME_REFRESH_TAG)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(UNIQUE_THEME_REFRESH_TAG, ExistingWorkPolicy.REPLACE, work)
    }

    companion object {
        private const val UNIQUE_THEME_REFRESH_TAG = "widget-theme-refresh"
    }
}


