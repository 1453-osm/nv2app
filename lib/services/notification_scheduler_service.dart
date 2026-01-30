import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'permission_service.dart';
import 'widget_bridge.dart';
import 'dua_service.dart';
import '../models/religious_day.dart';
import '../data/religious_days_mapping.dart';
import '../utils/app_logger.dart';
import '../utils/app_keys.dart';
import '../l10n/app_localizations.dart';

/// Seçilen dakika ve ses id'lerine göre namaz bildirimlerini planlar.
/// MVVM: SettingsBar kaydeder, PrayerTimesViewModel bugünün vakitlerini/pref'leri günceller.
class NotificationSchedulerService {
  NotificationSchedulerService._();
  static final NotificationSchedulerService instance =
      NotificationSchedulerService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final PermissionService _permissionService = PermissionService();
  final DuaService _duaService = DuaService();
  bool _initialized = false;

  /// Mevcut locale'e göre AppLocalizations instance'ı döndürür.
  Future<AppLocalizations> _getLocalizations() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode =
        prefs.getString(AppKeys.localeKey) ?? AppKeys.langTurkish;
    final locale = Locale(localeCode);
    return lookupAppLocalizations(locale);
  }

  static const String _defaultChannelId = 'nv_prayer_default';
  static const String _defaultChannelName = 'Namaz Bildirimleri';
  static const String _silentChannelId = 'nv_prayer_silent';
  static const String _silentChannelName = 'Sessiz Namaz Bildirimleri';
  static const String _noSoundHighId = 'nv_prayer_nosound_high';
  static const String _noSoundHighName =
      'Namaz Bildirimi (Sessiz, Yüksek Öncelik)';
  static const String _duaChannelId = 'nv_dua_daily';
  static const String _duaChannelName = 'Günlük Dua Bildirimleri';
  // Yalnızca Android raw/ içinde gerçekten mevcut olan sesler için kanal oluştur
  static const List<String> _customSoundIds = <String>[
    'alarm',
    'bird',
    'soft',
    'hard',
    'adhanarabic',
    'adhan',
    'sela',
  ];
  // Normal bildirime sığmayan uzun ezan sesleri (şu an boş - tüm sesler normal bildirim gibi)
  static const List<String> _longAdhanIds = <String>[
    // Boş - tüm sesler normal bildirim kanalı ile çalınır
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    // Timezone init: Android genelde systemDefault ile doğru çalışır
    try {
      tz.initializeTimeZones();
      // Native'den TZ kimliği almayı dene
      const methodChannel = MethodChannel('com.osm.namazvaktim/widgets');
      final String? tzId =
          await methodChannel.invokeMethod<String>('getLocalTimeZone');
      if (tzId != null && tzId.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzId));
      } else {
        // Güvenli geri dönüş: cihazın mevcut yerel zaman dilimi
        tz.setLocalLocation(tz.local);
      }
    } catch (_) {
      // UTC yerine yerel'e dön: yanlış zamanlamayı önler
      tz.setLocalLocation(tz.local);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS için DarwinInitializationSettings
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);

    // Android kanallarını oluştur
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await _ensureAndroidChannels(androidImpl);
    }

    // iOS için izin iste
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    _initialized = true;
  }

  Future<void> requestPermissionsIfNeeded() async {
    // Android 13+
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
    // Eksik izinleri (exact alarm, batarya optimizasyonu vb.) topluca iste
    await _permissionService.requestMissingNotificationPermissions();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    // Alarm fallback'larını da iptal et
    for (final baseId in <int>[101, 102, 103, 104, 105, 106, 107, 108]) {
      for (final offset in <int>[0, 10]) {
        final int req = baseId + offset;
        // ignore: unawaited_futures
        WidgetBridgeService.cancelExactAlarm(requestCode: req);
      }
    }
  }

  // Debug fonksiyonları kaldırıldı

  // Test bildirimi kaldırıldı

  /// Anlık basit bir test bildirimi gönderir.
  /// true: başarıyla gösterildi, false: gösterilemedi (ör. izin yok)
  Future<bool> sendTestNotification() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final permissions =
          await _permissionService.checkAllNotificationPermissions();
      if (!(permissions['notification'] ?? true)) {
        AppLogger.warning('Test bildirimi: bildirim izni yok',
            tag: 'Notification');
        return false;
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _defaultChannelId,
        _defaultChannelName,
        channelDescription: 'Test amaçlı basit bildirim',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final localizations = await _getLocalizations();
      await _plugin.show(
        999, // test bildirimi için sabit bir id
        localizations.notificationTestTitle,
        localizations.notificationTestBody,
        details,
      );

      AppLogger.debug('Test bildirimi gösterildi', tag: 'Notification');
      return true;
    } catch (e) {
      AppLogger.error('Test bildirimi hatası', tag: 'Notification', error: e);
      return false;
    }
  }

  /// Test amaçlı dua bildirimi gönderir.
  /// true: başarıyla gösterildi, false: gösterilemedi (ör. izin yok)
  Future<bool> sendTestDuaNotification() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final permissions =
          await _permissionService.checkAllNotificationPermissions();
      if (!(permissions['notification'] ?? true)) {
        AppLogger.warning('Test dua bildirimi: bildirim izni yok',
            tag: 'Notification');
        return false;
      }

      // DuaService'i başlat
      if (!_duaService.isLoaded) {
        await _duaService.loadDualar();
      }

      // Rastgele dua seç
      final randomDua = _duaService.getRandomDua();
      if (randomDua == null) {
        AppLogger.warning('Test için dua bulunamadı', tag: 'Notification');
        return false;
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _duaChannelId,
        _duaChannelName,
        channelDescription: 'Test amaçlı dua bildirimi',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final localizations = await _getLocalizations();
      final prefs = await SharedPreferences.getInstance();
      final localeCode =
          prefs.getString(AppKeys.localeKey) ?? AppKeys.langTurkish;
      final String duaText = randomDua.getText(localeCode);
      final String body =
          duaText.length > 100 ? '${duaText.substring(0, 97)}...' : duaText;

      await _plugin.show(
        998, // test dua bildirimi için sabit bir id
        localizations.notificationTestDuaTitle,
        body,
        details,
      );

      AppLogger.debug('Test dua bildirimi gösterildi: $body',
          tag: 'Notification');
      return true;
    } catch (e) {
      AppLogger.error('Test dua bildirimi hatası',
          tag: 'Notification', error: e);
      return false;
    }
  }

  /// Bildirim/izin durumlarını ve planlı bildirimleri konsola yazar.
  Future<void> debugNotificationStatus() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final permissions =
          await _permissionService.checkAllNotificationPermissions();
      AppLogger.debug('--- DEBUG STATUS ---', tag: 'Notification');
      AppLogger.debug('İzinler: $permissions', tag: 'Notification');

      try {
        final pending = await _plugin.pendingNotificationRequests();
        AppLogger.debug('Bekleyen bildirim: ${pending.length}',
            tag: 'Notification');
        for (final p in pending) {
          AppLogger.debug('  id=${p.id}, title=${p.title}',
              tag: 'Notification');
        }
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith('nv_notif_'))
            .toList()
          ..sort();
        AppLogger.debug('Ayar sayısı: ${keys.length}', tag: 'Notification');
      } catch (_) {}

      AppLogger.debug('Timezone: ${tz.local.name}, Şimdi: ${DateTime.now()}',
          tag: 'Notification');
    } catch (e) {
      AppLogger.error('Debug status hatası', tag: 'Notification', error: e);
    }
  }

  /// İzin durumlarını kontrol et ve eksikleri bildir
  Future<Map<String, bool>> checkPermissionStatus() async {
    return await _permissionService.checkAllNotificationPermissions();
  }

  /// Prefs'teki `nv_notif_*` ayarlarına ve SharedPreferences'taki vakitlere göre bugün ve yarının tüm bildirimlerini yeniden planlar.
  Future<void> rescheduleTodayNotifications() async {
    if (!_initialized) {
      AppLogger.debug('Başlatılıyor...', tag: 'Notification');
      await initialize();
    }

    // İzinleri kontrol et
    final permissions =
        await _permissionService.checkAllNotificationPermissions();
    AppLogger.debug('İzin durumu: $permissions', tag: 'Notification');

    if (!permissions['notification']!) {
      AppLogger.warning('Bildirim izni yok, planlama atlanıyor',
          tag: 'Notification');
      return;
    }

    // SharedPreferences'ı yeniden yükle - güncel değerleri garantilemek için
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    AppLogger.debug('Yeniden planlama başlıyor...', tag: 'Notification');

    // Bugünkü vakitler
    final String? fajr = prefs.getString(AppKeys.prayerFajr);
    final String? sunrise = prefs.getString(AppKeys.prayerSunrise);
    final String? dhuhr = prefs.getString(AppKeys.prayerDhuhr);
    final String? asr = prefs.getString(AppKeys.prayerAsr);
    final String? maghrib = prefs.getString(AppKeys.prayerMaghrib);
    final String? isha = prefs.getString(AppKeys.prayerIsha);

    // Yarınki vakitler (anahtar adı tutarsızlıklarına karşı geriye dönük uyumlu okuma)
    String? readTomorrow(String mainKey, String fallbackKey) {
      return prefs.getString(mainKey) ?? prefs.getString(fallbackKey);
    }

    final String? tomorrowFajr =
        readTomorrow(AppKeys.widgetTomorrowFajr, AppKeys.widgetFajrTomorrow);
    final String? tomorrowSunrise =
        readTomorrow(AppKeys.widgetTomorrowSunrise, AppKeys.widgetSunriseTomorrow);
    final String? tomorrowDhuhr =
        readTomorrow(AppKeys.widgetTomorrowDhuhr, AppKeys.widgetDhuhrTomorrow);
    final String? tomorrowAsr =
        readTomorrow(AppKeys.widgetTomorrowAsr, AppKeys.widgetAsrTomorrow);
    final String? tomorrowMaghrib =
        readTomorrow(AppKeys.widgetTomorrowMaghrib, AppKeys.widgetMaghribTomorrow);
    final String? tomorrowIsha =
        readTomorrow(AppKeys.widgetTomorrowIsha, AppKeys.widgetIshaTomorrow);

    AppLogger.debug('Bugün: fajr=$fajr, dhuhr=$dhuhr, maghrib=$maghrib',
        tag: 'Notification');

    if ([fajr, sunrise, dhuhr, asr, maghrib, isha]
        .any((s) => s == null || s.isEmpty)) {
      AppLogger.warning('Namaz vakitleri eksik, planlama atlanıyor',
          tag: 'Notification');
      return;
    }

    // Önce iptal et
    await cancelAll();

    // Bugünkü namaz vakitleri için planla (null olmayan kopyalar)
    final String fajrStr = fajr!;
    final String sunriseStr = sunrise!;
    final String dhuhrStr = dhuhr!;
    final String asrStr = asr!;
    final String maghribStr = maghrib!;
    final String ishaStr = isha!;
    await _scheduleForAll('imsak', fajrStr, 0, prefs);
    await _scheduleForAll('gunes', sunriseStr, 0, prefs);
    await _scheduleForAll('ogle', dhuhrStr, 0, prefs);
    await _scheduleForAll('ikindi', asrStr, 0, prefs);
    await _scheduleForAll('aksam', maghribStr, 0, prefs);
    await _scheduleForAll('yatsi', ishaStr, 0, prefs);

    // Cuma namazı özel bildirimi (sadece Cuma günleri)
    final now = DateTime.now();
    if (now.weekday == DateTime.friday) {
      await _scheduleSpecialFridayNotification(dhuhrStr, 0);
    }

    // Yarınki vakitler: elinde olanları tek tek planla (hepsi gerekmiyor)
    const Duration tomorrow = Duration(days: 1);
    final tomorrowDate = now.add(tomorrow);
    if (tomorrowFajr != null && tomorrowFajr.isNotEmpty) {
      await _scheduleForAll('imsak', tomorrowFajr, 1, prefs);
    }
    if (tomorrowSunrise != null && tomorrowSunrise.isNotEmpty) {
      await _scheduleForAll('gunes', tomorrowSunrise, 1, prefs);
    }
    if (tomorrowDhuhr != null && tomorrowDhuhr.isNotEmpty) {
      await _scheduleForAll('ogle', tomorrowDhuhr, 1, prefs);
      if (tomorrowDate.weekday == DateTime.friday) {
        await _scheduleSpecialFridayNotification(tomorrowDhuhr, 1);
      }
    }
    if (tomorrowAsr != null && tomorrowAsr.isNotEmpty) {
      await _scheduleForAll('ikindi', tomorrowAsr, 1, prefs);
    }
    if (tomorrowMaghrib != null && tomorrowMaghrib.isNotEmpty) {
      await _scheduleForAll('aksam', tomorrowMaghrib, 1, prefs);
    }
    if (tomorrowIsha != null && tomorrowIsha.isNotEmpty) {
      await _scheduleForAll('yatsi', tomorrowIsha, 1, prefs);
    }

    // Günlük dua bildirimi (saat 10:00)
    await _scheduleDailyDuaNotification(0);
    await _scheduleDailyDuaNotification(1);

    // Native taraf için de güvence: widget güncellemesinden sonra native alarm planla
    try {
      await WidgetBridgeService.forceUpdateSmallWidget();
    } catch (_) {}
  }

  /// Belirli bir temel vakit kimliği (ör. imsak) için, SharedPreferences içinde
  /// tanımlı olan tüm varyantlar (imsak, imsak_1, imsak_2, ...) için planlama yapar.
  Future<void> _scheduleForAll(
    String baseId,
    String hhmm,
    int dayOffset,
    SharedPreferences prefs,
  ) async {
    // Her zaman en az ana ID'yi ekle
    final Set<String> ids = {baseId};

    // nv_notif_imsak_1_enabled gibi ek kayıtları tara
    final String escapedBaseId = RegExp.escape(baseId);
    final RegExp pattern =
        RegExp('^nv_notif_${escapedBaseId}_(\\d+)_enabled\$');
    for (final key in prefs.getKeys()) {
      final match = pattern.firstMatch(key);
      if (match == null) continue;
      final String suffix = match.group(1) ?? '';
      if (suffix.isEmpty) continue;
      ids.add('${baseId}_$suffix');
    }

    for (final id in ids) {
      await _scheduleFor(id, hhmm, dayOffset);
    }
  }

  Future<void> _scheduleFor(String id, String hhmm, int dayOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Güncel değerleri garantilemek için
    final String base = 'nv_notif_${id}_';
    final bool enabled = prefs.getBool('${base}enabled') ?? true;
    final int minutes = prefs.getInt('${base}minutes') ?? 5;
    final String soundId = prefs.getString('${base}sound') ?? 'default';

    AppLogger.debug(
        'Planlanıyor: $id at $hhmm (+$dayOffset gün), enabled=$enabled, min=$minutes',
        tag: 'Notification');

    final DateTime now = DateTime.now();
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return;

    // TAM namaz vakti zamanı (sessiz mod için)
    final DateTime exactPrayerTime =
        DateTime(now.year, now.month, now.day + dayOffset, h, m);

    // ===== SESSİZ MOD ALARMI (bildirimden bağımsız, ayrı receiver) =====
    // Sadece base notification için kur (imsak_1, imsak_2 gibi varyantlar için değil)
    final String baseId = _basePrayerId(id);
    if (id == baseId) {
      final bool silentModeEnabled =
          prefs.getBool('${base}silentModeEnabled') ?? false;
      final int silentModeDuration =
          prefs.getInt('${base}silentModeDuration') ?? 15;
      AppLogger.debug(
          'Sessiz mod kontrolü: $id, enabled=$silentModeEnabled, duration=$silentModeDuration',
          tag: 'Notification');
      if (silentModeEnabled && !exactPrayerTime.isBefore(now)) {
        try {
          final int silentRequestCode =
              0x600 + _notifIdFor(id) + (dayOffset * 10);
          final int exactEpochMs = exactPrayerTime.millisecondsSinceEpoch;
          final bool scheduled =
              await WidgetBridgeService.scheduleSilentModeAlarm(
            epochMillis: exactEpochMs,
            durationMinutes: silentModeDuration,
            prayerId: id,
            requestCode: silentRequestCode,
          );
          if (scheduled) {
            AppLogger.success(
                'Sessiz mod alarmı planlandı: $id -> $exactPrayerTime (süre: $silentModeDuration dk)',
                tag: 'Notification');
          } else {
            AppLogger.error('Sessiz mod alarmı kurulamadı: $id',
                tag: 'Notification');
          }
        } catch (e) {
          AppLogger.error('Sessiz mod alarmı hatası: $e', tag: 'Notification');
        }
      }
    }

    // ===== BİLDİRİM PLANLAMA =====
    if (!enabled) {
      return;
    }

    DateTime scheduledTime =
        exactPrayerTime.subtract(Duration(minutes: minutes));

    if (scheduledTime.isBefore(now)) {
      return;
    }

    // Yarın için farklı notification ID kullan
    final int notifId = _notifIdFor(id) + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault =
        soundId == 'default' || !_customSoundIds.contains(soundId);
    final bool isLongAdhan = !isSilent && _longAdhanIds.contains(soundId);
    final bool useServicePlayback =
        isLongAdhan; // sadece uzun ezanlar servisle çalınır

    final String channelId;
    final String channelName;
    if (isSilent) {
      channelId = _silentChannelId;
      channelName = _silentChannelName;
    } else if (isDefault) {
      channelId = _defaultChannelId;
      channelName = _defaultChannelName;
    } else if (useServicePlayback) {
      channelId = _noSoundHighId;
      channelName = _noSoundHighName;
    } else {
      channelId = _channelIdFor(soundId);
      channelName = _channelNameFor(soundId);
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Namaz bildirimleri (sessiz)'
          : 'Namaz vakitleri için hatırlatıcı bildirimler',
      importance: isSilent ? Importance.defaultImportance : Importance.max,
      priority: isSilent ? Priority.defaultPriority : Priority.high,
      playSound: !isSilent && !useServicePlayback,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    // iOS için bildirim ayarları
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final localizations = await _getLocalizations();
    final title = await _titleFor(id, localizations);
    final body = await _bodyFor(id, minutes, localizations);

    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      AppLogger.success('Bildirim planlandı: $id -> $tzTime',
          tag: 'Notification');
    } catch (e) {
      AppLogger.error('Bildirim planlanamadı: $id',
          tag: 'Notification', error: e);
    }

    // Uzun ezanlar servis ile çalınır; ayrıca schedule başarısızsa alarm kur
    if (useServicePlayback || !scheduledOk) {
      try {
        final int epochMs = tzTime.millisecondsSinceEpoch;
        await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: epochMs,
          title: title,
          text: body,
          soundId: useServicePlayback ? soundId : 'default',
          requestCode: notifId,
          notificationId: id, // Sessiz mod kontrolü için
        );
      } catch (e) {
        AppLogger.error('Alarm fallback hatası', tag: 'Notification', error: e);
      }
    }
  }

  Future<void> _scheduleSpecialFridayNotification(
      String dhuhrTime, int dayOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String base = 'nv_notif_cuma_';
    final bool enabled = prefs.getBool('${base}enabled') ?? true;
    final int storedMinutes = prefs.getInt('${base}minutes') ?? 45;
    final int minutes = storedMinutes < 15 ? 15 : storedMinutes;
    final String soundId = prefs.getString('${base}sound') ?? 'default';

    if (!enabled) {
      return;
    }

    final DateTime now = DateTime.now();
    final parts = dhuhrTime.split(':');
    if (parts.length != 2) return;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return;

    DateTime scheduledTime =
        DateTime(now.year, now.month, now.day + dayOffset, h, m);
    scheduledTime = scheduledTime.subtract(Duration(minutes: minutes));

    if (scheduledTime.isBefore(now)) {
      return;
    }

    // Cuma namazı için özel notification ID
    final int notifId = 107 + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault =
        soundId == 'default' || !_customSoundIds.contains(soundId);
    final bool isLongAdhan = !isSilent && _longAdhanIds.contains(soundId);
    final String channelId = isSilent
        ? _silentChannelId
        : (isDefault
            ? _defaultChannelId
            : (isLongAdhan ? _noSoundHighId : _channelIdFor(soundId)));
    final String channelName = isSilent
        ? _silentChannelName
        : (isDefault
            ? _defaultChannelName
            : (isLongAdhan ? _noSoundHighName : _channelNameFor(soundId)));

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Cuma namazı bildirimleri (sessiz)'
          : 'Cuma namazı için özel hatırlatıcı bildirimler',
      importance: isSilent ? Importance.low : Importance.max,
      priority: isSilent ? Priority.low : Priority.high,
      playSound: !isSilent,
      enableVibration: !isSilent,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final localizations = await _getLocalizations();
    final String title = localizations.notificationFridayTitle;
    final String body = await _getFridayMessage(minutes, localizations);

    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      AppLogger.success('Cuma bildirimi planlandı: $tzTime',
          tag: 'Notification');
    } catch (e) {
      AppLogger.error('Cuma bildirimi planlanamadı',
          tag: 'Notification', error: e);
    }

    final bool requiresLongAdhan = _longAdhanIds.contains(soundId);
    if (!isSilent && (requiresLongAdhan || !scheduledOk)) {
      try {
        await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: tzTime.millisecondsSinceEpoch,
          title: title,
          text: body,
          soundId: requiresLongAdhan ? soundId : 'default',
          requestCode: notifId,
        );
      } catch (e) {
        AppLogger.error('Cuma fallback hatası', tag: 'Notification', error: e);
      }
    }
  }

  Future<String> _getFridayMessage(
      int minutes, AppLocalizations localizations) async {
    final timeText = await _getTimeText(minutes, localizations);
    if (minutes <= 15) {
      return localizations.notificationFridayMessage15(timeText);
    } else if (minutes <= 30) {
      return localizations.notificationFridayMessage30(timeText);
    } else {
      return localizations.notificationFridayMessageMore(timeText);
    }
  }

  Future<void> _ensureAndroidChannels(
      AndroidFlutterLocalNotificationsPlugin androidImpl) async {
    // Varsayılan: sistemin varsayılan tonu
    final defaultChannel = AndroidNotificationChannel(
      _defaultChannelId,
      _defaultChannelName,
      description:
          'Namaz vakitleri için bildirimler (telefonun varsayılan bildirim sesini kullanır)',
      importance: Importance.defaultImportance,
      playSound: true,
    );
    await androidImpl.createNotificationChannel(defaultChannel);

    // Sessiz
    final silentChannel = AndroidNotificationChannel(
      _silentChannelId,
      _silentChannelName,
      description: 'Namaz bildirimleri (sessiz)',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: true,
      enableLights: false,
    );
    await androidImpl.createNotificationChannel(silentChannel);

    // Özel sesli kanallar
    for (final soundId in _customSoundIds) {
      final String resource = _resourceNameFor(soundId);
      try {
        final custom = AndroidNotificationChannel(
          _channelIdFor(soundId),
          _channelNameFor(soundId),
          description: 'Özel ses: $soundId',
          importance: Importance.defaultImportance,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(resource),
        );
        await androidImpl.createNotificationChannel(custom);
      } catch (_) {
        // Eğer raw dosya yoksa kanal oluşturma başarısız olabilir; görmezden gel
      }
    }

    // Uzun ses/alarm için: bildirim sessiz ama yüksek öncelik (ses ForegroundService ile)
    final noSoundHigh = AndroidNotificationChannel(
      _noSoundHighId,
      _noSoundHighName,
      description:
          'Uzun ezan/alarm için sessiz fakat yüksek öncelikli bildirim',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
    );
    await androidImpl.createNotificationChannel(noSoundHigh);

    // Günlük dua bildirimleri kanalı
    final duaChannel = AndroidNotificationChannel(
      _duaChannelId,
      _duaChannelName,
      description: 'Her gün saat 10:00\u0027da gönderilen dua bildirimleri',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidImpl.createNotificationChannel(duaChannel);
  }

  String _channelIdFor(String soundId) => 'nv_prayer_sound_$soundId';
  String _channelNameFor(String soundId) => 'Namaz Bildirimi ($soundId)';
  String _resourceNameFor(String soundId) {
    // raw/ klasörüne konacak dosya adları ile eşleşmeli
    // örn: raw/alarm.mp3 -> 'alarm'
    switch (soundId) {
      case 'alarm':
      case 'bird':
      case 'soft':
      case 'hard':
        return soundId;
      default:
        // adhan1..7
        return soundId;
    }
  }

  int _notifIdFor(String id) {
    // imsak, imsak_1, imsak_2 gibi ID'leri destekle
    final String baseId = _basePrayerId(id);
    final String? suffix =
        id.length > baseId.length + 1 ? id.substring(baseId.length + 1) : null;
    final int variantIndex = int.tryParse(suffix ?? '') ?? 0;

    int baseCode;
    switch (baseId) {
      case 'imsak':
        baseCode = 101;
        break;
      case 'gunes':
        baseCode = 102;
        break;
      case 'ogle':
        baseCode = 103;
        break;
      case 'ikindi':
        baseCode = 104;
        break;
      case 'aksam':
        baseCode = 105;
        break;
      case 'yatsi':
        baseCode = 106;
        break;
      default:
        baseCode = 199;
        break;
    }

    // Her varyant için 100'lük blok kaydır: 101, 201, 301, ...
    return baseCode + (variantIndex * 100);
  }

  Future<String> _titleFor(String id, AppLocalizations localizations) async {
    final String baseId = _basePrayerId(id);
    switch (baseId) {
      case 'imsak':
        return localizations.notificationImsakTitle;
      case 'gunes':
        return localizations.notificationSunriseTitle;
      case 'ogle':
        return localizations.notificationZuhrTitle;
      case 'ikindi':
        return localizations.notificationAsrTitle;
      case 'aksam':
        return localizations.notificationMaghribTitle;
      case 'yatsi':
        return localizations.notificationIshaTitle;
      default:
        return localizations.notificationPrayerTimeTitle;
    }
  }

  Future<String> _bodyFor(
      String id, int minutes, AppLocalizations localizations) async {
    final String baseId = _basePrayerId(id);
    if (minutes == 0) {
      return await _getImmediateMessage(baseId, localizations);
    } else {
      return await _getAdvanceMessage(baseId, minutes, localizations);
    }
  }

  Future<String> _getImmediateMessage(
      String id, AppLocalizations localizations) async {
    final now = DateTime.now();
    final isRamadan = await _isRamadanMonth(now);

    switch (id) {
      case 'imsak':
        if (isRamadan) {
          return localizations.notificationImsakImmediateRamadan;
        } else {
          return localizations.notificationImsakImmediate;
        }
      case 'gunes':
        return localizations.notificationSunriseImmediate;
      case 'ogle':
        if (now.weekday == DateTime.friday) {
          return localizations.notificationZuhrImmediateFriday;
        } else {
          return localizations.notificationZuhrImmediate;
        }
      case 'ikindi':
        return localizations.notificationAsrImmediate;
      case 'aksam':
        if (isRamadan) {
          return localizations.notificationMaghribImmediateRamadan;
        } else {
          return localizations.notificationMaghribImmediate;
        }
      case 'yatsi':
        return localizations.notificationIshaImmediate;
      default:
        return localizations.notificationPrayerTimeImmediate;
    }
  }

  Future<String> _getAdvanceMessage(
      String id, int minutes, AppLocalizations localizations) async {
    final bool isAfter = minutes < 0;
    final int absMinutes = minutes.abs();
    final timeText = await _getTimeText(absMinutes, localizations);
    final now = DateTime.now();
    final isRamadan = await _isRamadanMonth(now);

    switch (id) {
      case 'imsak':
        return isAfter
            ? localizations.notificationImsakAfter(timeText)
            : localizations.notificationImsakAdvance(timeText);
      case 'gunes':
        return isAfter
            ? localizations.notificationSunriseAfter(timeText)
            : localizations.notificationSunriseAdvance(timeText);
      case 'ogle':
        if (now.weekday == DateTime.friday) {
          return localizations.notificationZuhrAdvanceFriday(timeText);
        } else {
          return localizations.notificationZuhrAdvance(timeText);
        }
      case 'ikindi':
        return localizations.notificationAsrAdvance(timeText);
      case 'aksam':
        if (isRamadan) {
          return localizations.notificationMaghribAdvanceRamadan(timeText);
        } else {
          return localizations.notificationMaghribAdvance(timeText);
        }
      case 'yatsi':
        return localizations.notificationIshaAdvance(timeText);
      default:
        return localizations.notificationPrayerTimeAdvance(timeText);
    }
  }

  /// imsak_1, imsak_2 gibi ID'leri için temel vakit kimliğini (imsak) döndürür.
  String _basePrayerId(String id) {
    final int idx = id.indexOf('_');
    if (idx == -1) return id;
    return id.substring(0, idx);
  }

  Future<bool> _isRamadanMonth(DateTime date) async {
    try {
      // 1. Check cache for current year (Dynamic check)
      final isRamadanDynamic = await _checkRamadanStatusFromCache(date);
      if (isRamadanDynamic != null) {
        return isRamadanDynamic;
      }
    } catch (e) {
      AppLogger.error('Dynamic Ramadan check failed, falling back to static',
          tag: 'Notification', error: e);
    }

    // 2. Fallback to static dates (Legacy support for old offline scenarios)
    final year = date.year;
    if (year == 2024) {
      // 11 Mart - 9 Nisan
      return (date.month == 3 && date.day >= 11) ||
          (date.month == 4 && date.day <= 9);
    } else if (year == 2025) {
      // 1 Mart - 29 Mart
      return (date.month == 3 && date.day >= 1 && date.day <= 29);
    } else if (year == 2026) {
      // 18 Şubat - 19 Mart (Tahmini)
      if (date.month == 2 && date.day >= 18) return true;
      if (date.month == 3 && date.day <= 19) return true;
    }

    return false;
  }

  /// Helper method to check Ramadan status from cached religious days
  Future<bool?> _checkRamadanStatusFromCache(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final year = date.year;

    List<DetectedReligiousDay> events = [];

    // Helper to load events for a specific year
    Future<void> loadEvents(int y) async {
      final jsonStr = prefs.getString(AppKeys.religiousDaysKey(y));
      if (jsonStr != null) {
        try {
          final List<dynamic> list = jsonDecode(jsonStr);
          events.addAll(
              list.map((e) => DetectedReligiousDay.fromMap(e)).toList());
        } catch (e) {
          AppLogger.error('Error parsing cached religious days for year $y',
              error: e);
        }
      }
    }

    // Load current year, and adjacent years to handle boundary cases
    await loadEvents(year);
    await loadEvents(year - 1);
    await loadEvents(year + 1);

    if (events.isEmpty) return null; // No data found in cache

    // Sort events by date to ensure correct order
    events.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));

    // Find closest Ramadan Start before or at the given date
    DateTime? start;
    for (final e in events) {
      final key = ReligiousEventMapping.toCanonicalKey(e.eventName, null);
      if (key == 'ramazan_baslangici') {
        if (e.gregorianDate.isBefore(date) ||
            e.gregorianDate.isAtSameMomentAs(date)) {
          start = e.gregorianDate;
        }
      }
    }

    // If no start date found before today, it's not Ramadan
    if (start == null) return false;

    // Find closest Eid (Ramadan End) strictly after the found Start
    DateTime? end;
    for (final e in events) {
      final key = ReligiousEventMapping.toCanonicalKey(e.eventName, null);
      if (key == 'ramazan_bayrami_1_gun') {
        if (e.gregorianDate.isAfter(start)) {
          end = e.gregorianDate;
          break; // Found the end of this Ramadan
        }
      }
    }

    // If start found but no end found, assume Ramadan if within 30 days
    if (end == null) {
      final diff = date.difference(start).inDays;
      return diff >= 0 && diff < 30;
    }

    // Check if date is strictly before the end date (Eid day is not Ramadan)
    return date.isBefore(end) &&
        (date.isAfter(start) || date.isAtSameMomentAs(start));
  }

  Future<String> _getTimeText(
      int minutes, AppLocalizations localizations) async {
    final int absMinutes = minutes.abs();
    if (absMinutes < 60) {
      return localizations.timeMinutes(absMinutes);
    } else {
      final hours = absMinutes ~/ 60;
      final remainingMinutes = absMinutes % 60;
      if (remainingMinutes == 0) {
        return localizations.timeHours(hours);
      } else {
        return localizations.timeHoursMinutes(hours, remainingMinutes);
      }
    }
  }

  /// Günlük dua bildirimi planla (saat 10:00)
  Future<void> _scheduleDailyDuaNotification(int dayOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String base = 'nv_notif_dua_';
    final bool enabled = prefs.getBool('${base}enabled') ?? true;
    final String soundId = prefs.getString('${base}sound') ?? 'default';

    if (!enabled) {
      return;
    }

    // DuaService'i başlat
    if (!_duaService.isLoaded) {
      await _duaService.loadDualar();
    }

    final DateTime now = DateTime.now();
    DateTime scheduledTime =
        DateTime(now.year, now.month, now.day + dayOffset, 10, 0);

    if (scheduledTime.isBefore(now)) {
      return;
    }

    // Rastgele dua seç
    final randomDua = _duaService.getRandomDua();
    if (randomDua == null) {
      return;
    }

    // Dua bildirimi için özel notification ID (108 + dayOffset * 10)
    final int notifId = 108 + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault =
        soundId == 'default' || !_customSoundIds.contains(soundId);

    final String channelId = isSilent
        ? _silentChannelId
        : (isDefault ? _duaChannelId : _channelIdFor(soundId));
    final String channelName = isSilent
        ? _silentChannelName
        : (isDefault ? _duaChannelName : _channelNameFor(soundId));

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Günlük dua bildirimleri (sessiz)'
          : 'Her gün saat 10:00\'da gönderilen dua bildirimleri',
      importance: isSilent ? Importance.defaultImportance : Importance.high,
      priority: isSilent ? Priority.defaultPriority : Priority.high,
      playSound: !isSilent,
      enableVibration: !isSilent,
      icon: '@mipmap/ic_launcher',
    );
    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final localizations = await _getLocalizations();
    final localeCode =
        prefs.getString(AppKeys.localeKey) ?? AppKeys.langTurkish;
    final String duaText = randomDua.getText(localeCode);
    final String title = localizations.notificationDuaTitle;
    final String body =
        duaText.length > 100 ? '${duaText.substring(0, 97)}...' : duaText;

    // Native fallback için seçilen duayı kaydet
    await prefs.setString('${AppKeys.duaTitleDayOffsetPrefix}$dayOffset', title);
    await prefs.setString('${AppKeys.duaBodyDayOffsetPrefix}$dayOffset', body);
    await prefs.setString(AppKeys.duaLastTitle, title);
    await prefs.setString(AppKeys.duaLastBody, body);

    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      AppLogger.success('Dua bildirimi planlandı: $tzTime',
          tag: 'Notification');
    } catch (e) {
      AppLogger.error('Dua bildirimi planlanamadı',
          tag: 'Notification', error: e);
    }

    // Başarısız olursa alarm fallback
    if (!scheduledOk) {
      try {
        await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: tzTime.millisecondsSinceEpoch,
          title: title,
          text: body,
          soundId: 'default',
          requestCode: notifId,
        );
      } catch (e) {
        AppLogger.error('Dua fallback hatası', tag: 'Notification', error: e);
      }
    }
  }
}
