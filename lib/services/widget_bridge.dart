import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Android ana ekran küçük widget'ı ile köprü.
/// MVVM: ViewModel'ler bu servis üzerinden değerleri kaydeder/günceller.
class WidgetBridgeService {
  static const MethodChannel _channel = MethodChannel('com.osm.namazvaktim/widgets');

  /// Flutter tarafındaki son verileri SharedPreferences'a yazar ki widget okuyabilsin.
  static Future<void> saveWidgetData({
    required String nextPrayerName,
    required String countdownText,
    required int currentThemeColor,
    required int selectedThemeColor,
    required int nextEpochMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nv_next_prayer_name', nextPrayerName);
    await prefs.setString('nv_countdown_text', countdownText);
    await prefs.setString('nv_next_epoch_ms', nextEpochMs.toString());
    // Renkleri Long olarak yazalım ki native taraf Long/Int farkına takılmasın
    await prefs.setInt('current_theme_color', currentThemeColor);
    await prefs.setInt('selected_theme_color', selectedThemeColor);
    // FlutterSharedPreferences anahtar adlandırması için 'flutter.' prefix otomatik eklenir
    // Otomatik arka plan: Son kullanılan duvar kağıdının küçük bir önbelleğini sakla (opsiyonel)
    // Not: Native taraf zaten sistem duvar kağıdını direkt okuyacak. Bu alan yalnızca cihaz kısıtında fallback içindir.
  }

  /// Küçük widget kart opaklığını (0.0 - 1.0) kaydeder.
  /// Native taraf `flutter.nv_card_alpha` anahtarını 0..255 arası okur.
  static Future<void> setWidgetCardOpacity(double opacity01) async {
    final prefs = await SharedPreferences.getInstance();
    final double clamped = opacity01.clamp(0.0, 1.0);
    final int alpha = (clamped * 255).round();
    await prefs.setInt('nv_card_alpha', alpha);
  }

  /// Küçük widget gradyan görünürlüğünü kaydeder.
  static Future<void> setWidgetGradientEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nv_gradient_on', enabled);
  }

  /// Küçük widget köşe yarıçapını dp cinsinden kaydeder (0 - 120).
  static Future<void> setWidgetCardRadiusDp(int radiusDp) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = radiusDp.clamp(0, 120);
    await prefs.setInt('nv_card_radius_dp', clamped);
  }

  /// Küçük widget metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setSmallWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_text_color_mode', mode.clamp(0, 2));
  }

  static Future<int> getSmallWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_text_color_mode') ?? 0).clamp(0, 2);
  }

  /// Küçük widget arka plan rengi modu (0: Sistem, 1: Açık, 2: Koyu)
  static Future<void> setWidgetBackgroundColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_bg_color_mode', mode.clamp(0, 2));
  }

  static Future<int> getWidgetBackgroundColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_bg_color_mode') ?? 0).clamp(0, 2);
  }

  /// Mevcut kart opaklığını 0.0 - 1.0 aralığında döndürür (varsayılan 204/255 ~ 0.8)
  static Future<double> getWidgetCardOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    final int alpha = prefs.getInt('nv_card_alpha') ?? 204;
    return (alpha.clamp(0, 255)) / 255.0;
  }

  /// Mevcut gradyan açık/kapalı durumu (varsayılan true)
  static Future<bool> getWidgetGradientEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('nv_gradient_on') ?? true;
  }

  /// Mevcut kart köşe yarıçapını dp cinsinden döndürür (varsayılan 75)
  static Future<int> getWidgetCardRadiusDp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('nv_card_radius_dp') ?? 75;
  }

  static Future<void> forceUpdateSmallWidget() async {
    try {
      await _channel.invokeMethod('updateSmallWidget');
    } catch (_) {}
  }

  // --- Text-only widget pin/state ---
  static Future<bool> requestPinTextWidget() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('requestPinTextWidget') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isTextWidgetPinned() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('isTextWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // Sadece metin widget'ında metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setTextOnlyWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_textonly_text_color_mode', mode.clamp(0, 2));
    await forceUpdateSmallWidget();
  }

  static Future<int> getTextOnlyWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_textonly_text_color_mode') ?? 0).clamp(0, 2);
  }

  /// Metin-only widget metin boyutu ölçeği yüzde (80..140). 100 varsayılan.
  static Future<void> setTextOnlyWidgetTextScalePercent(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = percent.clamp(80, 140);
    await prefs.setInt('nv_textonly_text_scale_pct', clamped);
    await forceUpdateSmallWidget();
  }

  static Future<int> getTextOnlyWidgetTextScalePercent() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_textonly_text_scale_pct') ?? 100).clamp(80, 140);
  }

  // Kullanıcıdan alınan bir görseli widget için kaydet (bytes olarak)
  static Future<void> saveWidgetBackgroundBytes(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final String b64 = base64Encode(bytes);
    await prefs.setString('nv_bg_image_b64', b64);
  }

  // Dosya yolu kaydetmek istenirse
  static Future<void> saveWidgetBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nv_bg_image_path', path);
  }

  static Future<void> clearWidgetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nv_bg_image_b64');
    await prefs.remove('nv_bg_image_path');
  }

  static Future<void> requestExactAlarmPermission() async {
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  static Future<bool> isExactAlarmAllowed() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('isExactAlarmAllowed') ?? true;
      return ok;
    } catch (_) {
      return true;
    }
  }

  // Pil optimizasyonu durumu
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<void> savePrayerTimesForWidget({
    required String todayIso, // yyyy-MM-dd
    required String fajr,
    required String sunrise,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    // Yedek/ileri gün desteği
    String? tomorrowDateIso,
    String? tomorrowFajr,
    String? tomorrowSunrise,
    String? tomorrowDhuhr,
    String? tomorrowAsr,
    String? tomorrowMaghrib,
    String? tomorrowIsha,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nv_today_date_iso', todayIso);
    await prefs.setString('nv_fajr', fajr);
    await prefs.setString('nv_sunrise', sunrise);
    await prefs.setString('nv_dhuhr', dhuhr);
    await prefs.setString('nv_asr', asr);
    await prefs.setString('nv_maghrib', maghrib);
    await prefs.setString('nv_isha', isha);
    // Yarın için tüm vakitler (varsa)
    if (tomorrowDateIso != null && tomorrowDateIso.isNotEmpty) {
      await prefs.setString('nv_tomorrow_date_iso', tomorrowDateIso);
    }
    if (tomorrowFajr != null && tomorrowFajr.isNotEmpty) {
      await prefs.setString('nv_tomorrow_fajr', tomorrowFajr);
      await prefs.setString('nv_fajr_tomorrow', tomorrowFajr);
    }
    if (tomorrowSunrise != null && tomorrowSunrise.isNotEmpty) {
      await prefs.setString('nv_sunrise_tomorrow', tomorrowSunrise);
    }
    if (tomorrowDhuhr != null && tomorrowDhuhr.isNotEmpty) {
      await prefs.setString('nv_dhuhr_tomorrow', tomorrowDhuhr);
    }
    if (tomorrowAsr != null && tomorrowAsr.isNotEmpty) {
      await prefs.setString('nv_asr_tomorrow', tomorrowAsr);
    }
    if (tomorrowMaghrib != null && tomorrowMaghrib.isNotEmpty) {
      await prefs.setString('nv_maghrib_tomorrow', tomorrowMaghrib);
    }
    if (tomorrowIsha != null && tomorrowIsha.isNotEmpty) {
      await prefs.setString('nv_isha_tomorrow', tomorrowIsha);
    }
  }

  static Future<bool> requestPinSmallWidget() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('requestPinSmallWidget') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSmallWidgetPinned() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('isSmallWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // --- Alarm köprüsü ---
  static Future<bool> scheduleExactAlarm({
    required int epochMillis,
    required String title,
    required String text,
    required String soundId,
    required int requestCode,
  }) async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('scheduleExactAlarm', {
        'epochMillis': epochMillis,
        'title': title,
        'text': text,
        'soundId': soundId,
        'requestCode': requestCode,
      }) ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancelExactAlarm({required int requestCode}) async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('cancelExactAlarm', {
        'requestCode': requestCode,
      }) ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // --- Takvim Widget ---
  /// Takvim widget için tarih verilerini kaydeder
  static Future<void> saveCalendarWidgetData({
    required String hijriDate,
    required String gregorianDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nv_calendar_hijri_date', hijriDate);
    await prefs.setString('nv_calendar_gregorian_date', gregorianDate);
  }

  /// Takvim widget kart opaklığını (0.0 - 1.0) kaydeder
  static Future<void> setCalendarWidgetCardOpacity(double opacity01) async {
    final prefs = await SharedPreferences.getInstance();
    final double clamped = opacity01.clamp(0.0, 1.0);
    final int alpha = (clamped * 255).round();
    await prefs.setInt('nv_calendar_card_alpha', alpha);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget gradyan görünürlüğünü kaydeder
  static Future<void> setCalendarWidgetGradientEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nv_calendar_gradient_on', enabled);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget köşe yarıçapını dp cinsinden kaydeder (0 - 120)
  static Future<void> setCalendarWidgetCardRadiusDp(int radiusDp) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = radiusDp.clamp(0, 120);
    await prefs.setInt('nv_calendar_card_radius_dp', clamped);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget tarih gösterim modu (0: Her ikisi, 1: Sadece Hicri, 2: Sadece Miladi)
  static Future<void> setCalendarWidgetDisplayMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_calendar_display_mode', mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setCalendarWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_calendar_text_color_mode', mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget arka plan rengi modu (0: Sistem, 1: Açık, 2: Koyu)
  static Future<void> setCalendarWidgetBackgroundColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_calendar_bg_color_mode', mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget'i güncelle
  static Future<void> forceUpdateCalendarWidget() async {
    try {
      await _channel.invokeMethod('updateCalendarWidget');
    } catch (_) {}
  }

  /// Takvim widget pin durumu kontrolü
  static Future<bool> requestPinCalendarWidget() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('requestPinCalendarWidget') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isCalendarWidgetPinned() async {
    try {
      final bool ok = await _channel.invokeMethod<bool>('isCalendarWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Takvim widget ayarları get metodları
  static Future<double> getCalendarWidgetCardOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    final int alpha = prefs.getInt('nv_calendar_card_alpha') ?? 204;
    return (alpha.clamp(0, 255)) / 255.0;
  }

  static Future<bool> getCalendarWidgetGradientEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('nv_calendar_gradient_on') ?? true;
  }

  static Future<int> getCalendarWidgetCardRadiusDp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('nv_calendar_card_radius_dp') ?? 75;
  }

  static Future<int> getCalendarWidgetDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_calendar_display_mode') ?? 0).clamp(0, 2);
  }

  static Future<int> getCalendarWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_calendar_text_color_mode') ?? 0).clamp(0, 2);
  }

  static Future<int> getCalendarWidgetBackgroundColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_calendar_bg_color_mode') ?? 0).clamp(0, 2);
  }

  /// Takvim widget hicri tarih font stili (0: Light, 1: Bold)
  static Future<void> setCalendarWidgetHijriFontStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_calendar_hijri_font_style', style.clamp(0, 1));
    await forceUpdateCalendarWidget();
  }

  static Future<int> getCalendarWidgetHijriFontStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_calendar_hijri_font_style') ?? 0).clamp(0, 1);
  }

  /// Takvim widget miladi tarih font stili (0: Light, 1: Bold)
  static Future<void> setCalendarWidgetGregorianFontStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nv_calendar_gregorian_font_style', style.clamp(0, 1));
    await forceUpdateCalendarWidget();
  }

  static Future<int> getCalendarWidgetGregorianFontStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('nv_calendar_gregorian_font_style') ?? 1).clamp(0, 1);
  }
}


