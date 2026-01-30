package com.osm.NamazVaktim

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel

/**
 * Widget yapılandırma ViewModel'i (MVVM mimarisi)
 * Widget ayarlarını yönetir ve SharedPreferences üzerinden kaydeder.
 */
class WidgetConfigureViewModel : ViewModel() {
    
    /**
     * Widget türü enum'ı
     */
    enum class WidgetType {
        SMALL,      // SmallPrayerWidgetProvider
        TEXT_ONLY,  // TextOnlyWidgetProvider
        CALENDAR    // CalendarWidgetProvider
    }
    
    /**
     * Widget türünü widget ID'den belirler
     */
    fun getWidgetType(context: Context, appWidgetId: Int): WidgetType {
        val manager = AppWidgetManager.getInstance(context)
        
        // Widget ID'nin hangi provider'a ait olduğunu kontrol et
        val smallIds = manager.getAppWidgetIds(ComponentName(context, SmallPrayerWidgetProvider::class.java))
        if (smallIds.contains(appWidgetId)) {
            return WidgetType.SMALL
        }
        
        val textOnlyIds = manager.getAppWidgetIds(ComponentName(context, TextOnlyWidgetProvider::class.java))
        if (textOnlyIds.contains(appWidgetId)) {
            return WidgetType.TEXT_ONLY
        }
        
        val calendarIds = manager.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
        if (calendarIds.contains(appWidgetId)) {
            return WidgetType.CALENDAR
        }
        
        // Varsayılan olarak SMALL döndür
        return WidgetType.SMALL
    }
    
    /**
     * Widget ayarlarını kaydeder
     */
    fun saveWidgetSettings(
        context: Context,
        appWidgetId: Int,
        widgetType: WidgetType,
        cardOpacity: Int,           // 0-255
        gradientMode: Int,          // 0: Kapalı, 1: Gradyan, 2: Renkli
        cardRadius: Int,            // 0-120 dp
        textColorMode: Int,         // 0: Sistem, 1: Koyu, 2: Açık
        bgColorMode: Int,           // 0: Sistem, 1: Açık, 2: Koyu
        // Calendar Specific
        dateDisplayMode: Int = 0,   // 0: Her ikisi, 1: Hicri, 2: Miladi
        hijriFontStyle: Int = 0,    // 0: Normal, 1: Bold
        gregorianFontStyle: Int = 1,// 0: Normal, 1: Bold
        // TextOnly Specific
        textSizePct: Int = 100      // 80-140 arası yüzdelik değer
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Widget-specific ayarları kaydet (widget ID ile prefix)
        // Her widget kendi ayarlarına sahip olur, global ayarlar sadece varsayılan olarak kullanılır
        val prefix = "widget_${appWidgetId}_"
        
        editor.putInt("${prefix}nv_card_alpha", cardOpacity.coerceIn(0, 255))
        editor.putInt("${prefix}nv_gradient_mode", gradientMode.coerceIn(0, 2))
        editor.putInt("${prefix}nv_card_radius_dp", cardRadius.coerceIn(0, 120))
        editor.putInt("${prefix}nv_text_color_mode", textColorMode.coerceIn(0, 2))
        editor.putInt("${prefix}nv_bg_color_mode", bgColorMode.coerceIn(0, 2))
        
        if (widgetType == WidgetType.CALENDAR) {
            editor.putInt("${prefix}nv_calendar_display_mode", dateDisplayMode.coerceIn(0, 2))
            editor.putInt("${prefix}nv_calendar_hijri_font_style", hijriFontStyle.coerceIn(0, 1))
            editor.putInt("${prefix}nv_calendar_gregorian_font_style", gregorianFontStyle.coerceIn(0, 1))
        }
        
        if (widgetType == WidgetType.TEXT_ONLY) {
            editor.putInt("${prefix}nv_text_scale_pct", textSizePct.coerceIn(80, 140))
        }
        
        editor.apply()
    }
    
    /**
     * Mevcut widget ayarlarını yükler
     */
    fun loadWidgetSettings(
        context: Context,
        appWidgetId: Int,
        widgetType: WidgetType? = null // İsteğe bağlı, eğer verilirse daha doğru fallback yapar
    ): WidgetSettings {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val prefix = "widget_${appWidgetId}_"
        
        // Widget türüne göre varsayılan anahtarları belirle
        // Eğer widgetType null ise (eski kullanım), varsayılan olarak generic keyleri kullanırız
        // Ancak Calendar için özel fallback keyleri var
        val isCalendar = widgetType == WidgetType.CALENDAR || 
                         (widgetType == null && getWidgetType(context, appWidgetId) == WidgetType.CALENDAR)
        
        val fallbackPrefix = if (isCalendar) "flutter.nv_calendar_" else "flutter.nv_"
        
        val textSizePct = prefsGetIntCompat(prefs, "${prefix}nv_text_scale_pct",
            prefsGetIntCompat(prefs, "flutter.nv_textonly_text_scale_pct", 100))
        
        return WidgetSettings(
            cardOpacity = prefsGetIntCompat(prefs, "${prefix}nv_card_alpha", 
                prefsGetIntCompat(prefs, "${fallbackPrefix}card_alpha", 204)),
            gradientMode = prefsGetIntCompat(prefs, "${prefix}nv_gradient_mode",
                prefsGetIntCompat(prefs, "${fallbackPrefix}gradient_mode", 1)),
            cardRadius = prefsGetIntCompat(prefs, "${prefix}nv_card_radius_dp",
                prefsGetIntCompat(prefs, "${fallbackPrefix}card_radius_dp", 75)),
            textColorMode = prefsGetIntCompat(prefs, "${prefix}nv_text_color_mode",
                prefsGetIntCompat(prefs, "${fallbackPrefix}text_color_mode", 0)),
            bgColorMode = prefsGetIntCompat(prefs, "${prefix}nv_bg_color_mode",
                prefsGetIntCompat(prefs, "${fallbackPrefix}bg_color_mode", 0)),
            
            // Calendar Specific
            dateDisplayMode = prefsGetIntCompat(prefs, "${prefix}nv_calendar_display_mode",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_display_mode", 0)),
            hijriFontStyle = prefsGetIntCompat(prefs, "${prefix}nv_calendar_hijri_font_style",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_hijri_font_style", 0)),
            gregorianFontStyle = prefsGetIntCompat(prefs, "${prefix}nv_calendar_gregorian_font_style",
                prefsGetIntCompat(prefs, "flutter.nv_calendar_gregorian_font_style", 1)),
                
            // TextOnly Specific
            textSizePct = textSizePct.coerceIn(80, 140)
        )
    }
    
    /**
     * SharedPreferences'tan Int değer okuma (uyumluluk için)
     */
    private fun prefsGetIntCompat(prefs: SharedPreferences, key: String, def: Int): Int {
        val anyVal = prefs.all[key] ?: return def
        return when (anyVal) {
            is Int -> anyVal
            is Long -> anyVal.toInt()
            is String -> runCatching { anyVal.toInt() }.getOrElse { def }
            else -> def
        }
    }
    
    /**
     * Widget ayarları data class'ı
     */
    data class WidgetSettings(
        val cardOpacity: Int = 204,
        val gradientMode: Int = 1,
        val cardRadius: Int = 75,
        val textColorMode: Int = 0,
        val bgColorMode: Int = 0,
        // Calendar Specific
        val dateDisplayMode: Int = 0,
        val hijriFontStyle: Int = 0,
        val gregorianFontStyle: Int = 1,
        // TextOnly Specific
        val textSizePct: Int = 100 // 80-140 arası yüzdelik değer
    )
}
