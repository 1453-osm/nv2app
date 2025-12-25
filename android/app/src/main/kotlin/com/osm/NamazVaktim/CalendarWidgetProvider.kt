package com.osm.NamazVaktim

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Bundle
import android.content.SharedPreferences
import android.util.TypedValue
import kotlin.math.roundToInt

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        // Günlük güncelleme için planlama
        scheduleDailyUpdate(context)
    }

    override fun onEnabled(context: Context) {
        scheduleDailyUpdate(context)
    }

    override fun onDisabled(context: Context) {
        cancelDailyUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        when (action) {
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_CONFIGURATION_CHANGED -> {
                if (shouldThrottle()) return
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
                onUpdate(context, manager, ids)
                if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED || action == Intent.ACTION_DATE_CHANGED) {
                    scheduleDailyUpdate(context)
                }
            }
            "android.app.action.UI_MODE_CHANGED" -> {
                if (shouldThrottle()) return
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
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun scheduleDailyUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                UPDATE_REQ_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Her gün 00:00'da güncelle
            val calendar = java.util.Calendar.getInstance().apply {
                timeInMillis = System.currentTimeMillis()
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pending
            )
        } catch (_: Exception) {}
    }

    private fun cancelDailyUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                UPDATE_REQ_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pending)
        } catch (_: Exception) {}
    }

    companion object {
        private const val UPDATE_REQ_CODE = 0x857

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

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = android.widget.RemoteViews(context.packageName, R.layout.widget_calendar)

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
            val cappedW = safeW.coerceAtMost(600)
            val cappedH = safeH.coerceAtMost(300)

            // Widget genişliğine/görünür yüksekliğine göre metin boyutlarını ölçekle
            val baseWidthPx = 260f * density
            val baseHeightPx = 150f * density
            val widthScaleRaw = safeW.toFloat() / baseWidthPx
            val heightScaleRaw = safeH.toFloat() / baseHeightPx
            // Her iki ekseni de dikkate alan geometrik ortalama kullan (yatay ve dikey genişlemede dinamik)
            val rawScale = kotlin.math.sqrt(widthScaleRaw * heightScaleRaw)
            val growFactor = 3.5f
            val textScale = if (rawScale <= 1f) {
                rawScale.coerceAtLeast(0.70f)
            } else {
                (1f + (rawScale - 1f) * growFactor).coerceAtMost(2.2f)
            }
            views.setTextViewTextSize(R.id.tv_hijri_date, TypedValue.COMPLEX_UNIT_SP, 17f * textScale)
            views.setTextViewTextSize(R.id.tv_gregorian_date, TypedValue.COMPLEX_UNIT_SP, 17f * textScale)

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var resolvedGradientMode = 1
            var resolvedAccentColor = 0xFF2196F3.toInt()
            
            // Widget-specific ayarları oku (varsa), yoksa global ayarları kullan
            val prefix = "widget_${appWidgetId}_"

            // Tema rengine göre gradyan overlay
            try {
                val accentColor = resolveAccentColor(context)
                resolvedAccentColor = accentColor
                val gradientModeRaw = prefsGetIntCompat(prefs, "${prefix}nv_gradient_mode",
                    prefsGetIntCompat(prefs, "flutter.nv_calendar_gradient_mode", -1))
                val gradientMode = when {
                    gradientModeRaw in 0..2 -> gradientModeRaw
                    else -> if (prefsGetBoolCompat(prefs, "flutter.nv_calendar_gradient_on", true)) 1 else 0
                }
                resolvedGradientMode = gradientMode
                val radiusDp = prefsGetIntCompat(prefs, "${prefix}nv_card_radius_dp",
                    prefsGetIntCompat(prefs, "flutter.nv_calendar_card_radius_dp", 75)).coerceIn(0, 120)
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

                // Kart overlay opaklığı
                val overlayAlpha = prefsGetIntCompat(prefs = prefs, key = "${prefix}nv_card_alpha",
                    prefsGetIntCompat(prefs, "flutter.nv_calendar_card_alpha", 204))
                val bgMode = prefsGetIntCompat(prefs, "${prefix}nv_bg_color_mode",
                    prefsGetIntCompat(prefs, "flutter.nv_calendar_bg_color_mode", 0)).coerceIn(0, 2)
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
                // Layout'ta bu ID'ler yoksa sessizce geç
            }

            // Tarih içeriği: SharedPreferences'tan Flutter'ın yazdığı değerler
            val hijriDate = prefs.getString("flutter.nv_calendar_hijri_date", "") ?: ""
            val gregorianDate = prefs.getString("flutter.nv_calendar_gregorian_date", "") ?: ""
            
            // Tarih gösterim modu: 0=Her ikisi, 1=Sadece Hicri, 2=Sadece Miladi
            val dateDisplayMode = prefsGetIntCompat(prefs, "${prefix}nv_calendar_display_mode",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_display_mode", 0)).coerceIn(0, 2)

            // Font stilleri: 0=Light, 1=Bold
            val hijriFontStyle = prefsGetIntCompat(prefs, "${prefix}nv_calendar_hijri_font_style",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_hijri_font_style", 0)).coerceIn(0, 1)
            val gregorianFontStyle = prefsGetIntCompat(prefs, "${prefix}nv_calendar_gregorian_font_style",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_gregorian_font_style", 1)).coerceIn(0, 1)

            // Font stilleri için yardımcı fonksiyon
            fun createStyledText(text: String, isBold: Boolean): CharSequence {
                val spannable = android.text.SpannableString(text)
                if (isBold) {
                    spannable.setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, text.length, android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                } else {
                    // Light için hem StyleSpan hem de TypefaceSpan kullanıyoruz
                    spannable.setSpan(android.text.style.StyleSpan(android.graphics.Typeface.NORMAL), 0, text.length, android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                    spannable.setSpan(android.text.style.TypefaceSpan("sans-serif-light"), 0, text.length, android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
                return spannable
            }

            when (dateDisplayMode) {
                0 -> {
                    // Her ikisi
                    if (hijriDate.isNotEmpty()) {
                        views.setTextViewText(R.id.tv_hijri_date, createStyledText(hijriDate, hijriFontStyle == 1))
                        views.setViewVisibility(R.id.tv_hijri_date, android.view.View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.tv_hijri_date, android.view.View.GONE)
                    }
                    val gregorianText = gregorianDate.ifEmpty { "Yükleniyor..." }
                    views.setTextViewText(R.id.tv_gregorian_date, createStyledText(gregorianText, gregorianFontStyle == 1))
                    views.setViewVisibility(R.id.tv_gregorian_date, android.view.View.VISIBLE)
                }
                1 -> {
                    // Sadece Hicri
                    val hijriText = hijriDate.ifEmpty { "Yükleniyor..." }
                    views.setTextViewText(R.id.tv_hijri_date, createStyledText(hijriText, hijriFontStyle == 1))
                    views.setViewVisibility(R.id.tv_hijri_date, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.tv_gregorian_date, android.view.View.GONE)
                }
                2 -> {
                    // Sadece Miladi
                    views.setViewVisibility(R.id.tv_hijri_date, android.view.View.GONE)
                    val gregorianText = gregorianDate.ifEmpty { "Yükleniyor..." }
                    views.setTextViewText(R.id.tv_gregorian_date, createStyledText(gregorianText, gregorianFontStyle == 1))
                    views.setViewVisibility(R.id.tv_gregorian_date, android.view.View.VISIBLE)
                }
            }

            // Metin rengi: kullanıcı tercihi (0: Sistem, 1: Koyu, 2: Açık)
            // Her iki tarih de aynı renk tonunda olacak
            val textMode = prefsGetIntCompat(prefs, "${prefix}nv_text_color_mode",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_text_color_mode", 0)).coerceIn(0, 2)
            val dark = when (textMode) {
                1 -> false
                2 -> true
                else -> if (resolvedGradientMode == 2) {
                    isColorDark(resolvedAccentColor)
                } else {
                    isSystemInDarkMode(context)
                }
            }
            val textColor = if (dark) Color.parseColor("#FFFFFFFF") else Color.parseColor("#CC000000")
            views.setTextColor(R.id.tv_hijri_date, textColor)
            views.setTextColor(R.id.tv_gregorian_date, textColor)

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
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun requestThemeAwareRefresh(context: Context) {
            try {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
                if (ids != null && ids.isNotEmpty()) {
                    ids.forEach { updateAppWidget(context, mgr, it) }
                    val viewIds = intArrayOf(R.id.tv_hijri_date, R.id.tv_gregorian_date, R.id.bg_card_overlay, R.id.gradient_overlay)
                    viewIds.forEach { vId -> mgr.notifyAppWidgetViewDataChanged(ids, vId) }
                }
            } catch (_: Exception) {}
        }

        private fun isSystemInDarkMode(context: Context): Boolean {
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

        private fun generateCardOverlay(context: Context, alpha: Int, radiusDp: Int, width: Int, height: Int, bgMode: Int): Bitmap {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val density = context.resources.displayMetrics.density
            val radius = radiusDp.coerceAtLeast(0).toFloat() * density
            val isDark = when (bgMode) {
                1 -> false
                2 -> true
                else -> isSystemInDarkMode(context)
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
    }
}

