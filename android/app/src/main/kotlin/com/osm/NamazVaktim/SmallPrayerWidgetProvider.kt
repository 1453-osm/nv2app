package com.osm.NamazVaktim

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
 import android.graphics.*
 import android.graphics.drawable.BitmapDrawable
 import android.os.Build
import android.os.PowerManager
import android.util.TypedValue
import android.os.Bundle
 import android.app.WallpaperManager
 import android.content.SharedPreferences
 // RS Toolkit kaldırıldı
import kotlin.math.roundToInt

class SmallPrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        // Dakika bazlı periyodik planlama ve exact dakika başı tetikleyici (yedekli)
        scheduleRepeatingUpdate(context)
        scheduleNextMinuteTick(context)
    }

    override fun onEnabled(context: Context) {
        // İlk widget eklendiğinde periyodik + exact dakika tetikleyicilerini başlat
        scheduleRepeatingUpdate(context)
        scheduleNextMinuteTick(context)
    }

    override fun onDisabled(context: Context) {
        // Son widget kaldırıldığında tekrar eden alarmı iptal et
        cancelRepeatingUpdate(context)
        // Exact tick iptali
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = PendingIntent.getBroadcast(
            context,
            UPDATE_REQ_CODE + 1,
            Intent(context, SmallPrayerWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        when (action) {
            ACTION_UPDATE_MINUTE -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
                onUpdate(context, manager, ids)
                // UfukMarmara sisteminde zincirli exact tetik yok; inexact yeterli
                // Dakika zinciri için bir sonraki dakika başını da planla
                scheduleNextMinuteTick(context)
            }
            Intent.ACTION_USER_PRESENT, // kullanıcı kilidi açtı
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_CONFIGURATION_CHANGED -> {
                // Basit debounce: ardışık tetiklerde ağır güncellemeyi atla
                if (shouldThrottle()) return
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
                onUpdate(context, manager, ids)

                // Tekrar eden planlama reboot/zaman değişimlerinde garantiye alınsın
                if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED || action == Intent.ACTION_DATE_CHANGED) {
                    scheduleRepeatingUpdate(context)
                    scheduleNextMinuteTick(context)
                }
                // UfukMarmara sisteminde ek exact tetik kullanılmıyor
            }
            // Özellikle gece/gündüz modu değişimi için yayın
            "android.app.action.UI_MODE_CHANGED" -> {
                if (shouldThrottle()) return
                // Ağır işi doğrudan broadcast içinde yapma; hafif planlama yap
                val appContext = context.applicationContext
                requestThemeAwareRefresh(appContext)
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
        // Bazı launcher'lar konfig değişimini buradan bildirir
        updateAppWidget(context, appWidgetManager, appWidgetId)
        // Dakika bazlı tekrar eden planlama yeterli
    }

    // One UI 7 uyumlu - daha az sıklıkta güncelleme
    private fun scheduleRepeatingUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetUpdateReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            UPDATE_REQ_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Yedek periyodik tetik: 1 dakika (inexact, sistem enerji politikalarına tabi)
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

    // UfukMarmara sistemi: tek seferlik exact tetik kullanılmıyor

        // scheduleNextBasedOnState kaldırıldı; inexact repeating kullanılacak

    // Eski exact alarm iptal mekanizması kaldırıldı (inexact repeating kullanılıyor)

    // Görünürlük anchor ve exact tetikleyiciler kaldırıldı

    companion object {
        private const val ACTION_UPDATE_MINUTE = "com.osm.NamazVaktim.UPDATE_SMALL_WIDGET"
        private const val UPDATE_REQ_CODE = 0x856
        private fun scheduleNextMinuteTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val now = System.currentTimeMillis()
                val nextMinute = ((now / 60_000L) + 1L) * 60_000L + 500L // dakika başından hemen sonra
                val pending = PendingIntent.getBroadcast(
                    context,
                    UPDATE_REQ_CODE + 1,
                    Intent(context, SmallPrayerWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pending)
                setExactCompat(alarmManager, AlarmManager.RTC_WAKEUP, nextMinute, pending)
            } catch (_: Exception) { }
        }
        private fun shouldThrottle(): Boolean {
            val now = android.os.SystemClock.elapsedRealtime()
            val delta = now - lastReceiveAtElapsed
            if (delta < 2000L) return true
            lastReceiveAtElapsed = now
            return false
        }
        private var lastReceiveAtElapsed: Long = 0L
        private var lastOverlaySig: String? = null
        private var lastGradientSig: String? = null
        private var lastOverlayBitmap: Bitmap? = null
        private var lastGradientBitmap: Bitmap? = null
        private fun prefsReadLongCompat(prefs: SharedPreferences, key: String): Long? {
            val anyVal = prefs.all[key] ?: return null
            return when (anyVal) {
                is Long -> anyVal
                is Int -> anyVal.toLong()
                is String -> runCatching { anyVal.toLong() }.getOrNull()
                else -> null
            }
        }

         fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = android.widget.RemoteViews(context.packageName, R.layout.widget_small)

            // Widget'in güncel ölçülerini al (launcher tarafından sağlanır)
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val density = context.resources.displayMetrics.density
            val minWdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).coerceAtLeast(60)
            val minHdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).coerceAtLeast(60)
            val maxWdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).coerceAtLeast(minWdp)
            val maxHdp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).coerceAtLeast(minHdp)
            // Daha iyi görsel kalite için hedef boyutu max değerlere yakın seçiyoruz
            val targetWpx = (maxWdp * density).roundToInt().coerceAtLeast((minWdp * density).roundToInt())
            val targetHpx = (maxHdp * density).roundToInt().coerceAtLeast((minHdp * density).roundToInt())
            val safeW = targetWpx.coerceIn(200, 1200)
            val safeH = targetHpx.coerceIn(100, 800)
            // Hesap yükünü azaltmak için üst tavan uygula
            val cappedW = safeW.coerceAtMost(600)
            val cappedH = safeH.coerceAtMost(300)

            // Metin boyutlarını widget'ın güncel ölçülerine orantılı büyüt/küçült
            val baseWidthPx = 260f * density
            val baseHeightPx = 150f * density
            val widthScaleRaw = safeW.toFloat() / baseWidthPx
            val heightScaleRaw = safeH.toFloat() / baseHeightPx
            val rawScale = minOf(widthScaleRaw, heightScaleRaw)
            val growFactor = 3.5f
            val textScale = if (rawScale <= 1f) {
                rawScale.coerceAtLeast(0.85f) // Küçük boyutlarda okunurluğu koru
            } else {
                (1f + (rawScale - 1f) * growFactor).coerceAtMost(2.2f)
            }
            views.setTextViewTextSize(R.id.tv_title, TypedValue.COMPLEX_UNIT_SP, 17f * textScale)
            views.setTextViewTextSize(R.id.tv_subtitle, TypedValue.COMPLEX_UNIT_SP, 19f * textScale)
            views.setTextViewTextSize(R.id.cm_countdown, TypedValue.COMPLEX_UNIT_SP, 19f * textScale)

            // Arka plan: Blur tamamen devre dışı. Duvar kağıdı view'u kaldırıldı.
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var resolvedGradientMode = 1
            var resolvedAccentColor = 0xFF2196F3.toInt()
            
            // Widget-specific ayarları oku (varsa), yoksa global ayarları kullan
            val prefix = "widget_${appWidgetId}_"

            // Tema rengine göre gradyan overlay (isteğe bağlı) - sadece ID mevcut ise
            try {
                val accentColor = resolveAccentColor(context)
                resolvedAccentColor = accentColor
                val gradientModeRaw = prefsGetIntCompat(prefs, "${prefix}nv_gradient_mode", 
                    prefsGetIntCompat(prefs, "flutter.nv_gradient_mode", -1))
                val gradientMode = when {
                    gradientModeRaw in 0..2 -> gradientModeRaw
                    else -> if (prefsGetBoolCompat(prefs, "flutter.nv_gradient_on", true)) 1 else 0
                }
                resolvedGradientMode = gradientMode
                val radiusDp = prefsGetIntCompat(prefs, "${prefix}nv_card_radius_dp",
                    prefsGetIntCompat(prefs, "flutter.nv_card_radius_dp", 75)).coerceIn(0, 120)
                if (gradientMode == 1) {
                    val gradSig = "c=${accentColor}|r=${radiusDp}|${cappedW}x${cappedH}"
                    if (gradSig != lastGradientSig || lastGradientBitmap == null) {
                        lastGradientBitmap = generateTopGradient(context, accentColor, radiusDp, cappedW, cappedH)
                        lastGradientSig = gradSig
                    }
                    lastGradientBitmap?.let { views.setImageViewBitmap(R.id.gradient_overlay, it) }
                    views.setViewVisibility(R.id.gradient_overlay, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.gradient_overlay, android.view.View.GONE)
                }

                // Kart overlay opaklığını SharedPreferences'tan uygula (0..255)
                // Karanlık/aydınlık moda duyarlı opak overlay
                val overlayAlpha = prefsGetIntCompat(prefs = prefs, key = "${prefix}nv_card_alpha",
                    prefsGetIntCompat(prefs, "flutter.nv_card_alpha", 204))
                val bgMode = prefsGetIntCompat(prefs, "${prefix}nv_bg_color_mode",
                    prefsGetIntCompat(prefs, "flutter.nv_bg_color_mode", 0)).coerceIn(0, 2)
                val darkFlag = when (bgMode) { 1 -> false; 2 -> true; else -> isSystemInDarkMode(context) }
                val isDynamic = isDynamicThemeMode(context)
                val secondaryColor = if (gradientMode == 2 && isDynamic) resolveSecondaryColor(context) else null
                val ovSig = "mode=${gradientMode}|a=${overlayAlpha}|r=${radiusDp}|m=${bgMode}|d=${darkFlag}|c=${accentColor}|s=${secondaryColor}|${cappedW}x${cappedH}"
                if (ovSig != lastOverlaySig || lastOverlayBitmap == null) {
                    lastOverlayBitmap = if (gradientMode == 2) {
                        if (isDynamic && secondaryColor != null) {
                            generateGradientColoredCardOverlay(context, accentColor, secondaryColor, overlayAlpha, radiusDp, cappedW, cappedH)
                        } else {
                            generateColoredCardOverlay(context, accentColor, overlayAlpha, radiusDp, cappedW, cappedH)
                        }
                    } else {
                        generateCardOverlay(context, overlayAlpha, radiusDp, cappedW, cappedH, bgMode)
                    }
                    lastOverlaySig = ovSig
                }
                lastOverlayBitmap?.let { views.setImageViewBitmap(R.id.bg_card_overlay, it) }
            } catch (e: Exception) {
                // Layout'ta bu ID'ler yoksa sessizce geç (örn: basit layout kullanılıyorsa)
            }

            // İçerik: SharedPreferences üzerinden Flutter'ın yazdığı değerler
            val now = java.util.Calendar.getInstance()
            val locale = WidgetLocalizationHelper.getLocale(prefs)
            // Öncelik: Flutter'ın kaydettiği kesin hedef zaman (epoch ms)
            val directEpoch = prefsReadLongCompat(prefs, "flutter.nv_next_epoch_ms")
            val nowWall = System.currentTimeMillis()
            val useDirect = directEpoch != null && directEpoch > nowWall && (directEpoch - nowWall) < 36L * 3_600_000L
            val triple = if (useDirect) {
                val directName = prefs.getString("flutter.nv_next_prayer_name", null)
                val remain = directEpoch!! - nowWall
                Triple(directName, null, remain)
            } else {
                findNextPrayerAndCountdown(prefs, now, locale)
            }
            val calculatingText = WidgetLocalizationHelper.getCalculatingTimeText(locale)
            val nextPrayerFormat = WidgetLocalizationHelper.getNextPrayerTimeFormat(locale)
            val prayerName = if (triple.first.isNullOrBlank()) {
                null
            } else {
                WidgetLocalizationHelper.getPrayerName(locale, triple.first!!)
            }
            val title = if (prayerName.isNullOrBlank()) {
                calculatingText
            } else {
                "$prayerName $nextPrayerFormat"
            }
            views.setTextViewText(R.id.tv_title, title)
            val subtitle = triple.second ?: "--"
            val remainingMs = triple.third
            if (remainingMs != null && remainingMs > 0L) {
                val hours = (remainingMs / 3_600_000L).toInt()
                val minutes = ((remainingMs % 3_600_000L) / 60_000L).toInt()
                val seconds = ((remainingMs % 60_000L) / 1_000L).toInt()

                if (hours > 0) {
                    // 1- Xsaat Ydk
                    val text = WidgetLocalizationHelper.formatTimeRemaining(locale, hours, minutes, 0)
                    views.setTextViewText(R.id.tv_subtitle, text)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
                } else if (minutes > 0) {
                    // 2- Ydakika
                    val text = WidgetLocalizationHelper.formatTimeRemaining(locale, 0, minutes, 0)
                    views.setTextViewText(R.id.tv_subtitle, text)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
                } else {
                    // 3- Zsaniye (bir dakikanın altında) - Chronometer ile saniye saniye akar
                    val base = android.os.SystemClock.elapsedRealtime() + remainingMs
                    val secondText = WidgetLocalizationHelper.getSecondText(locale)
                    views.setChronometer(R.id.cm_countdown, base, "%s $secondText", true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        views.setChronometerCountDown(R.id.cm_countdown, true)
                    }
                    views.setViewVisibility(R.id.cm_countdown, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.tv_subtitle, android.view.View.GONE)
                }
            } else {
                // Statik metin yedeği
                views.setTextViewText(R.id.tv_subtitle, subtitle)
                views.setViewVisibility(R.id.tv_subtitle, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.cm_countdown, android.view.View.GONE)
            }

            // Metin rengi: kullanıcı tercihi (0: Sistem, 1: Koyu, 2: Açık)
            val textMode = prefsGetIntCompat(prefs, "${prefix}nv_text_color_mode",
                prefsGetIntCompat(prefs, "flutter.nv_text_color_mode", 0)).coerceIn(0, 2)
            val dark = when (textMode) {
                1 -> false // Koyu yazı istendi: açık arkaplan varsayımıyla siyah metin
                2 -> true  // Açık yazı istendi: koyu arkaplan varsayımıyla beyaz metin
                else -> if (resolvedGradientMode == 2) {
                    isColorDark(resolvedAccentColor)
                } else {
                    isSystemInDarkMode(context)
                }
            }
            val titleColor = if (dark) Color.parseColor("#FFFFFFFF") else Color.parseColor("#CC000000")
            val subColor = if (dark) Color.parseColor("#E6FFFFFF") else Color.parseColor("#99000000")
            views.setTextColor(R.id.tv_title, titleColor)
            views.setTextColor(R.id.tv_subtitle, subColor)

            // Not: RemoteViews'daki Chronometer sadece görünümde akar; alarmlar widget'in periyodik olarak güncellenmesini sağlar.
            // Tıklama: widget'e tıklanınca uygulamayı aç
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val launchPending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.card_container, launchPending)
            // Tüm RemoteViews değişikliklerini tek seferde uygula (tıklama dahil)
            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Yeni vakit girişinde anında güncellenmesi için exact tek-seferlik tetik planla
            try {
                val nowWall = System.currentTimeMillis()
                val triggerAt = when {
                    remainingMs != null && remainingMs > 0L -> nowWall + remainingMs + 1000L // +1s tampon
                    else -> null
                }
                if (triggerAt != null) {
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val pending = PendingIntent.getBroadcast(
                        context,
                        UPDATE_REQ_CODE + 1,
                        Intent(context, SmallPrayerWidgetProvider::class.java).setAction(ACTION_UPDATE_MINUTE),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    // Önce varsa eski exact'ı iptal et, sonra yenisini kur
                    alarmManager.cancel(pending)
                    setExactCompat(alarmManager, AlarmManager.RTC_WAKEUP, triggerAt, pending)
                }
            } catch (_: Exception) { }
        }

        // requestReschedule kaldırıldı; tekrar eden planlama kullanılacak

        fun requestThemeAwareRefresh(context: Context) {
            try {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
                if (ids != null && ids.isNotEmpty()) {
                    // Anında bir güncelleme ve kısa bir ek tetikleme: yeni UI mode'un tam oturması için
                    ids.forEach { updateAppWidget(context, mgr, it) }
                    // Non-collection bile olsa host'lara "içerik değişti" sinyali gönder
                    val viewIds = intArrayOf(R.id.tv_title, R.id.tv_subtitle, R.id.cm_countdown, R.id.bg_card_overlay, R.id.gradient_overlay)
                    viewIds.forEach { vId -> mgr.notifyAppWidgetViewDataChanged(ids, vId) }
                }
            } catch (_: Exception) {
                // Sessizce geç
            }
            // Periyodik tekrar eden planlama yeterli
        }



        private fun findNextPrayerAndCountdown(prefs: SharedPreferences, now: java.util.Calendar, locale: String): Triple<String?, String?, Long> {
            // Öncelik: her zaman vakitlerden hesaplama (uygulama kapalıyken de çalışır)
            // Flutter'ın yazdığı stringler yalnızca yedek olarak kullanılsın.
            val directName = prefs.getString("flutter.nv_next_prayer_name", null)
            val directCountdown = prefs.getString("flutter.nv_countdown_text", null)

            // Günün vakitleri (FlutterSharedPreferences anahtarları)
            var fajr = prefs.getString("flutter.nv_fajr", null)
            var sunrise = prefs.getString("flutter.nv_sunrise", null)
            var dhuhr = prefs.getString("flutter.nv_dhuhr", null)
            var asr = prefs.getString("flutter.nv_asr", null)
            var maghrib = prefs.getString("flutter.nv_maghrib", null)
            var isha = prefs.getString("flutter.nv_isha", null)
            val tomorrowFajr = prefs.getString("flutter.nv_tomorrow_fajr", null)

            // Tarih kayması: Eğer kayıtlı today ISO bugünden farklıysa ve yarın verileri mevcutsa onları bugüne taşı
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
                    val subtitle = WidgetLocalizationHelper.formatTimeRemaining(locale, h, m, s)
                    return Triple(name, subtitle, remainingMs)
                }
            }
            // Gün bitti, yarının imsak
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
                    val subtitle = WidgetLocalizationHelper.formatTimeRemaining(locale, h, m, s)
                    return Triple("İmsak", subtitle, remainingMs)
                }
            }
            // Vakitler yoksa Flutter'ın en son yazdığı stringleri göster (statik yedek)
            if (!directName.isNullOrBlank() && !directCountdown.isNullOrBlank()) {
                return Triple(directName, directCountdown, -1L)
            }
            return Triple(null, null, -1L)
        }

        private fun isSystemInDarkMode(context: Context): Boolean {
            // Uygulama kaynaklarından bağımsız olarak sistemin güncel night modunu oku
            val sysCfg = android.content.res.Resources.getSystem().configuration
            val uiMode = sysCfg.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
            return uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
        }

        private fun resolveAccentColor(context: Context): Int {
            val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            fun readColor(key: String): Int? {
                val anyVal = prefs.all[key] ?: return null
                return when (anyVal) {
                    is Int -> anyVal
                    is Long -> anyVal.toInt()
                    is String -> runCatching { anyVal.toInt() }.getOrNull()
                    else -> null
                }
            }
            return readColor("flutter.current_theme_color")
                ?: readColor("flutter.selected_theme_color")
                ?: 0xFF2196F3.toInt()
        }

        private fun resolveSecondaryColor(context: Context): Int? {
            val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            fun readColor(key: String): Int? {
                val anyVal = prefs.all[key] ?: return null
                return when (anyVal) {
                    is Int -> anyVal
                    is Long -> anyVal.toInt()
                    is String -> runCatching { anyVal.toInt() }.getOrNull()
                    else -> null
                }
            }
            return readColor("flutter.current_secondary_color")
        }

        private fun isDynamicThemeMode(context: Context): Boolean {
            val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val modeStr = prefs.getString("flutter.theme_color_mode", null)
            return modeStr == "dynamic"
        }

        private fun generateTopGradient(context: Context, color: Int, radiusDp: Int, width: Int, height: Int): Bitmap {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)

            val shader = LinearGradient(
                0f, 0f, 0f, height.toFloat(),
                intArrayOf(applyAlpha(color, 0.55f), applyAlpha(color, 0.0f)),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP
            )
            paint.shader = shader

            // Widget kartının köşe yarıçapı Flutter'dan ayarlanabilir (dp)
            val density = context.resources.displayMetrics.density
            val radius = radiusDp.coerceAtLeast(0).toFloat() * density
            val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, paint)
            return bmp
        }

        private fun applyAlpha(color: Int, alpha: Float): Int {
            val a = (Color.alpha(color) * alpha).toInt()
            return Color.argb(a, Color.red(color), Color.green(color), Color.blue(color))
        }

        private fun isColorDark(color: Int): Boolean {
            val darkness = 1.0 - (
                0.299 * Color.red(color).toDouble() +
                    0.587 * Color.green(color).toDouble() +
                    0.114 * Color.blue(color).toDouble()
                ) / 255.0
            return darkness >= 0.5
        }

        // Blur kaldırıldığı için compose helper'a gerek yok; silindi

        private fun generateWallpaperBitmap(context: Context): Bitmap? {
            return try {
                val wm = WallpaperManager.getInstance(context)
                var src: Bitmap? = null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val pfd = wm.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
                    pfd?.use { src = android.graphics.BitmapFactory.decodeFileDescriptor(it.fileDescriptor) }
                }
                if (src == null) {
                    val d = wm.drawable ?: return null
                    src = (d as? BitmapDrawable)?.bitmap ?: run {
                        val dm = context.resources.displayMetrics
                        val fallbackW = dm.widthPixels.coerceAtLeast(720)
                        val fallbackH = dm.heightPixels.coerceAtLeast(1280)
                        val w = if (d.intrinsicWidth > 0) d.intrinsicWidth else fallbackW
                        val h = if (d.intrinsicHeight > 0) d.intrinsicHeight else fallbackH
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        val c = Canvas(bmp)
                        d.setBounds(0, 0, w, h)
                        d.draw(c)
                        bmp
                    }
                }
                src
            } catch (_: Exception) { null }
        }

        private fun generateCardOverlay(context: Context, alpha: Int, radiusDp: Int, width: Int, height: Int, bgMode: Int): Bitmap {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val density = context.resources.displayMetrics.density
            val radius = radiusDp.coerceAtLeast(0).toFloat() * density
            // Yalnızca opaklık uygulanan arkaplan: koyu modda saydam siyah, aydınlık modda saydam beyaz
            val isDark = when (bgMode) {
                1 -> false // Açık
                2 -> true  // Koyu
                else -> isSystemInDarkMode(context) // Sistem
            }
            val a = alpha.coerceIn(0, 255)
            paint.color = if (isDark) Color.argb(a, 0, 0, 0) else Color.argb(a, 255, 255, 255)
            canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
            return bmp
        }

        private fun generateColoredCardOverlay(context: Context, baseColor: Int, alpha: Int, radiusDp: Int, width: Int, height: Int): Bitmap {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val density = context.resources.displayMetrics.density
            val radius = radiusDp.coerceAtLeast(0).toFloat() * density
            val clampedAlpha = alpha.coerceIn(0, 255)
            val overlayColor = Color.argb(
                clampedAlpha,
                Color.red(baseColor),
                Color.green(baseColor),
                Color.blue(baseColor)
            )
            paint.color = overlayColor
            canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
            return bmp
        }

        private fun generateGradientColoredCardOverlay(context: Context, primaryColor: Int, secondaryColor: Int, alpha: Int, radiusDp: Int, width: Int, height: Int): Bitmap {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val density = context.resources.displayMetrics.density
            val radius = radiusDp.coerceAtLeast(0).toFloat() * density
            val clampedAlpha = alpha.coerceIn(0, 255)
            
            // Ana renk ve ikincil renk arasında gradient oluştur (üstten alta)
            val primaryWithAlpha = Color.argb(
                clampedAlpha,
                Color.red(primaryColor),
                Color.green(primaryColor),
                Color.blue(primaryColor)
            )
            val secondaryWithAlpha = Color.argb(
                clampedAlpha,
                Color.red(secondaryColor),
                Color.green(secondaryColor),
                Color.blue(secondaryColor)
            )
            
            val shader = LinearGradient(
                0f, 0f, 0f, height.toFloat(),
                intArrayOf(primaryWithAlpha, secondaryWithAlpha),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP
            )
            paint.shader = shader
            
            canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
            return bmp
        }

        private fun prefsGetIntCompat(prefs: SharedPreferences, key: String, def: Int): Int {
            val anyVal = prefs.all[key] ?: return def
            return when (anyVal) {
                is Int -> anyVal
                is Long -> anyVal.toInt()
                is String -> runCatching { anyVal.toInt() }.getOrElse { def }
                else -> def
            }
        }

        private fun prefsGetBoolCompat(prefs: SharedPreferences, key: String, def: Boolean): Boolean {
            val anyVal = prefs.all[key] ?: return def
            return when (anyVal) {
                is Boolean -> anyVal
                is String -> anyVal.equals("true", ignoreCase = true)
                is Int -> anyVal != 0
                else -> def
            }
        }

        private fun generateBlurredWallpaper(context: Context): Bitmap? {
            return try {
                val wm = WallpaperManager.getInstance(context)
                var src: Bitmap? = null

                // 0) Flutter tarafından kaydedilmiş özel arka plan varsa onu kullan
                val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val savedB64Any = sp.getString("flutter.nv_bg_image_b64", null)
                val savedPathAny = sp.getString("flutter.nv_bg_image_path", null)
                if (!savedB64Any.isNullOrEmpty()) {
                    try {
                        val data = android.util.Base64.decode(savedB64Any, android.util.Base64.DEFAULT)
                        src = android.graphics.BitmapFactory.decodeByteArray(data, 0, data.size)
                    } catch (_: Exception) {}
                }
                if (src == null && !savedPathAny.isNullOrEmpty()) {
                    try {
                        src = android.graphics.BitmapFactory.decodeFile(savedPathAny)
                    } catch (_: Exception) {}
                }

                // 1) Otomatik: Sistem duvar kağıdını her zaman dene (manuel gerektirmez)
                if (src == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val pfdSys = wm.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
                    pfdSys?.use { src = android.graphics.BitmapFactory.decodeFileDescriptor(it.fileDescriptor) }
                    if (src == null) {
                        val pfdAny = wm.getWallpaperFile(WallpaperManager.FLAG_LOCK)
                        pfdAny?.use { src = android.graphics.BitmapFactory.decodeFileDescriptor(it.fileDescriptor) }
                    }
                }

                if (src == null) {
                    val drawable = wm.drawable ?: return null
                    src = (drawable as? BitmapDrawable)?.bitmap
                    if (src == null) {
                        val dm = context.resources.displayMetrics
                        val fallbackW = dm.widthPixels.coerceAtLeast(720)
                        val fallbackH = dm.heightPixels.coerceAtLeast(1280)
                        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else fallbackW
                        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else fallbackH
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        val c = Canvas(bmp)
                        drawable.setBounds(0, 0, w, h)
                        drawable.draw(c)
                        src = bmp
                    }
                }

                val safeSrc = src ?: return null

                // 1) Çıktıyı RemoteViews limitine uygun sabit boyuta üret (600x300)
                val outW = 600
                val outH = 300

                // 2) Center-crop için kaynak dikdörtgeni hesapla
                val srcRatio = safeSrc.width.toFloat() / safeSrc.height
                val dstRatio = outW.toFloat() / outH
                val srcRect = if (srcRatio > dstRatio) {
                    val wantedW = (safeSrc.height * dstRatio).toInt()
                    val left = (safeSrc.width - wantedW) / 2
                    Rect(left, 0, left + wantedW, safeSrc.height)
                } else {
                    val wantedH = (safeSrc.width / dstRatio).toInt()
                    val top = (safeSrc.height - wantedH) / 2
                    Rect(0, top, safeSrc.width, top + wantedH)
                }
                val dstRect = Rect(0, 0, outW, outH)
                val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(out)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                paint.isFilterBitmap = true

                // 1) Center-crop çiz
                canvas.drawBitmap(safeSrc, srcRect, Rect(0, 0, outW, outH), paint)

                // 2) Profesyonel ve garantili yol: ağır downscale + upscale (frosted effect)
                //    Bu, tüm cihazlarda belirgin blur üretir
                val tinyW = 40
                val tinyH = 20
                val tiny = Bitmap.createScaledBitmap(out, tinyW, tinyH, true)
                // İsteğe bağlı hafif blur ile yumuşat
                val tinyBlur = fastBlur(tiny, 3)
                Bitmap.createScaledBitmap(tinyBlur, outW, outH, true)
            } catch (e: Exception) {
                null
            }
        }

        // İki geçişli hızlı kutu blur (yatay + dikey)
        private fun fastBlur(sentBitmap: Bitmap, radius: Int): Bitmap {
            val cfg = sentBitmap.config ?: Bitmap.Config.ARGB_8888
            val bitmap = sentBitmap.copy(cfg, true)
            val w = bitmap.width
            val h = bitmap.height
            val src = IntArray(w * h)
            bitmap.getPixels(src, 0, w, 0, 0, w, h)

            val r = radius.coerceAtLeast(1)
            val div = r + r + 1

            // 1) Yatay geçiş
            val tmp = IntArray(w * h)
            var yi = 0
            for (y in 0 until h) {
                var rs = 0; var gs = 0; var bs = 0
                // ilk pencere
                for (i in -r..r) {
                    val px = src[yi + clamp(i, 0, w - 1)]
                    rs += (px shr 16) and 0xFF
                    gs += (px shr 8) and 0xFF
                    bs += px and 0xFF
                }
                for (x in 0 until w) {
                    val ri = rs / div
                    val gi = gs / div
                    val bi = bs / div
                    tmp[yi + x] = (0xFF shl 24) or (ri shl 16) or (gi shl 8) or bi
                    val i1 = x - r
                    val i2 = x + r + 1
                    if (i1 >= 0) {
                        val p1 = src[yi + i1]
                        rs -= (p1 shr 16) and 0xFF
                        gs -= (p1 shr 8) and 0xFF
                        bs -= p1 and 0xFF
                    }
                    if (i2 < w) {
                        val p2 = src[yi + i2]
                        rs += (p2 shr 16) and 0xFF
                        gs += (p2 shr 8) and 0xFF
                        bs += p2 and 0xFF
                    }
                }
                yi += w
            }

            // 2) Dikey geçiş
            val out = IntArray(w * h)
            for (x in 0 until w) {
                var rs = 0; var gs = 0; var bs = 0
                // ilk pencere
                for (i in -r..r) {
                    val py = clamp(i, 0, h - 1)
                    val px = tmp[py * w + x]
                    rs += (px shr 16) and 0xFF
                    gs += (px shr 8) and 0xFF
                    bs += px and 0xFF
                }
                for (y in 0 until h) {
                    val ri = rs / div
                    val gi = gs / div
                    val bi = bs / div
                    out[y * w + x] = (0xFF shl 24) or (ri shl 16) or (gi shl 8) or bi
                    val i1 = y - r
                    val i2 = y + r + 1
                    if (i1 >= 0) {
                        val p1 = tmp[i1 * w + x]
                        rs -= (p1 shr 16) and 0xFF
                        gs -= (p1 shr 8) and 0xFF
                        bs -= p1 and 0xFF
                    }
                    if (i2 < h) {
                        val p2 = tmp[i2 * w + x]
                        rs += (p2 shr 16) and 0xFF
                        gs += (p2 shr 8) and 0xFF
                        bs += p2 and 0xFF
                    }
                }
            }

            val outBitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            outBitmap.setPixels(out, 0, w, 0, 0, w, h)
            return Bitmap.createScaledBitmap(outBitmap, w * 2, h * 2, true)
        }

        private fun clamp(v: Int, min: Int, max: Int): Int = if (v < min) min else if (v > max) max else v

        // Ekran durumu kontrolü gereksizleşti

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

        // Dinamik metin rengi yardımcıları kaldırıldı; metin rengi yalnızca koyu moda göre ayarlanıyor
    }
}


