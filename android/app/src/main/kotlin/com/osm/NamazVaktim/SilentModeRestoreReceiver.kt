package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.PowerManager
import android.util.Log

class SilentModeRestoreReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent) {
		Log.d("SilentModeRestore", "=== Geri yükleme alarmı tetiklendi ===")
		
		// Wake lock al (Android 8.0+ için gerekli)
		val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
		val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SilentModeRestore::WakeLock")
		
		try {
			wakeLock.acquire(10 * 60 * 1000L /*10 dakika*/)
			Log.d("SilentModeRestore", "Wake lock alındı")
			
			val prayerId = intent.getStringExtra("prayerId") ?: "unknown"
			val durationMinutes = intent.getIntExtra("durationMinutes", -1)
			Log.d("SilentModeRestore", "prayerId=$prayerId, duration=$durationMinutes dk")
			
			Log.d("SilentModeRestore", "Önceki durum geri yükleniyor...")
			val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			val savedMode = prefs.getInt("nv_saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
			val savedMusicVolume = prefs.getInt("nv_saved_music_volume", -1)
			val savedNotificationVolume = prefs.getInt("nv_saved_notification_volume", -1)
			val savedRingVolume = prefs.getInt("nv_saved_ring_volume", -1)
			
			Log.d("SilentModeRestore", "Kaydedilen değerler:")
			Log.d("SilentModeRestore", "  - Ringer mode: $savedMode")
			Log.d("SilentModeRestore", "  - Music volume: $savedMusicVolume")
			Log.d("SilentModeRestore", "  - Notification volume: $savedNotificationVolume")
			Log.d("SilentModeRestore", "  - Ring volume: $savedRingVolume")
			
			val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

			// Ringer mode'u geri yükle
			try {
				am.ringerMode = savedMode
				val currentMode = am.ringerMode
				if (currentMode == savedMode) {
					Log.d("SilentModeRestore", "✓ Ringer mode başarıyla geri yüklendi: $currentMode")
				} else {
					Log.w("SilentModeRestore", "⚠ Ringer mode geri yüklenemedi. Beklenen: $savedMode, Mevcut: $currentMode")
				}
			} catch (e: Exception) {
				Log.e("SilentModeRestore", "Ringer mode geri yüklenemedi", e)
			}

			// Ses seviyelerini geri yükle
			try {
				if (savedMusicVolume >= 0) {
					val maxMusicVolume = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
					val volumeToRestore = savedMusicVolume.coerceIn(0, maxMusicVolume)
					am.setStreamVolume(AudioManager.STREAM_MUSIC, volumeToRestore, 0)
					Log.d("SilentModeRestore", "✓ Music volume geri yüklendi: $volumeToRestore (max: $maxMusicVolume)")
				} else {
					Log.w("SilentModeRestore", "Music volume kaydedilmemiş, atlanıyor")
				}
				
				if (savedNotificationVolume >= 0) {
					val maxNotificationVolume = am.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION)
					val volumeToRestore = savedNotificationVolume.coerceIn(0, maxNotificationVolume)
					am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, volumeToRestore, 0)
					Log.d("SilentModeRestore", "✓ Notification volume geri yüklendi: $volumeToRestore (max: $maxNotificationVolume)")
				} else {
					Log.w("SilentModeRestore", "Notification volume kaydedilmemiş, atlanıyor")
				}
				
				if (savedRingVolume >= 0) {
					val maxRingVolume = am.getStreamMaxVolume(AudioManager.STREAM_RING)
					val volumeToRestore = savedRingVolume.coerceIn(0, maxRingVolume)
					am.setStreamVolume(AudioManager.STREAM_RING, volumeToRestore, 0)
					Log.d("SilentModeRestore", "✓ Ring volume geri yüklendi: $volumeToRestore (max: $maxRingVolume)")
				} else {
					Log.w("SilentModeRestore", "Ring volume kaydedilmemiş, atlanıyor")
				}
			} catch (e: Exception) {
				Log.e("SilentModeRestore", "Ses seviyeleri geri yüklenemedi", e)
			}

			// Kaydedilen değerleri temizle
			prefs.edit()
				.remove("nv_saved_ringer_mode")
				.remove("nv_saved_music_volume")
				.remove("nv_saved_notification_volume")
				.remove("nv_saved_ring_volume")
				.apply()
			
			Log.d("SilentModeRestore", "✓ Geri yükleme tamamlandı ve kaydedilen değerler temizlendi")
		} catch (e: Exception) {
			Log.e("SilentModeRestore", "Geri yükleme hatası", e)
		} finally {
			// Wake lock'ı serbest bırak
			if (wakeLock.isHeld) {
				wakeLock.release()
				Log.d("SilentModeRestore", "Wake lock serbest bırakıldı")
			}
		}
	}
}

