package com.osm.NamazVaktim

import android.content.Context
import android.content.SharedPreferences

/**
 * Widget'lar için çok dilli metin desteği sağlar.
 * Flutter tarafından kaydedilen locale bilgisini kullanarak metinleri çevirir.
 */
object WidgetLocalizationHelper {
    
    /**
     * SharedPreferences'tan locale bilgisini okur (varsayılan: 'tr')
     */
    fun getLocale(prefs: SharedPreferences): String {
        return prefs.getString("flutter.nv_widget_locale", "tr") ?: "tr"
    }
    
    /**
     * "Vakit hesaplanıyor" / "Calculating time" / "جاري حساب الوقت" metnini döndürür
     */
    fun getCalculatingTimeText(locale: String): String {
        return when (locale) {
            "en" -> "Calculating time"
            "ar" -> "جاري حساب الوقت"
            else -> "Vakit hesaplanıyor" // tr veya varsayılan
        }
    }
    
    /**
     * "vaktine" / "time" / "وقت" formatını döndürür
     */
    fun getNextPrayerTimeFormat(locale: String): String {
        return when (locale) {
            "en" -> "time"
            "ar" -> "وقت"
            else -> "vaktine" // tr veya varsayılan
        }
    }
    
    /**
     * Namaz ismini locale'e göre çevirir
     */
    fun getPrayerName(locale: String, prayerKey: String): String {
        return when (locale) {
            "en" -> when (prayerKey) {
                "İmsak" -> "Imsak"
                "Güneş" -> "Sunrise"
                "Öğle" -> "Zuhr"
                "İkindi" -> "Asr"
                "Akşam" -> "Maghrib"
                "Yatsı" -> "Isha"
                else -> prayerKey
            }
            "ar" -> when (prayerKey) {
                "İmsak" -> "الإمساك"
                "Güneş" -> "الشروق"
                "Öğle" -> "الظهر"
                "İkindi" -> "العصر"
                "Akşam" -> "المغرب"
                "Yatsı" -> "العشاء"
                else -> prayerKey
            }
            else -> prayerKey // tr veya varsayılan
        }
    }
    
    /**
     * "saat" / "hour" / "ساعة" metnini döndürür
     */
    fun getHourText(locale: String): String {
        return when (locale) {
            "en" -> "hour"
            "ar" -> "ساعة"
            else -> "saat" // tr veya varsayılan
        }
    }
    
    /**
     * "dakika" / "minute" / "دقيقة" metnini döndürür
     */
    fun getMinuteText(locale: String): String {
        return when (locale) {
            "en" -> "minute"
            "ar" -> "دقيقة"
            else -> "dakika" // tr veya varsayılan
        }
    }
    
    /**
     * "dk" / "min" / "د" metnini döndürür
     */
    fun getMinuteShortText(locale: String): String {
        return when (locale) {
            "en" -> "min"
            "ar" -> "د"
            else -> "dk" // tr veya varsayılan
        }
    }
    
    /**
     * "saniye" / "second" / "ثانية" metnini döndürür
     */
    fun getSecondText(locale: String): String {
        return when (locale) {
            "en" -> "second"
            "ar" -> "ثانية"
            else -> "saniye" // tr veya varsayılan
        }
    }
    
    /**
     * "Yükleniyor..." / "Loading..." / "جاري التحميل..." metnini döndürür
     */
    fun getLoadingText(locale: String): String {
        return when (locale) {
            "en" -> "Loading..."
            "ar" -> "جاري التحميل..."
            else -> "Yükleniyor..." // tr veya varsayılan
        }
    }
    
    /**
     * Sayıyı Arapça rakamlara çevirir (0-9 -> ٠-٩)
     */
    fun localizeNumerals(number: Int, locale: String): String {
        if (locale != "ar") {
            return number.toString()
        }
        
        val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        val numberStr = number.toString()
        val result = StringBuilder()
        
        for (char in numberStr) {
            if (char.isDigit()) {
                val digit = char.toString().toInt()
                result.append(arabicDigits[digit])
            } else {
                result.append(char)
            }
        }
        
        return result.toString()
    }
    
    /**
     * String içindeki sayıları Arapça rakamlara çevirir
     */
    fun localizeNumeralsInString(input: String, locale: String): String {
        if (locale != "ar") {
            return input
        }
        
        val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        val result = StringBuilder()
        
        for (char in input) {
            if (char.isDigit()) {
                val digit = char.toString().toInt()
                result.append(arabicDigits[digit])
            } else {
                result.append(char)
            }
        }
        
        return result.toString()
    }
    
    /**
     * Zaman formatını locale'e göre oluşturur
     * Örnek: "2saat 30dk" -> "2 hours 30 min" veya "٢ ساعة ٣٠ د"
     */
    fun formatTimeRemaining(
        locale: String,
        hours: Int,
        minutes: Int,
        seconds: Int
    ): String {
        val parts = mutableListOf<String>()
        
        if (hours > 0) {
            val hourText = getHourText(locale)
            val hoursStr = localizeNumerals(hours, locale)
            parts.add("$hoursStr$hourText")
        }
        
        if (minutes > 0) {
            val minuteText = if (hours > 0) {
                getMinuteShortText(locale)
            } else {
                getMinuteText(locale)
            }
            val minutesStr = localizeNumerals(minutes, locale)
            parts.add("$minutesStr$minuteText")
        }
        
        if (hours == 0 && minutes == 0 && seconds > 0) {
            val secondText = getSecondText(locale)
            val secondsStr = localizeNumerals(seconds, locale)
            parts.add("$secondsStr$secondText")
        }
        
        return parts.joinToString(" ")
    }
}

