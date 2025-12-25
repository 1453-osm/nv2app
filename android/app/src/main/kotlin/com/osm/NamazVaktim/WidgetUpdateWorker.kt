package com.osm.NamazVaktim

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class WidgetUpdateWorker(appContext: Context, workerParams: WorkerParameters) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        return try {
            val context = applicationContext
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
            if (ids != null && ids.isNotEmpty()) {
                ids.forEach { id ->
                    SmallPrayerWidgetProvider.updateAppWidget(context, mgr, id)
                }
            }
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}


