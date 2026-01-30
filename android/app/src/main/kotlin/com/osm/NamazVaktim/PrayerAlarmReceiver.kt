package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Bildirim alarmları için receiver.
 * Sessiz mod artık SilentModeReceiver tarafından yönetiliyor.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent) {
        val soundId = intent.getStringExtra("soundId") ?: "default"
        val title = intent.getStringExtra("title") ?: "Namaz Vaktim"
        val text = intent.getStringExtra("text") ?: "Namaz vakti"
        val req = intent.getIntExtra("requestCode", 0x900)

        Log.d("PrayerAlarmReceiver", "=== Alarm received ===")
        Log.d("PrayerAlarmReceiver", "soundId=$soundId, title=$title, text=$text, req=$req")

        val isSilent = soundId == "silent"
        val isDefault = soundId == "default"

		// Heads-up bildirimi göster
		if (!isSilent) {
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
					.setSmallIcon(R.mipmap.ic_launcher)
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
}


