import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'permission_service.dart';
import 'widget_bridge.dart';
import 'dua_service.dart';

/// Seçilen dakika ve ses id'lerine göre namaz bildirimlerini planlar.
/// MVVM: SettingsBar kaydeder, PrayerTimesViewModel bugünün vakitlerini/pref'leri günceller.
class NotificationSchedulerService {
  NotificationSchedulerService._();
  static final NotificationSchedulerService instance = NotificationSchedulerService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final PermissionService _permissionService = PermissionService();
  final DuaService _duaService = DuaService();
  bool _initialized = false;
  static const String _defaultChannelId = 'nv_prayer_default';
  static const String _defaultChannelName = 'Namaz Bildirimleri';
  static const String _silentChannelId = 'nv_prayer_silent';
  static const String _silentChannelName = 'Sessiz Namaz Bildirimleri';
  static const String _noSoundHighId = 'nv_prayer_nosound_high';
  static const String _noSoundHighName = 'Namaz Bildirimi (Sessiz, Yüksek Öncelik)';
  static const String _duaChannelId = 'nv_dua_daily';
  static const String _duaChannelName = 'Günlük Dua Bildirimleri';
  // Yalnızca Android raw/ içinde gerçekten mevcut olan sesler için kanal oluştur
  static const List<String> _customSoundIds = <String>[
    'alarm', 'bird', 'soft', 'hard',
    'adhan7',
  ];
  // Normal bildirime sığmayan uzun ezan sesleri
  static const List<String> _longAdhanIds = <String>[
    'adhan7',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    // Timezone init: Android genelde systemDefault ile doğru çalışır
    try {
      tz.initializeTimeZones();
      // Native'den TZ kimliği almayı dene
      const methodChannel = MethodChannel('com.osm.namazvaktim/widgets');
      final String? tzId = await methodChannel.invokeMethod<String>('getLocalTimeZone');
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
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Android kanallarını oluştur
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await _ensureAndroidChannels(androidImpl);
    }
    _initialized = true;
  }

  Future<void> requestPermissionsIfNeeded() async {
    // Android 13+
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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

      final permissions = await _permissionService.checkAllNotificationPermissions();
      if (!(permissions['notification'] ?? true)) {
        if (kDebugMode) {
          print('NotificationScheduler: sendTestNotification -> notification permission not granted');
        }
        return false;
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        _defaultChannelName,
        channelDescription: 'Test amaçlı basit bildirim',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        999, // test bildirimi için sabit bir id
        '🔔 Test Bildirimi',
        'Bildirim sistemi çalışıyor.',
        details,
      );

      if (kDebugMode) {
        print('NotificationScheduler: sendTestNotification -> shown');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: sendTestNotification error: $e');
      }
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

      final permissions = await _permissionService.checkAllNotificationPermissions();
      if (!(permissions['notification'] ?? true)) {
        if (kDebugMode) {
          print('NotificationScheduler: sendTestDuaNotification -> notification permission not granted');
        }
        return false;
      }

      // DuaService'i başlat
      if (!_duaService.isLoaded) {
        await _duaService.loadDualar();
      }

      // Rastgele dua seç
      final randomDua = _duaService.getRandomDua();
      if (randomDua == null) {
        if (kDebugMode) {
          print('NotificationScheduler: No dua available for test');
        }
        return false;
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _duaChannelId,
        _duaChannelName,
        channelDescription: 'Test amaçlı dua bildirimi',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      final NotificationDetails details = NotificationDetails(android: androidDetails);

      final String body = randomDua.tr.text.length > 100 
          ? '${randomDua.tr.text.substring(0, 97)}...' 
          : randomDua.tr.text;

      await _plugin.show(
        998, // test dua bildirimi için sabit bir id
        '🤲 Test - Günün Duası',
        body,
        details,
      );

      if (kDebugMode) {
        print('NotificationScheduler: sendTestDuaNotification -> shown');
        print('NotificationScheduler: Dua: $body');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: sendTestDuaNotification error: $e');
      }
      return false;
    }
  }

  /// Bildirim/izin durumlarını ve planlı bildirimleri konsola yazar.
  Future<void> debugNotificationStatus() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final permissions = await _permissionService.checkAllNotificationPermissions();
      if (kDebugMode) {
        print('NotificationScheduler: --- DEBUG STATUS START ---');
        print('NotificationScheduler: permissions => $permissions');
      }

      try {
        final pending = await _plugin.pendingNotificationRequests();
        if (kDebugMode) {
          print('NotificationScheduler: pending notifications count = ${pending.length}');
          for (final p in pending) {
            print('  -> id=${p.id}, title=${p.title}, body=${p.body}');
          }
        }
      } catch (_) {
        // pendingNotificationRequests desteklenmiyorsa sessizce geç
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().where((k) => k.startsWith('nv_notif_')).toList()..sort();
        if (kDebugMode) {
          print('NotificationScheduler: nv_notif_* keys (${keys.length}) => $keys');
          for (final k in keys) {
            print('  $k = ${prefs.get(k)}');
          }
        }
      } catch (_) {}

      if (kDebugMode) {
        print('NotificationScheduler: timezone => ${tz.local.name}');
        print('NotificationScheduler: now => ${DateTime.now()}');
        print('NotificationScheduler: --- DEBUG STATUS END ---');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: debugNotificationStatus error: $e');
      }
    }
  }

  /// İzin durumlarını kontrol et ve eksikleri bildir
  Future<Map<String, bool>> checkPermissionStatus() async {
    return await _permissionService.checkAllNotificationPermissions();
  }

  /// Prefs'teki `nv_notif_*` ayarlarına ve SharedPreferences'taki vakitlere göre bugün ve yarının tüm bildirimlerini yeniden planlar.
  Future<void> rescheduleTodayNotifications() async {
    if (!_initialized) {
      if (kDebugMode) {
        print('NotificationScheduler: Not initialized, initializing first...');
      }
      await initialize();
    }

    // İzinleri kontrol et
    final permissions = await _permissionService.checkAllNotificationPermissions();
    if (kDebugMode) {
      print('NotificationScheduler: Permission status: $permissions');
    }
    
    if (!permissions['notification']!) {
      if (kDebugMode) {
        print('NotificationScheduler: Notification permission not granted, skipping scheduling');
      }
      return;
    }

    // SharedPreferences'ı yeniden yükle - güncel değerleri garantilemek için
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    if (kDebugMode) {
      print('NotificationScheduler: Starting reschedule process...');
      // Tüm notification ayarlarını debug için listele
      final allKeys = prefs.getKeys().where((key) => key.startsWith('nv_notif_')).toList();
      print('NotificationScheduler: Found notification settings keys: $allKeys');
      for (final key in allKeys) {
        final value = prefs.get(key);
        print('NotificationScheduler: $key = $value');
      }
      
      // Vakitleri debug için listele
      final prayerKeys = prefs.getKeys().where((key) => 
        key.startsWith('nv_fajr') || key.startsWith('nv_sunrise') || 
        key.startsWith('nv_dhuhr') || key.startsWith('nv_asr') || 
        key.startsWith('nv_maghrib') || key.startsWith('nv_isha') ||
        key.startsWith('nv_tomorrow_')
      ).toList();
      print('NotificationScheduler: Found prayer times keys: $prayerKeys');
      for (final key in prayerKeys) {
        final value = prefs.get(key);
        print('NotificationScheduler: $key = $value');
      }
    }
    
    // Bugünkü vakitler
    final String? fajr = prefs.getString('nv_fajr');
    final String? sunrise = prefs.getString('nv_sunrise');
    final String? dhuhr = prefs.getString('nv_dhuhr');
    final String? asr = prefs.getString('nv_asr');
    final String? maghrib = prefs.getString('nv_maghrib');
    final String? isha = prefs.getString('nv_isha');
    
    // Yarınki vakitler (anahtar adı tutarsızlıklarına karşı geriye dönük uyumlu okuma)
    String? _readTomorrow(String mainKey, String fallbackKey) {
      return prefs.getString(mainKey) ?? prefs.getString(fallbackKey);
    }
    final String? tomorrowFajr = _readTomorrow('nv_tomorrow_fajr', 'nv_fajr_tomorrow');
    final String? tomorrowSunrise = _readTomorrow('nv_tomorrow_sunrise', 'nv_sunrise_tomorrow');
    final String? tomorrowDhuhr = _readTomorrow('nv_tomorrow_dhuhr', 'nv_dhuhr_tomorrow');
    final String? tomorrowAsr = _readTomorrow('nv_tomorrow_asr', 'nv_asr_tomorrow');
    final String? tomorrowMaghrib = _readTomorrow('nv_tomorrow_maghrib', 'nv_maghrib_tomorrow');
    final String? tomorrowIsha = _readTomorrow('nv_tomorrow_isha', 'nv_isha_tomorrow');
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: Reschedule called');
      // ignore: avoid_print
      print('Today prayer times: fajr=$fajr, sunrise=$sunrise, dhuhr=$dhuhr, asr=$asr, maghrib=$maghrib, isha=$isha');
      // ignore: avoid_print
      print('Tomorrow prayer times: fajr=$tomorrowFajr, sunrise=$tomorrowSunrise, dhuhr=$tomorrowDhuhr, asr=$tomorrowAsr, maghrib=$tomorrowMaghrib, isha=$tomorrowIsha');
    }
    
    if ([fajr, sunrise, dhuhr, asr, maghrib, isha].any((s) => s == null || s.isEmpty)) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationScheduler: Today prayer times missing; skip scheduling');
      }
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
    const tomorrow = Duration(days: 1);
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
    final RegExp pattern =
        RegExp('^nv_notif_${RegExp.escape(baseId)}_(\\d+)_enabled\$');
    for (final key in prefs.getKeys()) {
      final match = pattern.firstMatch(key);
      if (match == null) continue;
      final String suffix = match.group(1) ?? '';
      if (suffix.isEmpty) continue;
      ids.add('$baseId\_$suffix');
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
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: Schedule $id at $hhmm (day+$dayOffset), enabled=$enabled, minutes=$minutes, sound=$soundId');
      // ignore: avoid_print
      print('NotificationScheduler: Reading from SharedPreferences - base=$base, raw minutes value=${prefs.getInt("${base}minutes")}');
    }
    
    if (!enabled) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationScheduler: $id disabled, skipping');
      }
      return;
    }

    final DateTime now = DateTime.now();
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return;

    DateTime scheduledTime = DateTime(now.year, now.month, now.day + dayOffset, h, m);
    scheduledTime = scheduledTime.subtract(Duration(minutes: minutes));
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: $id scheduled for ${scheduledTime.toString()}, now is ${now.toString()}');
    }
    
    if (scheduledTime.isBefore(now)) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationScheduler: $id time passed, skipping');
      }
      return;
    }

    // Yarın için farklı notification ID kullan
    final int notifId = _notifIdFor(id) + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault = soundId == 'default' || !_customSoundIds.contains(soundId);
    final bool isLongAdhan = !isSilent && _longAdhanIds.contains(soundId);
    final bool useServicePlayback = isLongAdhan; // sadece uzun ezanlar servisle çalınır

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

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Namaz bildirimleri (sessiz)'
          : 'Namaz vakitleri için hatırlatıcı bildirimler',
      importance: isSilent ? Importance.defaultImportance : Importance.max,
      priority: isSilent ? Priority.defaultPriority : Priority.high,
      playSound: !isSilent && !useServicePlayback,
      enableVibration: true,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    if (kDebugMode) {
      print('NotificationScheduler: Local timezone: ${tz.local.name}');
      print('NotificationScheduler: Current time: ${DateTime.now()}');
      print('NotificationScheduler: Scheduled time (local): $scheduledTime');
      print('NotificationScheduler: Scheduled time (TZ): $tzTime');
      // ignore: avoid_print
      print('NotificationScheduler: Scheduling notification $notifId for $id at ${tzTime.toString()}');
      // ignore: avoid_print
      print('NotificationScheduler: Title: ${_titleFor(id)}, Body: ${_bodyFor(id, minutes)}');
    }
    
    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        _titleFor(id),
        _bodyFor(id, minutes),
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      if (kDebugMode) {
        print('NotificationScheduler: Successfully scheduled notification for $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: Failed to schedule notification for $id: $e');
      }
    }

    // Uzun ezanlar servis ile çalınır; ayrıca schedule başarısızsa alarm kur
    if (useServicePlayback || !scheduledOk) {
      try {
        final int epochMs = tzTime.millisecondsSinceEpoch;
        final ok = await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: epochMs,
          title: _titleFor(id),
          text: _bodyFor(id, minutes),
          soundId: useServicePlayback ? soundId : 'default',
          requestCode: notifId,
        );
        if (kDebugMode) {
          print('NotificationScheduler: scheduleExactAlarm fallback -> $ok');
        }
      } catch (e) {
        if (kDebugMode) {
          print('NotificationScheduler: scheduleExactAlarm error: $e');
        }
      }
    }
  }

  Future<void> _scheduleSpecialFridayNotification(String dhuhrTime, int dayOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Güncel değerleri garantilemek için
    final String base = 'nv_notif_cuma_';
    final bool enabled = prefs.getBool('${base}enabled') ?? true;
    final int storedMinutes = prefs.getInt('${base}minutes') ?? 30;
    final int minutes = storedMinutes < 15 ? 15 : storedMinutes;
    final String soundId = prefs.getString('${base}sound') ?? 'default';
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: Schedule Friday prayer at $dhuhrTime (day+$dayOffset), enabled=$enabled, minutes=$minutes (stored=$storedMinutes), sound=$soundId');
    }
    
    if (!enabled) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationScheduler: Friday prayer disabled, skipping');
      }
      return;
    }

    final DateTime now = DateTime.now();
    final parts = dhuhrTime.split(':');
    if (parts.length != 2) return;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return;

    DateTime scheduledTime = DateTime(now.year, now.month, now.day + dayOffset, h, m);
    scheduledTime = scheduledTime.subtract(Duration(minutes: minutes));
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: Friday prayer scheduled for ${scheduledTime.toString()}, now is ${now.toString()}');
    }
    
    if (scheduledTime.isBefore(now)) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationScheduler: Friday prayer time passed, skipping');
      }
      return;
    }

    // Cuma namazı için özel notification ID
    final int notifId = 107 + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault = soundId == 'default' || !_customSoundIds.contains(soundId);
    final bool isLongAdhan = !isSilent && _longAdhanIds.contains(soundId);
    final String channelId = isSilent
        ? _silentChannelId
        : (isDefault ? _defaultChannelId : (isLongAdhan ? _noSoundHighId : _channelIdFor(soundId)));
    final String channelName = isSilent
        ? _silentChannelName
        : (isDefault ? _defaultChannelName : (isLongAdhan ? _noSoundHighName : _channelNameFor(soundId)));

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Cuma namazı bildirimleri (sessiz)'
          : 'Cuma namazı için özel hatırlatıcı bildirimler',
      importance: isSilent ? Importance.low : Importance.max,
      priority: isSilent ? Priority.low : Priority.high,
      playSound: !isSilent,
      enableVibration: !isSilent,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    final String title = '🕌 Cuma Namazı';
    final String body = _getFridayMessage(minutes);
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationScheduler: Scheduling Friday notification $notifId at ${tzTime.toString()}');
      // ignore: avoid_print
      print('NotificationScheduler: Title: $title, Body: $body');
    }
    
    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      if (kDebugMode) {
        print('NotificationScheduler: Successfully scheduled Friday notification');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: Failed to schedule Friday notification: $e');
      }
    }

    final bool requiresLongAdhan = _longAdhanIds.contains(soundId);
    if (!isSilent && (requiresLongAdhan || !scheduledOk)) {
      try {
        final ok = await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: tzTime.millisecondsSinceEpoch,
          title: title,
          text: body,
          soundId: requiresLongAdhan ? soundId : 'default',
          requestCode: notifId,
        );
        if (kDebugMode) {
          print('NotificationScheduler: Friday scheduleExactAlarm fallback -> $ok');
        }
      } catch (e) {
        if (kDebugMode) {
          print('NotificationScheduler: Friday fallback error: $e');
        }
      }
    }
  }

  String _getFridayMessage(int minutes) {
    final timeText = _getTimeText(minutes);
    if (minutes <= 15) {
      return 'Cuma namazına $timeText kaldı. Camiye hareket etme zamanı!';
    } else if (minutes <= 30) {
      return 'Cuma namazına $timeText kaldı. Hazırlıklara başlayın.';
    } else {
      return 'Cuma namazına $timeText kaldı. Abdest alıp hazırlanmayı unutmayın.';
    }
  }

  Future<void> _ensureAndroidChannels(AndroidFlutterLocalNotificationsPlugin androidImpl) async {
    // Varsayılan: sistemin varsayılan tonu
    final defaultChannel = AndroidNotificationChannel(
      _defaultChannelId,
      _defaultChannelName,
      description: 'Namaz vakitleri için bildirimler (telefonun varsayılan bildirim sesini kullanır)',
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
      description: 'Uzun ezan/alarm için sessiz fakat yüksek öncelikli bildirim',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
    );
    await androidImpl.createNotificationChannel(noSoundHigh);

    // Günlük dua bildirimleri kanalı
    final duaChannel = AndroidNotificationChannel(
      _duaChannelId,
      _duaChannelName,
      description: 'Her gün saat 10:00\'da gönderilen dua bildirimleri',
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

  String _titleFor(String id) {
    final String baseId = _basePrayerId(id);
    switch (baseId) {
      case 'imsak':
        return '🌅 İmsak Vakti';
      case 'gunes':
        return '☀️ Güneş Doğuşu';
      case 'ogle':
        return '🕌 Öğle Namazı';
      case 'ikindi':
        return '🕐 İkindi Namazı';
      case 'aksam':
        return '🌇 Akşam Namazı';
      case 'yatsi':
        return '🌙 Yatsı Namazı';
      default:
        return '🕌 Namaz Vakti';
    }
  }

  String _bodyFor(String id, int minutes) {
    final String baseId = _basePrayerId(id);
    if (minutes == 0) {
      return _getImmediateMessage(baseId);
    } else {
      return _getAdvanceMessage(baseId, minutes);
    }
  }

  String _getImmediateMessage(String id) {
    final now = DateTime.now();
    final isRamadan = _isRamadanMonth(now);
    
    switch (id) {
      case 'imsak':
        if (isRamadan) {
          return 'İmsak vakti girdi! Sahur bitmiştir, oruç başladı.';
        } else {
          return 'İmsak vakti girdi. Fecr namazı vakti başladı.';
        }
      case 'gunes':
        return 'Güneş doğdu! İmsak vakti sona erdi.';
      case 'ogle':
        if (now.weekday == DateTime.friday) {
          return 'Cuma namazı vakti girdi! Camiye gitme zamanı.';
        } else {
          return 'Öğle namazı vakti girdi. Namaza hazırlanın.';
        }
      case 'ikindi':
        return 'İkindi namazı vakti girdi. İkindi namazını kılma zamanı.';
      case 'aksam':
        if (isRamadan) {
          return 'Akşam namazı vakti girdi! İftar zamanı geldi. 🌙';
        } else {
          return 'Akşam namazı vakti girdi. Maghrib namazı zamanı.';
        }
      case 'yatsi':
        return 'Yatsı namazı vakti girdi. Günün son namazını kılın.';
      default:
        return 'Namaz vakti girdi.';
    }
  }

  String _getAdvanceMessage(String id, int minutes) {
    final timeText = _getTimeText(minutes);
    final now = DateTime.now();
    final isRamadan = _isRamadanMonth(now);
    
    switch (id) {
      case 'imsak':
        if (isRamadan) {
          return 'İmsak vaktine $timeText kaldı. Sahur için son dakikalar!';
        } else {
          return 'İmsak vaktine $timeText kaldı. Fecr namazına hazırlanın.';
        }
      case 'gunes':
        return 'Güneş doğuşuna $timeText kaldı. İmsak vakti sona eriyor.';
      case 'ogle':
        if (now.weekday == DateTime.friday) {
          return 'Cuma namazına $timeText kaldı. Camiye gitmeyi unutmayın!';
        } else {
          return 'Öğle namazına $timeText kaldı. Abdest alıp hazırlanın.';
        }
      case 'ikindi':
        return 'İkindi namazına $timeText kaldı. Günün ikinci namazı için hazırlanın.';
      case 'aksam':
        if (isRamadan) {
          return 'İftar vaktine $timeText kaldı! Akşam namazı ve iftar zamanı.';
        } else {
          return 'Akşam namazına $timeText kaldı. Maghrib vakti yaklaşıyor.';
        }
      case 'yatsi':
        return 'Yatsı namazına $timeText kaldı. Günün son namazı için hazırlanın.';
      default:
        return 'Namaz vaktine $timeText kaldı.';
    }
  }

  /// imsak_1, imsak_2 gibi ID'leri için temel vakit kimliğini (imsak) döndürür.
  String _basePrayerId(String id) {
    final int idx = id.indexOf('_');
    if (idx == -1) return id;
    return id.substring(0, idx);
  }

  bool _isRamadanMonth(DateTime date) {
    // Basit bir Ramazan kontrolü - gerçek uygulamada Hicri takvim kullanılmalı
    // Şimdilik yaklaşık tarih aralığı kullanıyoruz
    final year = date.year;
    
    // 2024 Ramazan: 11 Mart - 9 Nisan
    // 2025 Ramazan: 1 Mart - 29 Mart (yaklaşık)
    if (year == 2024) {
      return (date.month == 3 && date.day >= 11) || (date.month == 4 && date.day <= 9);
    } else if (year == 2025) {
      return (date.month == 3 && date.day >= 1 && date.day <= 29);
    }
    
    // Diğer yıllar için genel kontrol yapılabilir
    return false;
  }

  String _getTimeText(int minutes) {
    if (minutes < 60) {
      return '$minutes dakika';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours saat';
      } else {
        return '$hours saat $remainingMinutes dakika';
      }
    }
  }

  /// Günlük dua bildirimi planla (saat 10:00)
  Future<void> _scheduleDailyDuaNotification(int dayOffset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Güncel değerleri garantilemek için
    final String base = 'nv_notif_dua_';
    final bool enabled = prefs.getBool('${base}enabled') ?? true;
    final String soundId = prefs.getString('${base}sound') ?? 'default';
    
    if (kDebugMode) {
      print('NotificationScheduler: Schedule daily dua for day+$dayOffset, enabled=$enabled, sound=$soundId');
    }
    
    if (!enabled) {
      if (kDebugMode) {
        print('NotificationScheduler: Daily dua disabled, skipping');
      }
      return;
    }

    // DuaService'i başlat
    if (!_duaService.isLoaded) {
      await _duaService.loadDualar();
    }

    final DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(now.year, now.month, now.day + dayOffset, 10, 0); // Saat 10:00
    
    if (kDebugMode) {
      print('NotificationScheduler: Daily dua scheduled for ${scheduledTime.toString()}, now is ${now.toString()}');
    }
    
    if (scheduledTime.isBefore(now)) {
      if (kDebugMode) {
        print('NotificationScheduler: Daily dua time passed, skipping');
      }
      return;
    }

    // Rastgele dua seç
    final randomDua = _duaService.getRandomDua();
    if (randomDua == null) {
      if (kDebugMode) {
        print('NotificationScheduler: No dua available, skipping daily dua notification');
      }
      return;
    }

    // Dua bildirimi için özel notification ID (108 + dayOffset * 10)
    final int notifId = 108 + (dayOffset * 10);

    final bool isSilent = soundId == 'silent';
    final bool isDefault = soundId == 'default' || !_customSoundIds.contains(soundId);
    
    final String channelId = isSilent
        ? _silentChannelId
        : (isDefault ? _duaChannelId : _channelIdFor(soundId));
    final String channelName = isSilent
        ? _silentChannelName
        : (isDefault ? _duaChannelName : _channelNameFor(soundId));

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isSilent
          ? 'Günlük dua bildirimleri (sessiz)'
          : 'Her gün saat 10:00\'da gönderilen dua bildirimleri',
      importance: isSilent ? Importance.defaultImportance : Importance.high,
      priority: isSilent ? Priority.defaultPriority : Priority.high,
      playSound: !isSilent,
      enableVibration: !isSilent,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    final String title = '🤲 Günün Duası';
    final String body = randomDua.tr.text.length > 100 
        ? '${randomDua.tr.text.substring(0, 97)}...' 
        : randomDua.tr.text;
    
    // Native fallback için seçilen duayı kaydet
    await prefs.setString('nv_dua_title_dayOffset_$dayOffset', title);
    await prefs.setString('nv_dua_body_dayOffset_$dayOffset', body);
    await prefs.setString('nv_dua_last_title', title);
    await prefs.setString('nv_dua_last_body', body);
    
    if (kDebugMode) {
      print('NotificationScheduler: Scheduling daily dua notification $notifId at ${tzTime.toString()}');
      print('NotificationScheduler: Title: $title, Body: $body');
    }
    
    bool scheduledOk = false;
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledOk = true;
      if (kDebugMode) {
        print('NotificationScheduler: Successfully scheduled daily dua notification');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationScheduler: Failed to schedule daily dua notification: $e');
      }
    }

    // Başarısız olursa alarm fallback
    if (!scheduledOk) {
      try {
        final ok = await WidgetBridgeService.scheduleExactAlarm(
          epochMillis: tzTime.millisecondsSinceEpoch,
          title: title,
          text: body,
          soundId: 'default',
          requestCode: notifId,
        );
        if (kDebugMode) {
          print('NotificationScheduler: Daily dua scheduleExactAlarm fallback -> $ok');
        }
      } catch (e) {
        if (kDebugMode) {
          print('NotificationScheduler: Daily dua fallback error: $e');
        }
      }
    }
  }
}


