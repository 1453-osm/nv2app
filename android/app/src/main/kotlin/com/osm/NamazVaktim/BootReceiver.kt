package com.osm.NamazVaktim

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_BOOT_COMPLETED == intent.action) {
            NotificationChannels.ensure(context)
            // UfukMarmara mantığı: boot sonrasında dakika bazlı inexact repeating alarmı yeniden kur
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = PendingIntent.getBroadcast(
                context,
                0x856,
                Intent(context, WidgetUpdateReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis(),
                30_000L,
                pi
            )

            // İlk güncelleme için bir kere tetikle
            context.sendBroadcast(Intent(context, WidgetUpdateReceiver::class.java))
        }
    }
}


