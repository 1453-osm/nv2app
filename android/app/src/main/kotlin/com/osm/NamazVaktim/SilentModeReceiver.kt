package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import android.util.Log

/**
 * Sadece sessiz mod için özel receiver.
 * Namaz vakti girdiğinde telefonu sessiz moda alır.
 */
class SilentModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SilentModeReceiver", "=== Sessiz mod alarmı tetiklendi ===")

        val durationMinutes = intent.getIntExtra("durationMinutes", 15)
        val prayerId = intent.getStringExtra("prayerId") ?: "unknown"

        Log.d("SilentModeReceiver", "prayerId=$prayerId, duration=$durationMinutes dk")

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

            // Mevcut durumu kaydet
            val currentRingerMode = audioManager.ringerMode
            prefs.edit().putInt("nv_saved_ringer_mode", currentRingerMode).apply()
            Log.d("SilentModeReceiver", "Mevcut ringer mode kaydedildi: $currentRingerMode")

            // Mevcut ses seviyelerini kaydet (geri yükleme için)
            val currentMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val currentNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            val currentRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            prefs.edit()
                .putInt("nv_saved_music_volume", currentMusicVolume)
                .putInt("nv_saved_notification_volume", currentNotificationVolume)
                .putInt("nv_saved_ring_volume", currentRingVolume)
                .apply()
            Log.d("SilentModeReceiver", "Mevcut ses seviyeleri kaydedildi: music=$currentMusicVolume, notification=$currentNotificationVolume, ring=$currentRingVolume")

            var silentModeSet = false

            // Normal sessiz moda geç (DND yerine)
            try {
                // Ringer mode'u sessize al
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d("SilentModeReceiver", "✓ Ringer mode SILENT yapıldı")
                
                // Ses seviyelerini sıfırla (tüm sesleri kapat)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_RING, 0, 0)
                Log.d("SilentModeReceiver", "✓ Tüm ses seviyeleri kapatıldı")
                
                silentModeSet = true
            } catch (e: Exception) {
                Log.e("SilentModeReceiver", "Sessiz mod ayarlanamadı", e)
            }

            // Geri alma alarmı kur
            if (silentModeSet) {
                try {
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val restoreIntent = Intent(context, SilentModeRestoreReceiver::class.java).apply {
                        putExtra("prayerId", prayerId)
                        putExtra("durationMinutes", durationMinutes)
                    }
                    val requestCode = 0x700 + (prayerId.hashCode() and 0xFF)
                    
                    val restorePi = PendingIntent.getBroadcast(
                        context,
                        requestCode,
                        restoreIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val restoreTime = System.currentTimeMillis() + (durationMinutes * 60 * 1000L)
                    val restoreDateTime = java.util.Date(restoreTime)
                    
                    Log.d("SilentModeReceiver", "Geri alma alarmı kuruluyor:")
                    Log.d("SilentModeReceiver", "  - Request code: $requestCode")
                    Log.d("SilentModeReceiver", "  - Süre: $durationMinutes dakika")
                    Log.d("SilentModeReceiver", "  - Zaman: $restoreDateTime")
                    Log.d("SilentModeReceiver", "  - Epoch: $restoreTime")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, restoreTime, restorePi)
                        Log.d("SilentModeReceiver", "✓ setExactAndAllowWhileIdle kullanıldı (Android 12+)")
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, restoreTime, restorePi)
                        Log.d("SilentModeReceiver", "✓ setExact kullanıldı (Android 6.0+)")
                    } else {
                        alarmManager.set(AlarmManager.RTC_WAKEUP, restoreTime, restorePi)
                        Log.d("SilentModeReceiver", "✓ set kullanıldı (Android < 6.0)")
                    }

                    Log.d("SilentModeReceiver", "✓ Geri alma alarmı başarıyla kuruldu: $durationMinutes dk sonra ($restoreDateTime)")
                } catch (e: Exception) {
                    Log.e("SilentModeReceiver", "Geri alma alarmı kurulamadı!", e)
                }
            }

        } catch (e: Exception) {
            Log.e("SilentModeReceiver", "Sessiz mod hatası", e)
        }
    }
}
