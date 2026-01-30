import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_keys.dart';

/// Android ana ekran küçük widget'ı ile köprü.
/// MVVM: ViewModel'ler bu servis üzerinden değerleri kaydeder/günceller.
/// Not: iOS'ta widget ve platform-specific metodlar desteklenmez, sessizce atlanır.
class WidgetBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.osm.namazvaktim/widgets');

  /// iOS'ta widget ve MethodChannel işlevleri desteklenmez
  static bool get _isIOSPlatform => Platform.isIOS;

  /// Flutter tarafındaki son verileri SharedPreferences'a yazar ki widget okuyabilsin.
  /// iOS'ta MethodChannel üzerinden App Groups'a yazar.
  static Future<void> saveWidgetData({
    required String nextPrayerName,
    required String countdownText,
    required int currentThemeColor,
    required int selectedThemeColor,
    required int nextEpochMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.widgetNextPrayerName, nextPrayerName);
    await prefs.setString(AppKeys.widgetCountdownText, countdownText);
    await prefs.setString(AppKeys.widgetNextEpochMs, nextEpochMs.toString());
    // Renkleri Long olarak yazalım ki native taraf Long/Int farkına takılmasın
    await prefs.setInt(AppKeys.widgetCurrentThemeColor, currentThemeColor);
    await prefs.setInt(AppKeys.widgetSelectedThemeColor, selectedThemeColor);

    // iOS için App Groups üzerinden widget'lara veri gönder
    if (_isIOSPlatform) {
      try {
        final locale = prefs.getString(AppKeys.widgetLocale) ?? 'tr';
        await _channel.invokeMethod('saveWidgetData', {
          'nextPrayerName': nextPrayerName,
          'countdownText': countdownText,
          'nextEpochMs': nextEpochMs,
          'currentThemeColor': currentThemeColor,
          'locale': locale,
        });
      } catch (_) {}
    }
  }

  /// Widget için locale bilgisini kaydeder (Android widget'ları çeviri için kullanacak).
  static Future<void> saveWidgetLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.widgetLocale, localeCode);
  }

  /// Küçük widget kart opaklığını (0.0 - 1.0) kaydeder.
  /// Native taraf `flutter.nv_card_alpha` anahtarını 0..255 arası okur.
  static Future<void> setWidgetCardOpacity(double opacity01) async {
    final prefs = await SharedPreferences.getInstance();
    final double clamped = opacity01.clamp(0.0, 1.0);
    final int alpha = (clamped * 255).round();
    await prefs.setInt(AppKeys.widgetCardAlpha, alpha);
  }

  /// Küçük widget gradyan görünürlüğünü kaydeder.
  static Future<void> setWidgetGradientEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.widgetGradientOn, enabled);
  }

  /// Küçük widget köşe yarıçapını dp cinsinden kaydeder (0 - 120).
  static Future<void> setWidgetCardRadiusDp(int radiusDp) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = radiusDp.clamp(0, 120);
    await prefs.setInt(AppKeys.widgetCardRadiusDp, clamped);
  }

  /// Küçük widget metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setSmallWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.widgetTextColorMode, mode.clamp(0, 2));
  }

  static Future<int> getSmallWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.widgetTextColorMode) ?? 0).clamp(0, 2);
  }

  /// Küçük widget arka plan rengi modu (0: Sistem, 1: Açık, 2: Koyu)
  static Future<void> setWidgetBackgroundColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.widgetBgColorMode, mode.clamp(0, 2));
  }

  static Future<int> getWidgetBackgroundColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.widgetBgColorMode) ?? 0).clamp(0, 2);
  }

  /// Mevcut kart opaklığını 0.0 - 1.0 aralığında döndürür (varsayılan 204/255 ~ 0.8)
  static Future<double> getWidgetCardOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    final int alpha = prefs.getInt(AppKeys.widgetCardAlpha) ?? 204;
    return (alpha.clamp(0, 255)) / 255.0;
  }

  /// Mevcut gradyan açık/kapalı durumu (varsayılan true)
  static Future<bool> getWidgetGradientEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.widgetGradientOn) ?? true;
  }

  /// Mevcut kart köşe yarıçapını dp cinsinden döndürür (varsayılan 75)
  static Future<int> getWidgetCardRadiusDp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppKeys.widgetCardRadiusDp) ?? 75;
  }

  static Future<void> forceUpdateSmallWidget() async {
    try {
      await _channel.invokeMethod('updateSmallWidget');
    } catch (_) {}
  }

  /// iOS için tüm widget'ları yeniden yükle (WidgetKit.reloadAllTimelines)
  static Future<void> reloadAllIOSWidgets() async {
    if (!_isIOSPlatform) return;
    try {
      await _channel.invokeMethod('reloadAllWidgets');
    } catch (_) {}
  }

  // --- Text-only widget pin/state ---
  static Future<bool> requestPinTextWidget() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('requestPinTextWidget') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isTextWidgetPinned() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('isTextWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // Sadece metin widget'ında metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setTextOnlyWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.textOnlyWidgetTextColorMode, mode.clamp(0, 2));
    await forceUpdateSmallWidget();
  }

  static Future<int> getTextOnlyWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.textOnlyWidgetTextColorMode) ?? 0).clamp(0, 2);
  }

  /// Metin-only widget metin boyutu ölçeği yüzde (80..140). 100 varsayılan.
  static Future<void> setTextOnlyWidgetTextScalePercent(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = percent.clamp(80, 140);
    await prefs.setInt(AppKeys.textOnlyWidgetTextScalePct, clamped);
    await forceUpdateSmallWidget();
  }

  static Future<int> getTextOnlyWidgetTextScalePercent() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.textOnlyWidgetTextScalePct) ?? 100).clamp(80, 140);
  }

  // Kullanıcıdan alınan bir görseli widget için kaydet (bytes olarak)
  static Future<void> saveWidgetBackgroundBytes(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final String b64 = base64Encode(bytes);
    await prefs.setString(AppKeys.widgetBgImageB64, b64);
  }

  // Dosya yolu kaydetmek istenirse
  static Future<void> saveWidgetBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.widgetBgImagePath, path);
  }

  static Future<void> clearWidgetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppKeys.widgetBgImageB64);
    await prefs.remove(AppKeys.widgetBgImagePath);
  }

  static Future<void> requestExactAlarmPermission() async {
    if (_isIOSPlatform) return; // iOS'ta kesin alarm izni gerekmez
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  static Future<bool> isExactAlarmAllowed() async {
    if (_isIOSPlatform) return true; // iOS'ta her zaman izinli sayılır
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('isExactAlarmAllowed') ?? true;
      return ok;
    } catch (_) {
      return true;
    }
  }

  /// Notification Policy erişimi mevcut mu? (Android M+)
  /// iOS'ta bu özellik desteklenmez, her zaman true döner
  static Future<bool> isNotificationPolicyAccessGranted() async {
    if (_isIOSPlatform)
      return true; // iOS'ta DND kontrolü Flutter'dan yapılamaz
    try {
      final bool ok = await _channel
              .invokeMethod<bool>('isNotificationPolicyAccessGranted') ??
          false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Notification Policy erişimi iste (Android M+ ayar sayfasına yönlendirir)
  /// iOS'ta bu özellik desteklenmez
  static Future<void> requestNotificationPolicyAccess() async {
    if (_isIOSPlatform) return; // iOS'ta DND kontrolü Flutter'dan yapılamaz
    try {
      await _channel.invokeMethod('requestNotificationPolicyAccess');
    } catch (_) {
      // Hata durumunda sessizce geç
    }
  }

  // Pil optimizasyonu durumu (Android-only)
  // iOS'ta bu özellik desteklenmez, her zaman true döner
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (_isIOSPlatform) return true; // iOS'ta pil optimizasyonu kontrolü yok
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
              false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (_isIOSPlatform) return true; // iOS'ta pil optimizasyonu kontrolü yok
    try {
      final bool ok = await _channel
              .invokeMethod<bool>('requestIgnoreBatteryOptimizations') ??
          false;
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
    await prefs.setString(AppKeys.widgetTodayDateIso, todayIso);
    await prefs.setString(AppKeys.prayerFajr, fajr);
    await prefs.setString(AppKeys.prayerSunrise, sunrise);
    await prefs.setString(AppKeys.prayerDhuhr, dhuhr);
    await prefs.setString(AppKeys.prayerAsr, asr);
    await prefs.setString(AppKeys.prayerMaghrib, maghrib);
    await prefs.setString(AppKeys.prayerIsha, isha);
    // Yarın için tüm vakitler (varsa)
    if (tomorrowDateIso != null && tomorrowDateIso.isNotEmpty) {
      await prefs.setString(AppKeys.widgetTomorrowDateIso, tomorrowDateIso);
    }
    if (tomorrowFajr != null && tomorrowFajr.isNotEmpty) {
      await prefs.setString(AppKeys.widgetTomorrowFajr, tomorrowFajr);
      await prefs.setString(AppKeys.widgetFajrTomorrow, tomorrowFajr);
    }
    if (tomorrowSunrise != null && tomorrowSunrise.isNotEmpty) {
      await prefs.setString(AppKeys.widgetSunriseTomorrow, tomorrowSunrise);
    }
    if (tomorrowDhuhr != null && tomorrowDhuhr.isNotEmpty) {
      await prefs.setString(AppKeys.widgetDhuhrTomorrow, tomorrowDhuhr);
    }
    if (tomorrowAsr != null && tomorrowAsr.isNotEmpty) {
      await prefs.setString(AppKeys.widgetAsrTomorrow, tomorrowAsr);
    }
    if (tomorrowMaghrib != null && tomorrowMaghrib.isNotEmpty) {
      await prefs.setString(AppKeys.widgetMaghribTomorrow, tomorrowMaghrib);
    }
    if (tomorrowIsha != null && tomorrowIsha.isNotEmpty) {
      await prefs.setString(AppKeys.widgetIshaTomorrow, tomorrowIsha);
    }
  }

  static Future<bool> requestPinSmallWidget() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('requestPinSmallWidget') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSmallWidgetPinned() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('isSmallWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // --- Alarm köprüsü (Android-only) ---
  // iOS'ta flutter_local_notifications kendi planlamasını yapar
  static Future<bool> scheduleExactAlarm({
    required int epochMillis,
    required String title,
    required String text,
    required String soundId,
    required int requestCode,
    String? notificationId,
  }) async {
    if (_isIOSPlatform)
      return true; // iOS'ta zaten flutter_local_notifications kullanılır
    try {
      final bool ok = await _channel.invokeMethod<bool>('scheduleExactAlarm', {
            'epochMillis': epochMillis,
            'title': title,
            'text': text,
            'soundId': soundId,
            'requestCode': requestCode,
            'notificationId': notificationId,
          }) ??
          false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancelExactAlarm({required int requestCode}) async {
    if (_isIOSPlatform) return true; // iOS'ta bu metod kullanılmaz
    try {
      final bool ok = await _channel.invokeMethod<bool>('cancelExactAlarm', {
            'requestCode': requestCode,
          }) ??
          false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  // --- Takvim Widget ---
  /// Takvim widget için tarih verilerini kaydeder
  /// iOS'ta MethodChannel üzerinden App Groups'a yazar.
  static Future<void> saveCalendarWidgetData({
    required String hijriDate,
    required String gregorianDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppKeys.calendarWidgetHijriDate, hijriDate);
    await prefs.setString(AppKeys.calendarWidgetGregorianDate, gregorianDate);

    // iOS için App Groups üzerinden widget'lara veri gönder
    if (_isIOSPlatform) {
      try {
        await _channel.invokeMethod('saveCalendarData', {
          'hijriDate': hijriDate,
          'gregorianDate': gregorianDate,
        });
      } catch (_) {}
    }
  }

  /// Takvim widget kart opaklığını (0.0 - 1.0) kaydeder
  static Future<void> setCalendarWidgetCardOpacity(double opacity01) async {
    final prefs = await SharedPreferences.getInstance();
    final double clamped = opacity01.clamp(0.0, 1.0);
    final int alpha = (clamped * 255).round();
    await prefs.setInt(AppKeys.calendarWidgetCardAlpha, alpha);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget gradyan görünürlüğünü kaydeder
  static Future<void> setCalendarWidgetGradientEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.calendarWidgetGradientOn, enabled);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget köşe yarıçapını dp cinsinden kaydeder (0 - 120)
  static Future<void> setCalendarWidgetCardRadiusDp(int radiusDp) async {
    final prefs = await SharedPreferences.getInstance();
    final int clamped = radiusDp.clamp(0, 120);
    await prefs.setInt(AppKeys.calendarWidgetCardRadiusDp, clamped);
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget tarih gösterim modu (0: Her ikisi, 1: Sadece Hicri, 2: Sadece Miladi)
  static Future<void> setCalendarWidgetDisplayMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.calendarWidgetDisplayMode, mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget metin rengi modu (0: Sistem, 1: Koyu, 2: Açık)
  static Future<void> setCalendarWidgetTextColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.calendarWidgetTextColorMode, mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget arka plan rengi modu (0: Sistem, 1: Açık, 2: Koyu)
  static Future<void> setCalendarWidgetBackgroundColorMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.calendarWidgetBgColorMode, mode.clamp(0, 2));
    await forceUpdateCalendarWidget();
  }

  /// Takvim widget'i güncelle (Android-only)
  static Future<void> forceUpdateCalendarWidget() async {
    if (_isIOSPlatform) return; // iOS'ta widget desteklenmez
    try {
      await _channel.invokeMethod('updateCalendarWidget');
    } catch (_) {}
  }

  /// Takvim widget pin durumu kontrolü (Android-only)
  static Future<bool> requestPinCalendarWidget() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('requestPinCalendarWidget') ??
              false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isCalendarWidgetPinned() async {
    if (_isIOSPlatform) return false; // iOS'ta widget desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('isCalendarWidgetPinned') ?? false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Takvim widget ayarları get metodları
  static Future<double> getCalendarWidgetCardOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    final int alpha = prefs.getInt(AppKeys.calendarWidgetCardAlpha) ?? 204;
    return (alpha.clamp(0, 255)) / 255.0;
  }

  static Future<bool> getCalendarWidgetGradientEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.calendarWidgetGradientOn) ?? true;
  }

  static Future<int> getCalendarWidgetCardRadiusDp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppKeys.calendarWidgetCardRadiusDp) ?? 75;
  }

  static Future<int> getCalendarWidgetDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.calendarWidgetDisplayMode) ?? 0).clamp(0, 2);
  }

  static Future<int> getCalendarWidgetTextColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.calendarWidgetTextColorMode) ?? 0).clamp(0, 2);
  }

  static Future<int> getCalendarWidgetBackgroundColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.calendarWidgetBgColorMode) ?? 0).clamp(0, 2);
  }

  /// Takvim widget hicri tarih font stili (0: Light, 1: Bold)
  static Future<void> setCalendarWidgetHijriFontStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.calendarWidgetHijriFontStyle, style.clamp(0, 1));
    await forceUpdateCalendarWidget();
  }

  static Future<int> getCalendarWidgetHijriFontStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.calendarWidgetHijriFontStyle) ?? 0).clamp(0, 1);
  }

  /// Takvim widget miladi tarih font stili (0: Light, 1: Bold)
  static Future<void> setCalendarWidgetGregorianFontStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.calendarWidgetGregorianFontStyle, style.clamp(0, 1));
    await forceUpdateCalendarWidget();
  }

  static Future<int> getCalendarWidgetGregorianFontStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(AppKeys.calendarWidgetGregorianFontStyle) ?? 1).clamp(0, 1);
  }

  /// Sessiz mod alarmı kur (bildirimden bağımsız, Android-only)
  /// iOS'ta DND kontrolü Flutter'dan yapılamaz
  static Future<bool> scheduleSilentModeAlarm({
    required int epochMillis,
    required int durationMinutes,
    required String prayerId,
    required int requestCode,
  }) async {
    if (_isIOSPlatform) return false; // iOS'ta sessiz mod alarmı desteklenmez
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('scheduleSilentModeAlarm', {
                'epochMillis': epochMillis,
                'durationMinutes': durationMinutes,
                'prayerId': prayerId,
                'requestCode': requestCode,
              }) ??
              false;
      return ok;
    } catch (_) {
      return false;
    }
  }
}
