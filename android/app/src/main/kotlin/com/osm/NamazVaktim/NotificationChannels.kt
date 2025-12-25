package com.osm.NamazVaktim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build

object NotificationChannels {
	const val DEFAULT_ID = "nv_prayer_default_v2"
	const val DEFAULT_NAME = "Namaz Bildirimleri"
	const val SILENT_ID = "nv_prayer_silent_v2"
	const val SILENT_NAME = "Sessiz Namaz Bildirimleri"
	// Flutter tarafındaki _customSoundIds ile hizalı tutulur
	private val customSounds = listOf(
		"alarm", "bird", "soft", "hard", "adhanarabic", "adhan", "sela"
	)

	fun ensure(context: Context) {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
		val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

		fun create(channel: NotificationChannel) {
			try {
				mgr.createNotificationChannel(channel)
			} catch (_: Exception) {}
		}

		// Varsayılan (normal görünürlük)
		create(NotificationChannel(
			DEFAULT_ID,
			DEFAULT_NAME,
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "Namaz vakitleri için bildirimler (sistem varsayılan sesi)"
		})

		// Sessiz (ses yok; normal görünürlük, titreşim açık)
		create(NotificationChannel(
			SILENT_ID,
			SILENT_NAME,
			NotificationManager.IMPORTANCE_DEFAULT
		).apply {
			description = "Namaz bildirimleri (sessiz)"
			setSound(null, null)
			enableVibration(true)
			enableLights(false)
		})

		// Özel ses kanalları
		val attrs = AudioAttributes.Builder()
			.setUsage(AudioAttributes.USAGE_NOTIFICATION)
			.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
			.build()
		for (sid in customSounds) {
			val resName = sid.lowercase()
			val resId = context.resources.getIdentifier(resName, "raw", context.packageName)
			if (resId == 0) continue
			create(NotificationChannel(
				"nv_prayer_sound_${sid}_v2",
				"Namaz Bildirimi (${sid})",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "Özel ses: $sid"
				setSound(android.net.Uri.parse("android.resource://${context.packageName}/$resId"), attrs)
			})
		}
	}
}


