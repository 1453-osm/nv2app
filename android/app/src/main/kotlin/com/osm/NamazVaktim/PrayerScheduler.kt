package com.osm.NamazVaktim

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

object PrayerScheduler {
	private const val TAG = "PrayerScheduler"

	private val baseNotificationCodes = mapOf(
		"imsak" to 101,
		"gunes" to 102,
		"ogle" to 103,
		"ikindi" to 104,
		"aksam" to 105,
		"yatsi" to 106,
		"cuma" to 107,
		"dua" to 108
	)

	private fun baseNotificationId(id: String): String = id.substringBefore('_')

	private fun variantIndex(id: String): Int {
		val idx = id.indexOf('_')
		if (idx == -1) return 0
		return id.substring(idx + 1).toIntOrNull() ?: 0
	}

	private fun discoverExtraIds(prefs: SharedPreferences, baseId: String): List<String> {
		val indices = mutableSetOf<Int>()
		val prefixes = listOf("flutter.nv_notif_${baseId}_", "nv_notif_${baseId}_")
		val enabledSuffix = "_enabled"
		for (key in prefs.all.keys) {
			for (prefix in prefixes) {
				if (key.startsWith(prefix) && key.endsWith(enabledSuffix)) {
					// Güvenli substring: prefix+suffix uzunluğu anahtarın sınırını aşmamalı
					if (key.length <= prefix.length + enabledSuffix.length) continue
					val raw = key.substring(prefix.length, key.length - enabledSuffix.length)
					val value = raw.toIntOrNull()
					if (value != null) {
						indices.add(value)
					}
				}
			}
		}
		return indices.sorted().map { "${baseId}_$it" }
	}

	data class PrayerTime(val id: String, val hour: Int, val minute: Int)

	fun scheduleAll(context: Context) {
		try {
			NotificationChannels.ensure(context)
			val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			fun fp(key: String): String? = try { flutterPrefs.getString("flutter.$key", null) } catch (_: Exception) { null }

			// Bugün vakitleri
			val fajr = fp("nv_fajr")
			val sunrise = fp("nv_sunrise")
			val dhuhr = fp("nv_dhuhr")
			val asr = fp("nv_asr")
			val maghrib = fp("nv_maghrib")
			val isha = fp("nv_isha")
			// Yarın vakitleri (varsa)
			val tomorrowFajr = fp("nv_tomorrow_fajr") ?: fp("nv_fajr_tomorrow")
			val tomorrowSunrise = fp("nv_tomorrow_sunrise") ?: fp("nv_sunrise_tomorrow")
			val tomorrowDhuhr = fp("nv_tomorrow_dhuhr") ?: fp("nv_dhuhr_tomorrow")
			val tomorrowAsr = fp("nv_tomorrow_asr") ?: fp("nv_asr_tomorrow")
			val tomorrowMaghrib = fp("nv_tomorrow_maghrib") ?: fp("nv_maghrib_tomorrow")
			val tomorrowIsha = fp("nv_tomorrow_isha") ?: fp("nv_isha_tomorrow")

			val list = mutableListOf<PrayerTime>()
			fun add(id: String, s: String?) {
				if (s.isNullOrEmpty()) return
				val parts = s.split(":")
				if (parts.size != 2) return
				val h = parts[0].toIntOrNull() ?: return
				val m = parts[1].toIntOrNull() ?: return
				list.add(PrayerTime(id, h, m))
			}
			add("imsak", fajr)
			add("gunes", sunrise)
			add("ogle", dhuhr)
			add("ikindi", asr)
			add("aksam", maghrib)
			add("yatsi", isha)

			val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

			fun scheduleSingle(id: String, hour: Int, minute: Int, dayOffset: Int) {
				val req = notifIdFor(id) + (dayOffset * 10)
				val cal = java.util.Calendar.getInstance().apply {
					add(java.util.Calendar.DAY_OF_YEAR, dayOffset)
					set(java.util.Calendar.HOUR_OF_DAY, hour)
					set(java.util.Calendar.MINUTE, minute)
					set(java.util.Calendar.SECOND, 0)
					set(java.util.Calendar.MILLISECOND, 0)
				}
				if (!isEnabled(context, id)) return
				val baseId = baseNotificationId(id)
				var minutesBefore = if (baseId == "dua") 0 else notifyMinutes(context, id)
				cal.add(java.util.Calendar.MINUTE, -minutesBefore)
				if (cal.timeInMillis <= System.currentTimeMillis()) return
				val soundId = soundIdFor(context, id)
				val prefsForText = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
				val title = if (baseId == "dua") {
					val fallbackTitle = prefsForText.readStringCompat("flutter.nv_dua_last_title", "nv_dua_last_title", titleFor(id))
					prefsForText.readStringCompat(
						"flutter.nv_dua_title_dayOffset_$dayOffset",
						"nv_dua_title_dayOffset_$dayOffset",
						fallbackTitle
					)
				} else {
					titleFor(id)
				}
				val text = if (baseId == "dua") {
					val fallbackBody = prefsForText.readStringCompat("flutter.nv_dua_last_body", "nv_dua_last_body", bodyFor(id, 0))
					prefsForText.readStringCompat(
						"flutter.nv_dua_body_dayOffset_$dayOffset",
						"nv_dua_body_dayOffset_$dayOffset",
						fallbackBody
					)
				} else {
					bodyFor(id, minutesBefore)
				}
				val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
					putExtra("title", title)
					putExtra("text", text)
					putExtra("soundId", soundId)
					putExtra("requestCode", req)
				}
				val pi = PendingIntent.getBroadcast(context, req, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
				if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
					am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
				} else {
					am.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
				}
			}

			fun scheduleGroup(baseId: String, hour: Int, minute: Int, dayOffset: Int) {
				scheduleSingle(baseId, hour, minute, dayOffset)
				val extras = discoverExtraIds(flutterPrefs, baseId)
				for (extraId in extras) {
					scheduleSingle(extraId, hour, minute, dayOffset)
				}
			}

			for (pt in list) scheduleGroup(pt.id, pt.hour, pt.minute, 0)
			// Yarın için mevcut olanları planla
			fun parse(s: String?): Pair<Int,Int>? {
				if (s.isNullOrEmpty()) return null
				val p = s.split(":"); if (p.size!=2) return null
				val h = p[0].toIntOrNull() ?: return null
				val m = p[1].toIntOrNull() ?: return null
				return h to m
			}
			parse(tomorrowFajr)?.let { scheduleGroup("imsak", it.first, it.second, 1) }
			parse(tomorrowSunrise)?.let { scheduleGroup("gunes", it.first, it.second, 1) }
			parse(tomorrowDhuhr)?.let { scheduleGroup("ogle", it.first, it.second, 1) }
			parse(tomorrowAsr)?.let { scheduleGroup("ikindi", it.first, it.second, 1) }
			parse(tomorrowMaghrib)?.let { scheduleGroup("aksam", it.first, it.second, 1) }
			parse(tomorrowIsha)?.let { scheduleGroup("yatsi", it.first, it.second, 1) }

			// Cuma özel bildirimi: bugünün öğlesi ve yarının öğlesi
			if (!dhuhr.isNullOrEmpty()) {
				val todayCal = java.util.Calendar.getInstance()
				if (todayCal.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY) {
					parse(dhuhr)?.let { scheduleGroup("cuma", it.first, it.second, 0) }
				}
			}
			if (!tomorrowDhuhr.isNullOrEmpty()) {
				val tomorrowCal = java.util.Calendar.getInstance().apply { add(java.util.Calendar.DAY_OF_YEAR, 1) }
				if (tomorrowCal.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY) {
					parse(tomorrowDhuhr)?.let { scheduleGroup("cuma", it.first, it.second, 1) }
				}
			}

			// Günlük dua bildirimi (10:00)
			scheduleGroup("dua", 10, 0, 0)
			scheduleGroup("dua", 10, 0, 1)
		} catch (e: Exception) {
			Log.e(TAG, "scheduleAll error", e)
		}
	}

	fun cancelAll(context: Context) {
		try {
			val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
			val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			for (baseId in baseNotificationCodes.keys) {
				val ids = mutableListOf(baseId)
				ids.addAll(discoverExtraIds(prefs, baseId))
				for (id in ids) {
					for (dayOffset in 0..1) {
						val req = notifIdFor(id) + (dayOffset * 10)
						val pi = PendingIntent.getBroadcast(context, req, Intent(context, PrayerAlarmReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
						am.cancel(pi)
					}
				}
			}
		} catch (_: Exception) {}
	}

	private fun notifIdFor(id: String): Int {
		val baseCode = baseNotificationCodes[baseNotificationId(id)] ?: 199
		return baseCode + (variantIndex(id) * 100)
	}

	private fun titleFor(id: String): String = when(baseNotificationId(id)) {
		"imsak" -> "\uD83C\uDF05 İmsak Vakti"
		"gunes" -> "☀️ Güneş Doğuşu"
		"ogle" -> "🕌 Öğle Namazı"
		"ikindi" -> "🕐 İkindi Namazı"
		"aksam" -> "🌇 Akşam Namazı"
		"yatsi" -> "🌙 Yatsı Namazı"
		"cuma" -> "🕌 Cuma Namazı"
		"dua" -> "\uD83E\uDD32 Günün Duası"
		else -> "🕌 Namaz Vakti"
	}

	private fun bodyFor(id: String, minutes: Int): String {
		val baseId = baseNotificationId(id)
		return if (minutes <= 0) when(baseId) {
			"imsak" -> "İmsak vakti girdi."
			"gunes" -> "Güneş doğdu!"
			"ogle" -> "Öğle namazı vakti girdi."
			"ikindi" -> "İkindi namazı vakti girdi."
			"aksam" -> "Akşam namazı vakti girdi."
			"yatsi" -> "Yatsı namazı vakti girdi."
			"cuma" -> "Cuma namazı vakti girdi."
			"dua" -> "Günün duası hazır."
			else -> "Namaz vakti girdi."
		} else when(baseId) {
			"imsak" -> "İmsak vaktine $minutes dakika kaldı."
			"gunes" -> "Güneş doğuşuna $minutes dakika kaldı."
			"ogle" -> "Öğle namazına $minutes dakika kaldı."
			"ikindi" -> "İkindi namazına $minutes dakika kaldı."
			"aksam" -> "Akşam namazına $minutes dakika kaldı."
			"yatsi" -> "Yatsı namazına $minutes dakika kaldı."
			"cuma" -> "Cuma namazına $minutes dakika kaldı."
			"dua" -> "Günün duasına $minutes dakika kaldı."
			else -> "$minutes dakika kaldı."
		}
	}

	private fun soundIdFor(context: Context, id: String): String {
		return try {
			val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			prefs.readStringCompat(
				"flutter.nv_notif_${id}_sound",
				"nv_notif_${id}_sound",
				"default"
			)
		} catch (_: Exception) { "default" }
	}

	private fun notifyMinutes(context: Context, id: String): Int {
		return try {
			val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			var minutes = prefs.readIntCompat(
				"flutter.nv_notif_${id}_minutes",
				"nv_notif_${id}_minutes",
				5
			)
			if (baseNotificationId(id) == "cuma" && minutes < 15) {
				minutes = 15
			}
			minutes
		} catch (_: Exception) { if (baseNotificationId(id) == "cuma") 15 else 5 }
	}

	@Suppress("SameParameterValue")
	private fun isEnabled(context: Context, id: String): Boolean {
		return try {
			val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			prefs.readBooleanCompat(
				"flutter.nv_notif_${id}_enabled",
				"nv_notif_${id}_enabled",
				true
			)
		} catch (_: Exception) { true }
	}

	private fun SharedPreferences.readIntCompat(primary: String, secondary: String?, fallback: Int): Int {
		val keys = listOfNotNull(primary, secondary)
		for (key in keys) {
			when (val value = all[key]) {
				is Int -> return value
				is Long -> return value.toInt()
				is String -> value.toIntOrNull()?.let { return it }
			}
		}
		return fallback
	}

	private fun SharedPreferences.readStringCompat(primary: String, secondary: String?, fallback: String): String {
		val keys = listOfNotNull(primary, secondary)
		for (key in keys) {
			val value = all[key]
			if (value is String && value.isNotBlank()) return value
		}
		return fallback
	}

	private fun SharedPreferences.readBooleanCompat(primary: String, secondary: String?, fallback: Boolean): Boolean {
		val keys = listOfNotNull(primary, secondary)
		for (key in keys) {
			when (val value = all[key]) {
				is Boolean -> return value
				is Int -> return value != 0
				is Long -> return value != 0L
				is String -> value.toBooleanStrictOrNull()?.let { return it }
			}
		}
		return fallback
	}
}



