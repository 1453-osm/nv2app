package com.osm.NamazVaktim

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import kotlin.math.roundToInt

class TextOnlyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleRepeatingUpdate(context)
        scheduleNextMinuteTick(context)
    }

    override fun onEnabled(context: Context) {
        scheduleRepeatingUpdate(context)
        scheduleNextMinuteTick(context)
    }

    override fun onDisabled(context: Context) {
        cancelRepeatingUpdate(context)
        // Exact tetik iptali
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = PendingIntent.getBroadcast(
            context,
            UPDATE_REQ_CODE + 1,
            Intent(context, TextOnlyWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_UPDATE_MINUTE,
            Intent.ACTION_USER_PRESENT,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_CONFIGURATION_CHANGED,
            "android.app.action.UI_MODE_CHANGED" -> {
                if (shouldThrottle()) return
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, TextOnlyWidgetProvider::class.java))
                if (ids != null && ids.isNotEmpty()) {
                    ids.forEach { updateAppWidget(context, mgr, it) }

                }
                if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
                    intent.action == Intent.ACTION_TIME_CHANGED ||
                    intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
                    intent.action == Intent.ACTION_DATE_CHANGED) {
                    scheduleRepeatingUpdate(context)
                    scheduleNextMinuteTick(context)
                }
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun scheduleRepeatingUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetUpdateReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            UPDATE_REQ_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Yedek periyodik tetik: 1 dakika (inexact)
        alarmManager.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 60_000L,
            60_000L,
            pending
        )
    }

    private fun cancelRepeatingUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetUpdateReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            UPDATE_REQ_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }

    companion object {
        private const val ACTION_UPDATE_MINUTE = "com.osm.NamazVaktim.UPDATE_TEXT_WIDGET"
        private const val UPDATE_REQ_CODE = 0x857
        private var lastReceiveAtElapsed: Long = 0L
        private fun shouldThrottle(): Boolean {
            val now = android.os.SystemClock.elapsedRealtime()
            val delta = now - lastReceiveAtElapsed
            if (delta < 2000L) return true
            lastReceiveAtElapsed = now
            return false
        }

        private fun scheduleNextMinuteTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val now = System.currentTimeMillis()
                val nextMinute = ((now / 60_000L) + 1L) * 60_000L + 500L
                val pending = PendingIntent.getBroadcast(
                    context,
                    UPDATE_REQ_CODE + 1,
                    Intent(context, TextOnlyWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pending)
                setExactCompat(alarmManager, AlarmManager.RTC_WAKEUP, nextMinute, pending)
            } catch (_: Exception) { }
        }

        private fun prefsReadLongCompat(prefs: android.content.SharedPreferences, key: String): Long? {
            val anyVal = prefs.all[key] ?: return null
            return when (anyVal) {
                is Long -> anyVal
                is Int -> anyVal.toLong()
                is String -> runCatching { anyVal.toLong() }.getOrNull()
                else -> null
            }
        }

        private fun isSystemInDarkMode(context: Context): Boolean {
            val sysCfg = android.content.res.Resources.getSystem().configuration
            val uiMode = sysCfg.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
            return uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
        }

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = android.widget.RemoteViews(context.packageName, R.layout.widget_textonly)

            // Ölçüler
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val density = context.resources.displayMetrics.density
            val minWdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).coerceAtLeast(60)
            val minHdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).coerceAtLeast(60)
            val maxWdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).coerceAtLeast(minWdp)
            val maxHdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).coerceAtLeast(minHdp)
            val targetWpx = (maxWdp * density).roundToInt().coerceAtLeast((minWdp * density).roundToInt())
            val targetHpx = (maxHdp * density).roundToInt().coerceAtLeast((minHdp * density).roundToInt())
            val safeW = targetWpx.coerceIn(200, 1200)
            val safeH = targetHpx.coerceIn(100, 800)

            // Widget genişledikçe metinleri orantılı büyüt (kullanıcı ölçeği ayrıca uygulanacak)
            val baseWidthPx = 260f * density
            val baseHeightPx = 150f * density
            val widthScaleRaw = safeW.toFloat() / baseWidthPx
            val heightScaleRaw = safeH.toFloat() / baseHeightPx
            val rawScale = minOf(widthScaleRaw, heightScaleRaw)
            val growFactor = 3.5f
            val autoScale = if (rawScale <= 1f) {
                rawScale.coerceAtLeast(0.85f)
            } else {
                (1f + (rawScale - 1f) * growFactor).coerceAtMost(2.25f)
            }
            val titleBase = 17f * autoScale
            val contentBase = 19.5f * autoScale
            // Kullanıcı ölçeği: 80..140% arası
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // Widget-specific ayarları oku (varsa), yoksa global ayarları kullan
            val prefix = "widget_${appWidgetId}_"
            val scalePct = prefsGetIntCompat(prefs, "${prefix}nv_text_scale_pct",
                prefsGetIntCompat(prefs, "flutter.nv_textonly_text_scale_pct", 100)).coerceIn(80, 140)
            val scale = scalePct / 100f
            val titleSp = (titleBase * scale).coerceIn(12f, 32f)
            val contentSp = (contentBase * scale).coerceIn(13f, 34f)
            views.setTextViewTextSize(R.id.tv_title, TypedValue.COMPLEX_UNIT_SP, titleSp)
            views.setTextViewTextSize(R.id.tv_subtitle, TypedValue.COMPLEX_UNIT_SP, contentSp)
            views.setTextViewTextSize(R.id.cm_countdown, TypedValue.COMPLEX_UNIT_SP, contentSp)

            // İçerik verisi
            val now = java.util.Calendar.getInstance()
            val directEpoch = prefsReadLongCompat(prefs, "flutter.nv_next_epoch_ms")
            val nowWall = System.currentTimeMillis()
            val useDirect = directEpoch != null && directEpoch > nowWall && (directEpoch - nowWall) < 36L * 3_600_000L
            val triple = if (useDirect) {
                val directName = prefs.getString("flutter.nv_next_prayer_name", null)
                val remain = directEpoch!! - nowWall
                Triple(directName, null, remain)
            } else {
                findNextPrayerAndCountdown(prefs, now)
            }

            val title = if (triple.first.isNullOrBlank()) "Vakit hesaplanıyor" else "${triple.first} vaktine"
            views.setTextViewText(R.id.tv_title, title)
            val subtitle = triple.second ?: "--"
            val remainingMs = triple.third
            if (remainingMs != null && remainingMs > 0L) {
                val hours = (remainingMs / 3_600_000L).toInt()
                val minutes = ((remainingMs % 3_600_000L) / 60_000L).toInt()
                val seconds = ((remainingMs % 60_000L) / 1_000L).toInt()
                if (hours > 0) {
                    val text = "${hours}saat ${minutes}dk"
                    views.setTextViewText(R.id.tv_subtitle, text)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
                } else if (minutes > 0) {
                    val text = "${minutes}dakika"
                    views.setTextViewText(R.id.tv_subtitle, text)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
                } else {
                    val base = android.os.SystemClock.elapsedRealtime() + remainingMs
                    views.setChronometer(R.id.cm_countdown, base, "%s saniye", true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        views.setChronometerCountDown(R.id.cm_countdown, true)
                    }
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.GONE)
                }
            } else {
                views.setTextViewText(R.id.tv_subtitle, subtitle)
                views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
            }

            // Metin rengi: 0 Sistem, 1 Koyu (siyah), 2 Açık (beyaz)
            // Widget-specific ayarları oku (varsa), yoksa global ayarları kullan
            // prefix zaten yukarıda tanımlı
            val textMode = prefsGetIntCompat(prefs, "${prefix}nv_text_color_mode",
                prefsGetIntCompat(prefs, "flutter.nv_textonly_text_color_mode", 0)).coerceIn(0, 2)
            val dark = when (textMode) {
                1 -> false
                2 -> true
                else -> isSystemInDarkMode(context)
            }
            val titleColor = if (dark) 0xFFFFFFFF.toInt() else 0xCC000000.toInt()
            val subColor = if (dark) 0xE6FFFFFF.toInt() else 0x99000000.toInt()
            views.setTextColor(R.id.tv_title, titleColor)
            views.setTextColor(R.id.tv_subtitle, subColor)
            views.setTextColor(R.id.cm_countdown, subColor)

            // Tıklama: uygulamayı aç
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val launchPending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.root_container, launchPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Yeni vakit girişinde anında yenileme için exact tek-seferlik tetik planla
            try {
                val nowWall = System.currentTimeMillis()
                val triggerAt = when {
                    remainingMs != null && remainingMs > 0L -> nowWall + remainingMs + 1000L // +1s tampon
                    else -> null
                }
                if (triggerAt != null) {
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    val pending = android.app.PendingIntent.getBroadcast(
                        context,
                        UPDATE_REQ_CODE + 1,
                        Intent(context, TextOnlyWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                    alarmManager.cancel(pending)
                    setExactCompat(alarmManager, AlarmManager.RTC_WAKEUP, triggerAt, pending)
                }
            } catch (_: Exception) { }
        }

        private fun setExactCompat(alarmManager: AlarmManager, type: Int, triggerAtMillis: Long, operation: PendingIntent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(type, triggerAtMillis, operation)
                } else {
                    alarmManager.setAndAllowWhileIdle(type, triggerAtMillis, operation)
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(type, triggerAtMillis, operation)
            }
        }

        private fun prefsGetIntCompat(prefs: android.content.SharedPreferences, key: String, def: Int): Int {
            val anyVal = prefs.all[key] ?: return def
            return when (anyVal) {
                is Int -> anyVal
                is Long -> anyVal.toInt()
                is String -> runCatching { anyVal.toInt() }.getOrElse { def }
                else -> def
            }
        }

        private fun findNextPrayerAndCountdown(prefs: android.content.SharedPreferences, now: java.util.Calendar): Triple<String?, String?, Long> {
            val directName = prefs.getString("flutter.nv_next_prayer_name", null)
            val directCountdown = prefs.getString("flutter.nv_countdown_text", null)

            var fajr = prefs.getString("flutter.nv_fajr", null)
            var sunrise = prefs.getString("flutter.nv_sunrise", null)
            var dhuhr = prefs.getString("flutter.nv_dhuhr", null)
            var asr = prefs.getString("flutter.nv_asr", null)
            var maghrib = prefs.getString("flutter.nv_maghrib", null)
            var isha = prefs.getString("flutter.nv_isha", null)
            val tomorrowFajr = prefs.getString("flutter.nv_tomorrow_fajr", null)

            val savedTodayIso = prefs.getString("flutter.nv_today_date_iso", null)
            val savedTomorrowIso = prefs.getString("flutter.nv_tomorrow_date_iso", null)
            val todayIso = String.format("%04d-%02d-%02d", now.get(java.util.Calendar.YEAR), now.get(java.util.Calendar.MONTH) + 1, now.get(java.util.Calendar.DAY_OF_MONTH))
            if (savedTodayIso != null && savedTodayIso != todayIso && savedTomorrowIso == todayIso) {
                fajr = prefs.getString("flutter.nv_fajr_tomorrow", fajr)
                sunrise = prefs.getString("flutter.nv_sunrise_tomorrow", sunrise)
                dhuhr = prefs.getString("flutter.nv_dhuhr_tomorrow", dhuhr)
                asr = prefs.getString("flutter.nv_asr_tomorrow", asr)
                maghrib = prefs.getString("flutter.nv_maghrib_tomorrow", maghrib)
                isha = prefs.getString("flutter.nv_isha_tomorrow", isha)
            }

            fun toToday(time: String?): java.util.Calendar? {
                if (time == null) return null
                val parts = time.split(":")
                if (parts.size != 2) return null
                val c = now.clone() as java.util.Calendar
                c.set(java.util.Calendar.SECOND, 0)
                c.set(java.util.Calendar.MILLISECOND, 0)
                c.set(java.util.Calendar.HOUR_OF_DAY, parts[0].toInt())
                c.set(java.util.Calendar.MINUTE, parts[1].toInt())
                return c
            }

            val sequence = listOf(
                Pair("İmsak", toToday(fajr)),
                Pair("Güneş", toToday(sunrise)),
                Pair("Öğle", toToday(dhuhr)),
                Pair("İkindi", toToday(asr)),
                Pair("Akşam", toToday(maghrib)),
                Pair("Yatsı", toToday(isha)),
            )

            for ((name, cal) in sequence) {
                if (cal != null && now.before(cal)) {
                    val diffMs = cal.timeInMillis - now.timeInMillis
                    val h = (diffMs / 3_600_000).toInt()
                    val m = ((diffMs % 3_600_000) / 60_000).toInt()
                    val s = ((diffMs % 60_000) / 1000).toInt()
                    val remainingMs = diffMs
                    val parts = mutableListOf<String>()
                    if (h > 0) parts.add("${h}saat")
                    if (m > 0) {
                        if (h > 0) parts.add("${m}dk") else parts.add("${m}dakika")
                    }
                    if (h == 0 && m == 0) parts.add("${s}saniye")
                    val subtitle = parts.joinToString(" ")
                    return Triple(name, subtitle, remainingMs)
                }
            }

            if (tomorrowFajr != null) {
                val parts = tomorrowFajr.split(":")
                if (parts.size == 2) {
                    val t = (now.clone() as java.util.Calendar)
                    t.add(java.util.Calendar.DAY_OF_YEAR, 1)
                    t.set(java.util.Calendar.SECOND, 0)
                    t.set(java.util.Calendar.MILLISECOND, 0)
                    t.set(java.util.Calendar.HOUR_OF_DAY, parts[0].toInt())
                    t.set(java.util.Calendar.MINUTE, parts[1].toInt())
                    val diffMs = t.timeInMillis - now.timeInMillis
                    val h = (diffMs / 3_600_000).toInt()
                    val m = ((diffMs % 3_600_000) / 60_000).toInt()
                    val s = ((diffMs % 60_000) / 1000).toInt()
                    val remainingMs = diffMs
                    val parts2 = mutableListOf<String>()
                    if (h > 0) parts2.add("${h}saat")
                    if (m > 0) {
                        if (h > 0) parts2.add("${m}dk") else parts2.add("${m}dakika")
                    }
                    if (h == 0 && m == 0) parts2.add("${s}saniye")
                    val subtitle = parts2.joinToString(" ")
                    return Triple("İmsak", subtitle, remainingMs)
                }
            }

            if (!directName.isNullOrBlank() && !directCountdown.isNullOrBlank()) {
                return Triple(directName, directCountdown, -1L)
            }
            return Triple(null, null, -1L)
        }


    }
}


