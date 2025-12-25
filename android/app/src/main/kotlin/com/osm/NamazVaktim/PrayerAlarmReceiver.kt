package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerAlarmReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent) {
        val soundId = intent.getStringExtra("soundId") ?: "default"
        val title = intent.getStringExtra("title") ?: "Namaz Vaktim"
        val text = intent.getStringExtra("text") ?: "Namaz vakti"
        val req = intent.getIntExtra("requestCode", 0x900)

        // Kanal bazlı normal bildirim; uzun ezanlar için foreground servis kaldırıldı
        val isSilent = soundId == "silent"
        val isDefault = soundId == "default"

		// Heads-up bildirimi
		try {
			NotificationChannels.ensure(context)
			val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
			val dismissIntent = Intent(context, StopAlarmReceiver::class.java).apply { putExtra("requestCode", req) }
			val dismissPi = android.app.PendingIntent.getBroadcast(context, req, dismissIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
			val openIntent = Intent(context, MainActivity::class.java).apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
				putExtra("stopAlarmOnOpen", true)
				putExtra("requestCode", req)
			}
			val openPi = android.app.PendingIntent.getActivity(context, req, openIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
            // Kanal seçim (NotificationChannels ile hizalı _v2 id'leri):
            // default -> DEFAULT_ID (sesli),
            // silent -> SILENT_ID (sessiz),
            // diğer sesler -> nv_prayer_sound_<id>_v2
            val channelId = when {
                isDefault -> NotificationChannels.DEFAULT_ID
                isSilent -> NotificationChannels.SILENT_ID
                else -> "nv_prayer_sound_${soundId.lowercase()}_v2"
            }
            val heads = androidx.core.app.NotificationCompat.Builder(context, channelId)
				.setContentTitle(title)
				.setContentText(text)
				.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
				.setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
				.setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
				.setAutoCancel(true)
				.setContentIntent(openPi)
				.setDeleteIntent(dismissPi)
				.build()
			mgr.notify(req, heads)
		} catch (_: Exception) {}
	}
}


