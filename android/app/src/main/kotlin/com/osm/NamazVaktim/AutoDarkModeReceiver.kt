package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import java.util.*

class AutoDarkModeReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AutoDarkModeReceiver"
        
        // Namaz vakti renkleri (Constants.dart ile uyumlu)
        private val prayerColors = mapOf(
            "İmsak" to 0xFF121838L,
            "Güneş" to 0xFF865B5BL,
            "Öğle" to 0xFFD1AA48L,
            "İkindi" to 0xFFD2954FL,
            "Akşam" to 0xFF865B5BL,
            "Yatsı" to 0xFF212556L
        )
        private const val DEFAULT_COLOR = 0xFF588066L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "OnReceive: $action")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAutoDarkMode = try {
            val anyVal = prefs.all["flutter.auto_dark_mode"]
            when (anyVal) {
                is Boolean -> anyVal
                is String -> anyVal.toBoolean()
                else -> false
            }
        } catch (_: Exception) { false }
        
        if (!isAutoDarkMode) return

        val editor = prefs.edit()
        
        when (action) {
            "com.osm.NamazVaktim.ACTION_AUTO_DARK_NIGHT" -> {
                val currentMode = prefs.getString("flutter.theme_color_mode", "static")
                if (currentMode != "black") {
                   // Orijinal modu sakla
                   editor.putString("flutter.auto_dark_mode_original_theme_color_mode", currentMode)
                   // Siyah temaya geç
                   editor.putString("flutter.theme_color_mode", "black")
                   editor.putLong("flutter.current_theme_color", 0xFF000000L)
                   editor.apply()
                   
                   refreshWidgets(context)
                }
            }
            "com.osm.NamazVaktim.ACTION_AUTO_DARK_SUNRISE" -> {
                val originalMode = prefs.getString("flutter.auto_dark_mode_original_theme_color_mode", null)
                if (originalMode != null) {
                    editor.putString("flutter.theme_color_mode", originalMode)
                    
                    // Rengi geri yükle
                    val restoredColor = when (originalMode) {
                        "static" -> prefs.getLong("flutter.selected_theme_color", DEFAULT_COLOR)
                        "dynamic" -> calculateCurrentPrayerColor(prefs)
                        "system" -> prefs.getLong("flutter.selected_theme_color", DEFAULT_COLOR) // Sistem modu için de bir fallback
                        else -> DEFAULT_COLOR
                    }
                    
                    editor.putLong("flutter.current_theme_color", restoredColor)
                    editor.remove("flutter.auto_dark_mode_original_theme_color_mode")
                    editor.apply()
                    
                    refreshWidgets(context)
                }
            }
        }
    }

    private fun refreshWidgets(context: Context) {
        SmallPrayerWidgetProvider.requestThemeAwareRefresh(context)
        TextOnlyWidgetProvider.requestThemeAwareRefresh(context)
        CalendarWidgetProvider.requestThemeAwareRefresh(context)
    }

    private fun calculateCurrentPrayerColor(prefs: SharedPreferences): Long {
        val now = Calendar.getInstance()
        
        fun toToday(time: String?): Calendar? {
            if (time.isNullOrEmpty()) return null
            val parts = time.split(":")
            if (parts.size != 2) return null
            val c = now.clone() as Calendar
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            c.set(Calendar.HOUR_OF_DAY, parts[0].toIntOrNull() ?: return null)
            c.set(Calendar.MINUTE, parts[1].toIntOrNull() ?: return null)
            return c
        }

        val fajr = toToday(prefs.getString("flutter.nv_fajr", null))
        val sunrise = toToday(prefs.getString("flutter.nv_sunrise", null))
        val dhuhr = toToday(prefs.getString("flutter.nv_dhuhr", null))
        val asr = toToday(prefs.getString("flutter.nv_asr", null))
        val maghrib = toToday(prefs.getString("flutter.nv_maghrib", null))
        val isha = toToday(prefs.getString("flutter.nv_isha", null))

        val sequence = listOf(
            "İmsak" to fajr,
            "Güneş" to sunrise,
            "Öğle" to dhuhr,
            "İkindi" to asr,
            "Akşam" to maghrib,
            "Yatsı" to isha
        )

        var foundColor = prayerColors["Yatsı"] ?: DEFAULT_COLOR
        for (i in sequence.indices) {
            val (name, cal) = sequence[i]
            if (cal != null && now.before(cal)) {
                // Mevcut vakit bir önceki vakittir
                val prevIndex = if (i == 0) sequence.size - 1 else i - 1
                foundColor = prayerColors[sequence[prevIndex].first] ?: DEFAULT_COLOR
                return foundColor
            }
        }
        
        // Eğer hiçbirinden önce değilse (yatsı sonrası), yatsı rengi döner
        return prayerColors["Yatsı"] ?: DEFAULT_COLOR
    }
}
