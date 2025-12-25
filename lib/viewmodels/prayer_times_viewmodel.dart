import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import '../models/prayer_times_model.dart';
import '../services/prayer_times_service.dart';
import '../services/theme_service.dart';
import '../services/widget_bridge.dart';
import '../services/religious_days_service.dart';
import '../services/notification_scheduler_service.dart';
import '../models/religious_day.dart';
import '../utils/constants.dart';
import '../utils/arabic_numbers_helper.dart';
import '../utils/error_messages.dart';
import '../data/hijri_months.dart';
 

class PrayerTimesViewModel extends ChangeNotifier {
  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final ThemeService _themeService = ThemeService();
  final ReligiousDaysService _religiousDaysService = ReligiousDaysService();
  final Map<int, PrayerTime> _cachedTodayPrayerTimes = {};
  final Set<int> _loadedCityIds = {};
  bool _showSkeleton = false;
  bool _hasLoadedOnce = false;
  
  PrayerTimesResponse? _prayerTimesResponse;
  PrayerTime? _todayPrayerTimes;
  List<DetectedReligiousDay> _detectedReligiousDays = [];
  bool _isLoading = false;
  String? _errorMessage;
  ErrorCode? _errorCode;
  int? _selectedCityId;
  int _selectedYear = DateTime.now().year;
  int _lastCheckedYear = DateTime.now().year; // Yıl değişimi kontrolü için
  final Map<String, DateTime> _todayPrayerDateTimes = {};
  
  // Geri sayım için
  Timer? _countdownTimer;
  Duration? _timeUntilNextPrayer;
  String? _nextPrayerName;
  String? _lastPublishedWidgetText; // nextPrayerName|countdownText anahtarı
  
  // Dinamik tema rengi güncellemesi için
  Timer? _themeUpdateTimer;
  // İnternet bağlantı denemeleri için retry timer
  Timer? _retryTimer;

  // Geri sayım görüntüleme modu (kalıcı)
  CountdownFormat _countdownFormat = CountdownFormat.verbose;
  Locale _currentLocale = const Locale('tr');

  PrayerTimesViewModel() {
    _loadCountdownFormat();
    _loadLastCheckedYear();
    _startYearChangeMonitor();
  }

  // Getters
  PrayerTimesResponse? get prayerTimesResponse => _prayerTimesResponse;
  PrayerTime? get todayPrayerTimes => _todayPrayerTimes;
  List<DetectedReligiousDay> get detectedReligiousDays => _detectedReligiousDays;

  /// Dini günleri uzak kaynaktan günceller (ör. modal açılmadan önce çağrılabilir)
  Future<void> recomputeReligiousDays() async {
    await _refreshReligiousDays(_selectedCityId ?? -1, _selectedYear);
    notifyListeners();
  }
  bool get isLoading => _isLoading;
  bool get showSkeleton => _showSkeleton;
  String? get errorMessage => _errorMessage;
  ErrorCode? get errorCode => _errorCode;
  int? get selectedCityId => _selectedCityId;
  int get selectedYear => _selectedYear;
  Duration? get timeUntilNextPrayer => _timeUntilNextPrayer;
  String? get nextPrayerName => _nextPrayerName;
  CountdownFormat get countdownFormat => _countdownFormat;
  bool get isHmsFormat => _countdownFormat == CountdownFormat.hms;

  /// Uygulamanın aktif locale bilgisini günceller
  void updateLocale(Locale locale) {
    if (_currentLocale == locale) return;
    final previousLanguageCode = _currentLocale.languageCode;
    _currentLocale = locale;
    // Takvim widget'ının yeni dili kullanması için tekrar kaydet
    _lastPublishedWidgetText = null;
    
    // Dil değiştiyse dini günleri yeni dilde yeniden yükle
    if (previousLanguageCode != locale.languageCode && _selectedCityId != null) {
      unawaited(_refreshReligiousDays(_selectedCityId!, _selectedYear));
    }
    
    notifyListeners();
    unawaited(_updateCalendarWidgetWithLocale());
  }

  /// Geri sayım formatını değiştir (toggle) ve kaydet
  Future<void> toggleCountdownFormat() async {
    _countdownFormat =
        (_countdownFormat == CountdownFormat.verbose) ? CountdownFormat.hms : CountdownFormat.verbose;
    await _saveCountdownFormat();
    // Widget metnini de senkronize et (fallback metni için)
    _lastPublishedWidgetText = null; // anında publish edilsin
    notifyListeners();
    await _syncWidget();
  }

  /// Namaz vakitlerini yükler
  Future<void> loadPrayerTimes(int cityId, {int? year}) async {
    if (_isLoading) {
      // Eğer aynı şehir için yükleme devam ediyorsa tekrarlama
      if (cityId == _selectedCityId) return;
    }
    final bool firstLoad = !_hasLoadedOnce;
    final int targetYearEarly = year ?? _selectedYear;
    final bool alreadyLocal = await _prayerTimesService.hasLocalFile(cityId, targetYearEarly);

    _showSkeleton = !firstLoad && !_loadedCityIds.contains(cityId) && !alreadyLocal;

    // Şehir ID'sini kaydet
    _loadedCityIds.add(cityId);
    
    // Skeleton gösterilecekse UI'ı güncelle
    if (_showSkeleton) {
      notifyListeners();
    }
    _hasLoadedOnce = true;
    // Önbellekte varsa ve yeni yükleme değilse, eski veriyi hemen göster
    if (!_showSkeleton && _cachedTodayPrayerTimes.containsKey(cityId)) {
      _todayPrayerTimes = _cachedTodayPrayerTimes[cityId]!;
      notifyListeners();
    }
    final startTime = DateTime.now();
    _setLoading(true);
    _clearError();
    
    try {
      final targetYear = year ?? _selectedYear;
      _selectedCityId = cityId;
      _selectedYear = targetYear;
      
      _prayerTimesResponse = await _prayerTimesService.getPrayerTimes(cityId, targetYear);
      _todayPrayerTimes = await _prayerTimesService.getTodayPrayerTimes(cityId, targetYear);
      _rebuildTodayPrayerDateTimes();
      // Geri sayımı ve UI'ı bekletmeden başlat
      _calculateTimeUntilNextPrayer();
      _startCountdownTimer();
      notifyListeners();
      
      await _refreshReligiousDays(cityId, targetYear);
      // Yüklenen veriyi önbelleğe kaydet
      if (_todayPrayerTimes != null) {
        _cachedTodayPrayerTimes[cityId] = _todayPrayerTimes!;
        final today = _todayPrayerTimes!;
        final tomorrow = _getTomorrowPrayerTimeRelativeTo(today);
        // Ağır yan görevleri UI'ı bloklamadan çalıştır
        unawaited(_persistWidgetData(today, tomorrow));
      }

      // Başarılı yükleme sonrası retry timer'ı iptal et
      _retryTimer?.cancel();
      _retryTimer = null;

      // Yıl sonu/başı: 31 Aralık'ta yeni yıl verisini ön yükle
      final now = DateTime.now();
      if (now.month == 12 && now.day == 31) {
        _prayerTimesService.getPrayerTimes(cityId, _selectedYear + 1);
      }
      // 3 Ocak ve sonrası: önceki yıl verisini hafızadan sil
      if (now.month == 1 && now.day >= 3) {
        await _prayerTimesService.clearLocalFile(cityId, _selectedYear - 1);
      }

      _setLoading(false);
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('SocketException') || errorMsg.contains('Bağlantı')) {
        _setError(ErrorMessages.noInternetConnection(null));
        // Retry mekanizması: bağlantı geri geldiğinde otomatik yeniden yükle
        _retryTimer?.cancel();
        _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
          if (await checkInternetConnection()) {
            timer.cancel();
            _retryTimer = null;
            await loadPrayerTimes(cityId);
          }
        });
      } else if (RegExp(r'HTTP\s404').hasMatch(errorMsg)) {
        _setError(ErrorMessages.dataNotFound(null));
      } else if (RegExp(r'HTTP\s5\d{2}').hasMatch(errorMsg)) {
        _setError(ErrorMessages.serverError(null));
      } else {
        _setError(ErrorMessages.unknownError(null));
      }

      if (_showSkeleton) {
        final elapsed = DateTime.now().difference(startTime);
        const minDuration = Duration(milliseconds: 2500);
        if (elapsed < minDuration) {
          await Future.delayed(minDuration - elapsed);
        }
      }
      _setLoading(false);
      _showSkeleton = false;
    }
  }

  /// Bugün girdisine göre yarının PrayerTime kaydını döndürür (varsa)
  PrayerTime? _getTomorrowPrayerTimeRelativeTo(PrayerTime today) {
    if (_prayerTimesResponse == null) return null;
    final all = _prayerTimesResponse!.prayerTimes;
    final idx = all.indexWhere((e) => e.gregorianDateShortIso8601 == today.gregorianDateShortIso8601);
    if (idx >= 0 && idx + 1 < all.length) {
      return all[idx + 1];
    }
    return null;
  }

  /// Belirli bir tarihin namaz vakitlerini yükler
  Future<PrayerTime?> loadPrayerTimesByDate(DateTime date) async {
    if (_selectedCityId == null) return null;
    
    try {
      return await _prayerTimesService.getPrayerTimesByDate(_selectedCityId!, _selectedYear, date);
    } catch (e) {
      _setError(ErrorMessages.prayerTimesLoadError(date.toString(), e.toString()));
      return null;
    }
  }

  /// Yılı değiştirir ve verileri yeniden yükler
  Future<void> changeYear(int year) async {
    if (_selectedCityId == null || year == _selectedYear) return;
    
    _selectedYear = year;
    await loadPrayerTimes(_selectedCityId!, year: year);
  }

  /// Cache'i temizler
  void clearCache() {
    _prayerTimesService.clearCache();
    _prayerTimesResponse = null;
    _todayPrayerTimes = null;
    _detectedReligiousDays = [];
    _todayPrayerDateTimes.clear();
    _cachedTodayPrayerTimes.clear();
    _loadedCityIds.clear();
    notifyListeners();
  }

  /// Belirli bir şehir için viewmodel önbelleğini temizler
  void clearCacheForCity(int cityId) {
    _cachedTodayPrayerTimes.remove(cityId);
    _loadedCityIds.remove(cityId);
    _todayPrayerDateTimes.clear();
    notifyListeners();
  }

  /// Local dosyaları temizler
  Future<void> clearLocalFiles() async {
    try {
      await _prayerTimesService.clearLocalFiles();
      _prayerTimesResponse = null;
      _todayPrayerTimes = null;
      _detectedReligiousDays = [];
      notifyListeners();
    } catch (e) {
      _setError(ErrorMessages.localFilesClearError(e.toString()));
    }
  }

  /// İnternet bağlantısını kontrol eder
  Future<bool> checkInternetConnection() async {
    return await _prayerTimesService.checkInternetConnection();
  }

  /// Dosya boyutunu alır
  Future<int> getLocalFileSize() async {
    if (_selectedCityId == null) return 0;
    return await _prayerTimesService.getLocalFileSize(_selectedCityId!, _selectedYear);
  }

  /// Bugünün namaz vakitlerini formatlar
  Map<String, String> getFormattedTodayPrayerTimes() {
    if (_todayPrayerTimes == null) return {};
    
    final isArabic = _currentLocale.languageCode == 'ar';
    
    return {
      'İmsak': isArabic ? localizeNumerals(_todayPrayerTimes!.fajr, 'ar') : _todayPrayerTimes!.fajr,
      'Güneş': isArabic ? localizeNumerals(_todayPrayerTimes!.sunrise, 'ar') : _todayPrayerTimes!.sunrise,
      'Öğle': isArabic ? localizeNumerals(_todayPrayerTimes!.dhuhr, 'ar') : _todayPrayerTimes!.dhuhr,
      'İkindi': isArabic ? localizeNumerals(_todayPrayerTimes!.asr, 'ar') : _todayPrayerTimes!.asr,
      'Akşam': isArabic ? localizeNumerals(_todayPrayerTimes!.maghrib, 'ar') : _todayPrayerTimes!.maghrib,
      'Yatsı': isArabic ? localizeNumerals(_todayPrayerTimes!.isha, 'ar') : _todayPrayerTimes!.isha,
    };
  }

  /// Şehir bilgisini alır
  String getCityInfo() {
    if (_prayerTimesResponse?.cityInfo == null) return '';
    return _prayerTimesResponse!.cityInfo.fullName;
  }

  /// Bugünün tarihini aktif dil ayarına göre formatlar
  String getTodayDate({Locale? locale}) {
    if (_todayPrayerTimes == null) return '';
    DateTime? date = DateTime.tryParse(_todayPrayerTimes!.gregorianDateShortIso8601);
    if (date == null) {
      final parts = _todayPrayerTimes!.gregorianDateShort.split('.');
      if (parts.length == 3) {
        date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    }
    if (date == null) return '';
    final Locale effectiveLocale = locale ?? _currentLocale;
    final String localeCode = _localeCodeForIntl(effectiveLocale);
    final isArabic = effectiveLocale.languageCode == 'ar';
    String formattedDate;
    try {
      formattedDate = DateFormat('d MMMM EEEE', localeCode).format(date);
    } catch (_) {
      try {
        formattedDate = DateFormat('d MMMM EEEE', 'en').format(date);
      } catch (_) {
        formattedDate = '${date.day}.${date.month}.${date.year}';
      }
    }
    // Arapça dilinde rakamları Arapça rakamlara dönüştür
    return isArabic ? localizeNumerals(formattedDate, 'ar') : formattedDate;
  }

  /// Hicri tarihi aktif dil ayarına göre formatlar
  String getHijriDate({Locale? locale}) {
    if (_todayPrayerTimes == null) return '';
    final Locale effectiveLocale = locale ?? _currentLocale;
    return _localizeHijriDate(_todayPrayerTimes!.hijriDateLong, effectiveLocale);
  }

  /// Ay resmi URL'ini alır
  String getMoonImageUrl() {
    if (_todayPrayerTimes == null) return '';
    return _todayPrayerTimes!.shapeMoonUrl;
  }

  /// Kıble vaktini alır
  String getQiblaTime() {
    if (_todayPrayerTimes == null) return '';
    return _todayPrayerTimes!.qiblaTime;
  }

  /// Şu anki aktif namaz vaktinin adını döndürür
  String? getCurrentPrayerName() {
    if (_todayPrayerTimes == null) return null;
    if (_todayPrayerDateTimes.isEmpty) {
      _rebuildTodayPrayerDateTimes();
    }
    if (_todayPrayerDateTimes.isEmpty) return null;

    final now = DateTime.now();
    const ordered = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    for (int i = 0; i < ordered.length; i++) {
      final current = _todayPrayerDateTimes[ordered[i]];
      final next = _todayPrayerDateTimes[ordered[(i + 1) % ordered.length]];
      if (current == null || next == null) continue;
      if (i < ordered.length - 1) {
        if (now.isAfter(current) && now.isBefore(next)) {
          return ordered[i];
        }
      } else {
        // Yatsı -> İmsak arası (gece)
        if (now.isAfter(current) || now.isBefore(next)) {
          return ordered[i];
        }
      }
    }
    return null;
  }

  /// Kerahat vakti kontrolü yapar
  /// Kerahat vakitleri:
  /// 1. Güneş doğduktan sonraki 45 dakika
  /// 2. Öğle vaktinden önceki 45 dakika
  /// 3. Akşam vaktinden önceki 45 dakika
  bool isKerahatTime() {
    if (_todayPrayerTimes == null) {
      return false;
    }
    
    if (_todayPrayerDateTimes.isEmpty) {
      _rebuildTodayPrayerDateTimes();
    }

    final sunrise = _todayPrayerDateTimes['Güneş'];
    final dhuhr = _todayPrayerDateTimes['Öğle'];
    final maghrib = _todayPrayerDateTimes['Akşam'];
    final now = DateTime.now();

    if (sunrise == null || dhuhr == null || maghrib == null) {
      return false;
    }

    // 1. Güneş doğduktan sonraki 45 dakika
    final sunriseEnd = sunrise.add(const Duration(minutes: 45));
    if (now.isAfter(sunrise) && now.isBefore(sunriseEnd)) {
      return true;
    }

    // 2. Öğle vaktinden önceki 45 dakika
    final dhuhrStart = dhuhr.subtract(const Duration(minutes: 45));
    if (now.isAfter(dhuhrStart) && now.isBefore(dhuhr)) {
      return true;
    }

    // 3. Akşam vaktinden önceki 45 dakika
    final maghribStart = maghrib.subtract(const Duration(minutes: 45));
    if (now.isAfter(maghribStart) && now.isBefore(maghrib)) {
      return true;
    }

    return false;
  }

  /// Kerahat vakti bilgilerini döndürür (debug için)
  String getKerahatInfo() {
    if (_todayPrayerTimes == null) return 'Vakit bilgisi yok';
    
    final now = DateTime.now();
    final sunrise = _todayPrayerTimes!.sunrise;
    final dhuhr = _todayPrayerTimes!.dhuhr;
    final maghrib = _todayPrayerTimes!.maghrib;
    
    return '''
Şu anki saat: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}

Kerahat Vakitleri:
1. Güneş sonrası: $sunrise - 45 dakika
2. Öğle öncesi: 45 dakika - $dhuhr
3. Akşam öncesi: 45 dakika - $maghrib

Kerahat durumu: ${isKerahatTime() ? "✅ EVET" : "❌ HAYIR"}
''';
  }

  DateTime? _parsePrayerBaseDate(PrayerTime prayer) {
    if (prayer.gregorianDateShortIso8601.isNotEmpty) {
      final parsed = DateTime.tryParse(prayer.gregorianDateShortIso8601);
      if (parsed != null) return parsed;
    }
    final parts = prayer.gregorianDateShort.split('.');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  DateTime? _parseClock(DateTime base, String timeStr) {
    final parts = timeStr.split(":");
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  void _rebuildTodayPrayerDateTimes() {
    _todayPrayerDateTimes.clear();
    final todayPrayer = _todayPrayerTimes;
    if (todayPrayer == null) return;
    final baseDate = _parsePrayerBaseDate(todayPrayer);
    if (baseDate == null) return;

    final Map<String, DateTime?> parsed = {
      'İmsak': _parseClock(baseDate, todayPrayer.fajr),
      'Güneş': _parseClock(baseDate, todayPrayer.sunrise),
      'Öğle': _parseClock(baseDate, todayPrayer.dhuhr),
      'İkindi': _parseClock(baseDate, todayPrayer.asr),
      'Akşam': _parseClock(baseDate, todayPrayer.maghrib),
      'Yatsı': _parseClock(baseDate, todayPrayer.isha),
    };

    parsed.forEach((key, value) {
      if (value != null) {
        _todayPrayerDateTimes[key] = value;
      }
    });
  }

  /// Sonraki namaz vaktine kadar olan süreyi hesaplar
  void _calculateTimeUntilNextPrayer() {
    if (_todayPrayerTimes == null) {
      _timeUntilNextPrayer = null;
      _nextPrayerName = null;
      return;
    }

    if (_todayPrayerDateTimes.isEmpty) {
      _rebuildTodayPrayerDateTimes();
    }
    if (_todayPrayerDateTimes.isEmpty) {
      _timeUntilNextPrayer = null;
      _nextPrayerName = null;
      return;
    }

    final now = DateTime.now();
    const ordered = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    DateTime? nextPrayerTime;
    String? nextPrayerNameLocal;

    for (final name in ordered) {
      final time = _todayPrayerDateTimes[name];
      if (time != null && time.isAfter(now)) {
        nextPrayerTime = time;
        nextPrayerNameLocal = name;
        break;
      }
    }

    // Eğer bugünün hiçbir vakti kalmadıysa, yarının İmsak vaktini al
    nextPrayerTime ??= _todayPrayerDateTimes['İmsak']?.add(const Duration(days: 1));
    nextPrayerNameLocal ??= nextPrayerTime != null ? 'İmsak' : null;

    if (nextPrayerTime != null && nextPrayerNameLocal != null) {
      _timeUntilNextPrayer = nextPrayerTime.difference(now);
      if (_nextPrayerName != nextPrayerNameLocal) {
        // Namaz değiştiğinde yayın anahtarını sıfırla ki ilk turda widget güncellensin
        _lastPublishedWidgetText = null;
        // Dinamik tema rengi için beklemeden güncelle
        if (_themeService.themeColorMode == ThemeColorMode.dynamic) {
          _themeService.checkAndUpdateDynamicColor();
        }
      }
      _nextPrayerName = nextPrayerNameLocal;
    } else {
      _timeUntilNextPrayer = null;
      _nextPrayerName = null;
    }
  }

  /// Geri sayım timer'ını başlatır
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(AnimationConstants.countdownInterval, (timer) {
      _calculateTimeUntilNextPrayer();
      notifyListeners();
      _syncWidget();
    });
    
    // Dinamik tema rengi güncellemesi için timer başlat
    _startThemeUpdateTimer();
  }

  Future<void> _persistWidgetData(PrayerTime today, PrayerTime? tomorrow) async {
    try {
      await WidgetBridgeService.savePrayerTimesForWidget(
        todayIso: today.gregorianDateShortIso8601,
        fajr: today.fajr,
        sunrise: today.sunrise,
        dhuhr: today.dhuhr,
        asr: today.asr,
        maghrib: today.maghrib,
        isha: today.isha,
        tomorrowDateIso: tomorrow?.gregorianDateShortIso8601,
        tomorrowFajr: tomorrow?.fajr,
        tomorrowSunrise: tomorrow?.sunrise,
        tomorrowDhuhr: tomorrow?.dhuhr,
        tomorrowAsr: tomorrow?.asr,
        tomorrowMaghrib: tomorrow?.maghrib,
        tomorrowIsha: tomorrow?.isha,
      );
      final hijriDate = getHijriDate();
      final gregorianDate = getTodayDate();
      await WidgetBridgeService.saveCalendarWidgetData(
        hijriDate: hijriDate,
        gregorianDate: gregorianDate,
      );
      await WidgetBridgeService.forceUpdateCalendarWidget();
      await NotificationSchedulerService.instance.rescheduleTodayNotifications();
    } catch (_) {}
  }

  Future<void> _syncWidget() async {
    if (_nextPrayerName == null || _timeUntilNextPrayer == null) return;
    final themeService = _themeService;
    final String countdownText = getFormattedCountdown();
    final int nextEpochMs = DateTime.now().millisecondsSinceEpoch + _timeUntilNextPrayer!.inMilliseconds;
    final String publishKey = '${_nextPrayerName}|$countdownText|$nextEpochMs';
    if (_lastPublishedWidgetText == publishKey) {
      // Metin değişmediyse gereksiz native güncelleme yapma
      return;
    }
    final int currentColor = themeService.currentThemeColor.value;
    final int selectedColor = themeService.selectedThemeColor.value;
    await WidgetBridgeService.saveWidgetData(
      nextPrayerName: _nextPrayerName!,
      countdownText: countdownText,
      currentThemeColor: currentColor,
      selectedThemeColor: selectedColor,
      nextEpochMs: nextEpochMs,
    );
    await WidgetBridgeService.forceUpdateSmallWidget();
    
    // Takvim widget için tarih verilerini kaydet
    if (_todayPrayerTimes != null) {
      final hijriDate = getHijriDate();
      final gregorianDate = getTodayDate();
      await WidgetBridgeService.saveCalendarWidgetData(
        hijriDate: hijriDate,
        gregorianDate: gregorianDate,
      );
      await WidgetBridgeService.forceUpdateCalendarWidget();
    }
    
    _lastPublishedWidgetText = publishKey;
  }

  Future<void> _updateCalendarWidgetWithLocale() async {
    if (_todayPrayerTimes == null) return;
    try {
      final hijriDate = getHijriDate();
      final gregorianDate = getTodayDate();
      await WidgetBridgeService.saveCalendarWidgetData(
        hijriDate: hijriDate,
        gregorianDate: gregorianDate,
      );
      await WidgetBridgeService.forceUpdateCalendarWidget();
    } catch (_) {}
  }

  String _localizeHijriDate(String raw, Locale locale) {
    final match = _hijriDatePattern.firstMatch(raw.trim());
    if (match == null) return raw;
    final day = match.group(1)!;
    final month = match.group(2)!;
    final year = match.group(3)!;
    final normalized = normalizeHijriMonthLabel(month);
    final canonical = hijriMonthCanonical[normalized];
    if (canonical == null) return raw;
    final translations = hijriMonthTranslations[canonical];
    if (translations == null) return raw;
    final localizedMonth =
        translations[locale.languageCode] ?? translations['tr'];
    if (localizedMonth == null || localizedMonth.isEmpty) {
      return raw;
    }
    
    // Arapça dilinde rakamları Arapça rakamlara dönüştür
    final localizedDay = localizeNumerals(day, locale.languageCode);
    final localizedYear = localizeNumerals(year, locale.languageCode);
    
    return '$localizedDay $localizedMonth $localizedYear';
  }

  String _localeCodeForIntl(Locale locale) {
    final countryCode = locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      return '${locale.languageCode}_$countryCode';
    }
    return locale.languageCode;
  }
  
  
  /// Dinamik tema rengi güncellemesi için timer başlatır
  void _startThemeUpdateTimer() {
    _themeUpdateTimer?.cancel();
    // Her 30 saniyede bir tema rengini kontrol et
    _themeUpdateTimer = Timer.periodic(AnimationConstants.themeUpdateInterval, (timer) {
      _themeService.checkAndUpdateDynamicColor();
    });
  }

  

  /// Geri sayım timer'ını durdurur
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Geri sayım formatını döndürür
  String getFormattedCountdown({String? hourText, String? minuteText, String? minuteShortText, String? secondText}) {
    if (_timeUntilNextPrayer == null) return '';

    final duration = _timeUntilNextPrayer!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final isArabic = _currentLocale.languageCode == 'ar';

    if (_countdownFormat == CountdownFormat.hms) {
      final hh = hours.toString().padLeft(2, '0');
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      final formatted = '$hh:$mm:$ss';
      return isArabic ? localizeNumerals(formatted, 'ar') : formatted;
    } else {
      // Varsayılan değerler (geriye dönük uyumluluk için)
      final hour = hourText ?? 'saat';
      final minute = minuteText ?? 'dakika';
      final minuteShort = minuteShortText ?? 'dk';
      final second = secondText ?? 'saniye';
      
      List<String> parts = [];
      if (hours > 0) {
        final hoursStr = isArabic ? localizeNumerals(hours.toString(), 'ar') : hours.toString();
        parts.add('$hoursStr$hour');
      }
      if (minutes > 0) {
        final minutesStr = isArabic ? localizeNumerals(minutes.toString(), 'ar') : minutes.toString();
        if (hours > 0) {
          parts.add('$minutesStr$minuteShort');
        } else {
          parts.add('$minutesStr$minute');
        }
      }
      if (hours == 0 && minutes == 0) {
        final secondsStr = isArabic ? localizeNumerals(seconds.toString(), 'ar') : seconds.toString();
        parts.add('$secondsStr$second');
      }
      return parts.join(' ');
    }
  }

  /// Loading durumunu ayarlar
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (!loading) {
      _showSkeleton = false;
    }
    notifyListeners();
  }

  /// Hata mesajını ayarlar ve cache'i temizler
  void _setError(String message) {
    _errorMessage = message;
    // Hata durumunda cache'i otomatik temizle
    if (_selectedCityId != null) {
      _cachedTodayPrayerTimes.remove(_selectedCityId);
      _loadedCityIds.remove(_selectedCityId);
      _todayPrayerTimes = null;
    }
    _todayPrayerDateTimes.clear();
    notifyListeners();
  }

  /// Hata mesajını temizler
  void _clearError() {
    _errorMessage = null;
    _errorCode = null;
  }

  /// Hata mesajını temizler (public method)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// UI katmanında hata mesajını oluşturur
  String? getErrorMessage(BuildContext? context) {
    if (_errorCode != null && context != null) {
      return ErrorMessages.fromErrorCode(context, _errorCode!);
    }
    return _errorMessage;
  }

  /// Yıl değişimini izleyen timer başlatır
  Timer? _yearChangeTimer;
  
  void _startYearChangeMonitor() {
    _yearChangeTimer?.cancel();
    // Her saat başı yıl değişimini kontrol et
    _yearChangeTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkYearChange();
    });
  }

  /// Yıl değişimini kontrol eder ve gerekirse dini günleri günceller
  Future<void> _checkYearChange() async {
    final currentYear = DateTime.now().year;
    
    if (currentYear != _lastCheckedYear) {
      // Yıl değişti, dini günleri güncelle
      if (_selectedCityId != null) {
        await _updateReligiousDaysForYearChange(currentYear);
      }
      
      _lastCheckedYear = currentYear;
      await _saveLastCheckedYear();
    }
  }

  /// Yıl değişiminde dini günleri günceller
  /// Sadece bu yılın verisini kullanarak hicri tarihlerden dini günleri tespit eder
  Future<void> _updateReligiousDaysForYearChange(int newYear) async {
    if (_selectedCityId == null) return;
    
    try {
      await _refreshReligiousDays(_selectedCityId!, newYear);
      
      // Eski yılın cache'ini temizle (2 yıl öncesi)
      await _clearReligiousDaysCache(newYear - 2);
      
      notifyListeners();
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  /// Dini günleri cache'e kaydeder
  Future<void> _saveReligiousDaysToCache(int year, List<DetectedReligiousDay> days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          days.map((day) => day.toMap()).toList();
      
      await prefs.setString('religious_days_$year', jsonEncode(jsonList));
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  /// Cache'deki dini günleri okur
  Future<List<DetectedReligiousDay>?> _loadReligiousDaysFromCache(int year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('religious_days_$year');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! List) return null;

      final List<DetectedReligiousDay> items = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          items.add(DetectedReligiousDay.fromMap(item));
        }
      }
      return items;
    } catch (e) {
      return null;
    }
  }


  /// Belirli bir yılın dini günler cache'ini temizler
  Future<void> _clearReligiousDaysCache(int year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('religious_days_$year');
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  /// Son kontrol edilen yılı yükler
  Future<void> _loadLastCheckedYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCheckedYear = prefs.getInt('last_checked_year') ?? DateTime.now().year;
    } catch (_) {}
  }

  /// Son kontrol edilen yılı kaydeder
  Future<void> _saveLastCheckedYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_checked_year', _lastCheckedYear);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    _themeUpdateTimer?.cancel();
    _yearChangeTimer?.cancel();
    super.dispose();
  }

  // Kalıcı tercih: geri sayım formatı
  Future<void> _loadCountdownFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nv_countdown_format');
      if (saved != null) {
        _countdownFormat = CountdownFormat.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => CountdownFormat.verbose,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveCountdownFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nv_countdown_format', _countdownFormat.name);
    } catch (_) {}
  }

  Future<void> _refreshReligiousDays(int _cityId, int targetYear) async {
    // Eğer prayerTimesResponse yüklüyse, ondan dini günleri tespit et
    if (_prayerTimesResponse != null && _prayerTimesResponse!.year == targetYear) {
      final days = _religiousDaysService.detectFrom(_prayerTimesResponse!);
      _detectedReligiousDays = days;
      // Cache'e kaydet
      await _saveReligiousDaysToCache(targetYear, days);
      notifyListeners();
      return;
    }

    // Eğer response yoksa veya yıl farklıysa cache'den oku
    final years = [targetYear - 1, targetYear, targetYear + 1];
    final List<DetectedReligiousDay> aggregated = [];

    for (final year in years) {
      final days = await _loadYearReligiousDaysFromCache(year);
      aggregated.addAll(days);
    }

    aggregated.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    _detectedReligiousDays = aggregated;
    notifyListeners();
  }

  Future<List<DetectedReligiousDay>> _loadYearReligiousDaysFromCache(int year) async {
    try {
      final cachedDays = await _loadReligiousDaysFromCache(year);
      return cachedDays ?? <DetectedReligiousDay>[];
    } catch (_) {
      return <DetectedReligiousDay>[];
    }
  }
} 

final RegExp _hijriDatePattern = RegExp(r'^(\d{1,2})\s+(.+?)\s+(\d{3,4})$');

/// Geri sayım metni için iki görünüm modu
enum CountdownFormat { verbose, hms }