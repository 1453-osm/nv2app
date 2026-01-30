package com.osm.NamazVaktim

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.content.res.Configuration
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager

class MainActivity : FlutterActivity() {
    private val channelName = "com.osm.namazvaktim/widgets"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Kanal güvenliği (Android O+): app başında kanal varlığını garanti et
        NotificationChannels.ensure(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPinSmallWidget" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val provider = ComponentName(this, SmallPrayerWidgetProvider::class.java)
                        if (mgr.isRequestPinAppWidgetSupported) {
                            mgr.requestPinAppWidget(provider, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isSmallWidgetPinned" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, SmallPrayerWidgetProvider::class.java)
                    val ids = mgr.getAppWidgetIds(provider)
                    result.success(ids != null && ids.isNotEmpty())
                }
                "requestPinTextWidget" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val provider = ComponentName(this, TextOnlyWidgetProvider::class.java)
                        if (mgr.isRequestPinAppWidgetSupported) {
                            mgr.requestPinAppWidget(provider, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isTextWidgetPinned" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, TextOnlyWidgetProvider::class.java)
                    val ids = mgr.getAppWidgetIds(provider)
                    result.success(ids != null && ids.isNotEmpty())
                }
                "requestPinCalendarWidget" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val provider = ComponentName(this, CalendarWidgetProvider::class.java)
                        if (mgr.isRequestPinAppWidgetSupported) {
                            mgr.requestPinAppWidget(provider, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isCalendarWidgetPinned" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, CalendarWidgetProvider::class.java)
                    val ids = mgr.getAppWidgetIds(provider)
                    result.success(ids != null && ids.isNotEmpty())
                }
                "updateCalendarWidget" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, CalendarWidgetProvider::class.java)
                    val ids = mgr.getAppWidgetIds(provider)
                    if (ids != null && ids.isNotEmpty()) {
                        ids.forEach { id ->
                            CalendarWidgetProvider.updateAppWidget(this, mgr, id)
                        }
                    }
                    result.success(true)
                }
                "updateSmallWidget" -> {
                    val mgr = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, SmallPrayerWidgetProvider::class.java)
                    val ids = mgr.getAppWidgetIds(provider)
                    if (ids != null && ids.isNotEmpty()) {
                        ids.forEach { id ->
                            SmallPrayerWidgetProvider.updateAppWidget(this, mgr, id)
                        }
                    }
                    // Ayrıca metin-only widget'ı da güncelle
                    val textProvider = ComponentName(this, TextOnlyWidgetProvider::class.java)
                    val textIds = mgr.getAppWidgetIds(textProvider)
                    if (textIds != null && textIds.isNotEmpty()) {
                        textIds.forEach { id ->
                            TextOnlyWidgetProvider.updateAppWidget(this, mgr, id)
                        }
                    }
                    // Native planlayıcıyı tetikle (Flutter güncel vakitleri yazdıktan sonra kullanılabilir)
                    try { PrayerScheduler.scheduleAll(this) } catch (_: Exception) {}
                    result.success(true)
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
                        if (!alarmManager.canScheduleExactAlarms()) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isExactAlarmAllowed" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "scheduleExactAlarm" -> {
                    try {
                        val epochMillis = (call.argument<Number>("epochMillis")?.toLong()) ?: 0L
                        val title = call.argument<String>("title") ?: "Namaz Vaktim"
                        val text = call.argument<String>("text") ?: "Namaz vakti"
                        val soundId = call.argument<String>("soundId") ?: "alarm"
                        val requestCode = call.argument<Int>("requestCode") ?: 0x900
                        val notificationId = call.argument<String>("notificationId")

                        val am = getSystemService(ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
                            putExtra("title", title)
                            putExtra("text", text)
                            putExtra("soundId", soundId)
                            putExtra("requestCode", requestCode)
                            if (notificationId != null) {
                                putExtra("notificationId", notificationId)
                            }
                        }
                        val pi = PendingIntent.getBroadcast(
                            this,
                            requestCode,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        } else {
                            am.setExact(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "cancelExactAlarm" -> {
                    try {
                        val requestCode = call.argument<Int>("requestCode") ?: 0x900
                        val am = getSystemService(ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, PrayerAlarmReceiver::class.java)
                        val pi = PendingIntent.getBroadcast(
                            this,
                            requestCode,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        am.cancel(pi)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    val pkg = packageName
                    val ignoring = pm.isIgnoringBatteryOptimizations(pkg)
                    result.success(ignoring)
                }
                "getLocalTimeZone" -> {
                    try {
                        val tz = java.util.TimeZone.getDefault().id
                        result.success(tz)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = android.net.Uri.parse("package:" + packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "deleteNotificationChannel" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val channelId = call.argument<String>("channelId")
                            if (!channelId.isNullOrEmpty()) {
                                val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                mgr.deleteNotificationChannel(channelId)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isNotificationPolicyAccessGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(notificationManager.isNotificationPolicyAccessGranted)
                    } else {
                        result.success(true) // Android M öncesi için her zaman true
                    }
                }
                "requestNotificationPolicyAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        if (!notificationManager.isNotificationPolicyAccessGranted) {
                            val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "setSilentMode" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        
                        if (enabled) {
                            // Mevcut ringer mode'u kaydet
                            val currentMode = am.ringerMode
                            prefs.edit().putInt("nv_saved_ringer_mode", currentMode).apply()
                            
                            // Sessiz moda al
                            am.ringerMode = AudioManager.RINGER_MODE_SILENT
                            result.success(true)
                        } else {
                            // Kaydedilmiş ringer mode'u geri yükle
                            val savedMode = prefs.getInt("nv_saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
                            am.ringerMode = savedMode
                            prefs.edit().remove("nv_saved_ringer_mode").apply()
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "scheduleSilentModeRestore" -> {
                    try {
                        val minutes = call.argument<Int>("minutes") ?: 15
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val cal = java.util.Calendar.getInstance().apply {
                            add(java.util.Calendar.MINUTE, minutes)
                        }
                        val intent = Intent(this, SilentModeRestoreReceiver::class.java)
                        val pi = PendingIntent.getBroadcast(
                            this,
                            0x800,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
                        } else {
                            am.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "cancelSilentModeRestore" -> {
                    try {
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, SilentModeRestoreReceiver::class.java)
                        val pi = PendingIntent.getBroadcast(
                            this,
                            0x800,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        am.cancel(pi)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "scheduleSilentModeAlarm" -> {
                    // Sessiz mod için özel alarm kur
                    try {
                        val epochMillis = (call.argument<Number>("epochMillis")?.toLong()) ?: 0L
                        val durationMinutes = call.argument<Int>("durationMinutes") ?: 15
                        val prayerId = call.argument<String>("prayerId") ?: "unknown"
                        val requestCode = call.argument<Int>("requestCode") ?: 0x600

                        android.util.Log.d("MainActivity", "Sessiz mod alarmı kuruluyor: prayerId=$prayerId, epoch=$epochMillis, duration=$durationMinutes")

                        val am = getSystemService(ALARM_SERVICE) as AlarmManager
                        val intent = Intent(this, SilentModeReceiver::class.java).apply {
                            putExtra("durationMinutes", durationMinutes)
                            putExtra("prayerId", prayerId)
                        }
                        val pi = PendingIntent.getBroadcast(
                            this,
                            requestCode,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        } else {
                            am.setExact(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                        }

                        android.util.Log.d("MainActivity", "Sessiz mod alarmı kuruldu!")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Sessiz mod alarmı kurulamadı", e)
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Heads-up bildirime tıklanıp uygulamaya dönüldüğünde alarmı durdur
        if (intent.getBooleanExtra("stopAlarmOnOpen", false)) {
            try { stopService(Intent(this, MediaPlaybackService::class.java)) } catch (_: Exception) {}
            // Ayrıca heads-up id'sini de iptal etmeye çalış
            val req = intent.getIntExtra("requestCode", 0x900)
            try {
                val mgr = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                mgr.cancel(req)
            } catch (_: Exception) {}
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Sistem tema değişimi dahil tüm config değişimlerinde widget'i hemen güncelle
        val mgr = AppWidgetManager.getInstance(this)
        val provider = ComponentName(this, SmallPrayerWidgetProvider::class.java)
        val ids = mgr.getAppWidgetIds(provider)
        if (ids != null && ids.isNotEmpty()) {
            ids.forEach { id ->
                SmallPrayerWidgetProvider.updateAppWidget(this, mgr, id)
            }
        }
    }
}