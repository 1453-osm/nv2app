package com.osm.NamazVaktim

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MediaPlaybackService : Service() {
	private var mediaPlayer: MediaPlayer? = null
	// Medya kanalı kaldırıldı; foreground için varsayılan kanal kullanılacak
	private val channelId = NotificationChannels.DEFAULT_ID
	private val notificationId = 1001

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		if (intent?.action == "STOP") {
			stopPlayback()
			return START_NOT_STICKY
		}
		NotificationChannels.ensure(this)
		startInForeground(intent)
		startPlayback(intent)
		return START_STICKY
	}

	private fun startInForeground(intent: Intent?) {
		val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
		val stopIntent = Intent(this, MediaPlaybackService::class.java).apply { action = "STOP" }
		val stopPi = PendingIntent.getService(
			this,
			0x771,
			stopIntent,
			PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
		)
		val title = intent?.getStringExtra("title") ?: "Namaz Vaktim"
		val text = intent?.getStringExtra("text") ?: "Ezan/alarm çalıyor"
		val notif: Notification = NotificationCompat.Builder(this, channelId)
			.setContentTitle(title)
			.setContentText(text)
			.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
			.addAction(android.R.drawable.ic_media_pause, "Durdur", stopPi)
			.setOngoing(true)
			.build()
		startForeground(notificationId, notif)
	}

	private fun startPlayback(intent: Intent?) {
		stopPlayback()
        val soundId = intent?.getStringExtra("soundId") ?: "alarm"

		val resName = sanitizeToResourceName(soundId)
		val resId = resources.getIdentifier(resName, "raw", packageName)
        if (resId == 0) {
			// Fallback alarm sesi
			playResource("alarm")
		} else {
			mediaPlayer = MediaPlayer.create(this, resId)
			mediaPlayer?.setOnCompletionListener {
				stopPlayback()
			}
			mediaPlayer?.start()
		}
	}

	private fun playResource(name: String) {
		val resId = resources.getIdentifier(name, "raw", packageName)
		if (resId != 0) {
			mediaPlayer = MediaPlayer.create(this, resId)
			mediaPlayer?.setOnCompletionListener { stopPlayback() }
			mediaPlayer?.start()
		}
	}

	private fun stopPlayback() {
		try {
			mediaPlayer?.stop()
			mediaPlayer?.release()
		} catch (_: Exception) {}
		mediaPlayer = null
		stopForeground(true)
		stopSelf()
	}

	private fun sanitizeToResourceName(id: String): String {
		// raw kaynak isimleri sadece [a-z0-9_]
		return id.lowercase().replace("-", "_")
	}
}


