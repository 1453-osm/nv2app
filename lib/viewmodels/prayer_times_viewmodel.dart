import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_times_model.dart';
import '../services/prayer_times_service.dart';
import '../services/theme_service.dart';
import '../services/widget_bridge.dart';
import '../services/religious_days_service.dart';
import '../services/notification_scheduler_service.dart';
import '../models/religious_day.dart';
import '../utils/constants.dart';
import 'dart:async';
 

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
  int? _selectedCityId;
  int _selectedYear = DateTime.now().year;
  
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

  PrayerTimesViewModel() {
    _loadCountdownFormat();
  }

  // Getters
  PrayerTimesResponse? get prayerTimesResponse => _prayerTimesResponse;
  PrayerTime? get todayPrayerTimes => _todayPrayerTimes;
  List<DetectedReligiousDay> get detectedReligiousDays => _detectedReligiousDays;

  /// Dini günleri yeniden hesaplar (ör. modal açılmadan önce çağrılabilir)
  void recomputeReligiousDays() {
    if (_prayerTimesResponse == null) return;
    _detectedReligiousDays = _religiousDaysService.detectFrom(_prayerTimesResponse!);
    notifyListeners();
  }
  bool get isLoading => _isLoading;
  bool get showSkeleton => _showSkeleton;
  String? get errorMessage => _errorMessage;
  int? get selectedCityId => _selectedCityId;
  int get selectedYear => _selectedYear;
  Duration? get timeUntilNextPrayer => _timeUntilNextPrayer;
  String? get nextPrayerName => _nextPrayerName;
  CountdownFormat get countdownFormat => _countdownFormat;
  bool get isHmsFormat => _countdownFormat == CountdownFormat.hms;

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
      // Dini günleri tespit et
      _detectedReligiousDays = _religiousDaysService
          .detectFrom(_prayerTimesResponse!);
      // Yüklenen veriyi önbelleğe kaydet
      if (_todayPrayerTimes != null) {
        _cachedTodayPrayerTimes[cityId] = _todayPrayerTimes!;
      }
      
      // Geri sayımı başlat
      _calculateTimeUntilNextPrayer();
      _startCountdownTimer();
      // Widget için bugünün vakitlerini de sakla (arkaplan senaryosu için)
      if (_todayPrayerTimes != null) {
        final today = _todayPrayerTimes!;
        final tomorrow = _getTomorrowPrayerTimeRelativeTo(today);
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
        // Vakitler kaydedildikten sonra bugünün bildirimlerini yeniden planla
        await NotificationSchedulerService.instance.rescheduleTodayNotifications();
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
        _setError('İnternet bağlantısı yok.');
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
        _setError('Veri bulunamadı.');
      } else if (RegExp(r'HTTP\s5\d{2}').hasMatch(errorMsg)) {
        _setError('Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.');
      } else {
        _setError('Bilinmeyen hata oluştu.');
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
      _setError('$date tarihinin namaz vakitleri yüklenirken hata oluştu: $e');
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
    _cachedTodayPrayerTimes.clear();
    _loadedCityIds.clear();
    notifyListeners();
  }

  /// Belirli bir şehir için viewmodel önbelleğini temizler
  void clearCacheForCity(int cityId) {
    _cachedTodayPrayerTimes.remove(cityId);
    _loadedCityIds.remove(cityId);
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
      _setError('Local dosyalar temizlenirken hata oluştu: $e');
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
    
    return {
      'İmsak': _todayPrayerTimes!.fajr,
      'Güneş': _todayPrayerTimes!.sunrise,
      'Öğle': _todayPrayerTimes!.dhuhr,
      'İkindi': _todayPrayerTimes!.asr,
      'Akşam': _todayPrayerTimes!.maghrib,
      'Yatsı': _todayPrayerTimes!.isha,
    };
  }

  /// Şehir bilgisini alır
  String getCityInfo() {
    if (_prayerTimesResponse?.cityInfo == null) return '';
    return _prayerTimesResponse!.cityInfo.fullName;
  }

  /// Bugünün tarihini alır
  String getTodayDate() {
    if (_todayPrayerTimes == null) return '';
    DateTime? date = DateTime.tryParse(_todayPrayerTimes!.gregorianDateShortIso8601);
    if (date == null) {
      final parts = _todayPrayerTimes!.gregorianDateShort.split('.');
      if (parts.length == 3) {
        date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    }
    if (date == null) return '';
    const List<String> months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    const List<String> weekdays = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final day = date.day;
    final monthName = months[date.month];
    final weekdayName = weekdays[date.weekday];
    return '$day $monthName $weekdayName';
  }

  /// Hicri tarihi alır
  String getHijriDate() {
    if (_todayPrayerTimes == null) return '';
    return _todayPrayerTimes!.hijriDateLong;
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
    final now = DateTime.now();
    final times = {
      'İmsak': _todayPrayerTimes!.fajr,
      'Güneş': _todayPrayerTimes!.sunrise,
      'Öğle': _todayPrayerTimes!.dhuhr,
      'İkindi': _todayPrayerTimes!.asr,
      'Akşam': _todayPrayerTimes!.maghrib,
      'Yatsı': _todayPrayerTimes!.isha,
    };
    DateTime? parseTime(String t) {
      final parts = t.split(":");
      if (parts.length != 2) return null;
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    final vakitler = times.entries.map((e) => MapEntry(e.key, parseTime(e.value))).toList();
    for (int i = 0; i < vakitler.length; i++) {
      final current = vakitler[i].value;
      final next = vakitler[(i + 1) % vakitler.length].value;
      if (current == null || next == null) continue;
      if (i < vakitler.length - 1) {
        if (now.isAfter(current) && now.isBefore(next)) {
          return vakitler[i].key;
        }
      } else {
        // Yatsı -> İmsak arası (gece)
        if (now.isAfter(current) || now.isBefore(next)) {
          return vakitler[i].key;
        }
      }
    }
    return null;
  }

  /// Sonraki namaz vaktine kadar olan süreyi hesaplar
  void _calculateTimeUntilNextPrayer() {
    if (_todayPrayerTimes == null) {
      _timeUntilNextPrayer = null;
      _nextPrayerName = null;
      return;
    }

    final now = DateTime.now();
    final times = {
      'İmsak': _todayPrayerTimes!.fajr,
      'Güneş': _todayPrayerTimes!.sunrise,
      'Öğle': _todayPrayerTimes!.dhuhr,
      'İkindi': _todayPrayerTimes!.asr,
      'Akşam': _todayPrayerTimes!.maghrib,
      'Yatsı': _todayPrayerTimes!.isha,
    };

    DateTime? parseTime(String timeStr) {
      final parts = timeStr.split(":");
      if (parts.length != 2) return null;
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }

    final prayerTimes = times.entries
        .map((e) => MapEntry(e.key, parseTime(e.value)))
        .where((e) => e.value != null)
        .toList();

    DateTime? nextPrayerTime;
    String? nextPrayerNameLocal;

    // Önce bugünün kalan vakitlerini kontrol et
    for (final entry in prayerTimes) {
      final prayerTime = entry.value!;
      if (prayerTime.isAfter(now)) {
        nextPrayerTime = prayerTime;
        nextPrayerNameLocal = entry.key;
        break;
      }
    }

    // Eğer bugünün hiçbir vakti kalmadıysa, yarının İmsak vaktini al
    if (nextPrayerTime == null) {
      final tomorrowFajr = parseTime(_todayPrayerTimes!.fajr);
      if (tomorrowFajr != null) {
        nextPrayerTime = tomorrowFajr.add(const Duration(days: 1));
        nextPrayerNameLocal = 'İmsak';
      }
    }

    if (nextPrayerTime != null && nextPrayerNameLocal != null) {
      _timeUntilNextPrayer = nextPrayerTime.difference(now);
      if (_nextPrayerName != nextPrayerNameLocal) {
        // Namaz değiştiğinde yayın anahtarını sıfırla ki ilk turda widget güncellensin
        _lastPublishedWidgetText = null;
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
    _lastPublishedWidgetText = publishKey;
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
  String getFormattedCountdown() {
    if (_timeUntilNextPrayer == null) return '';

    final duration = _timeUntilNextPrayer!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (_countdownFormat == CountdownFormat.hms) {
      final hh = hours.toString().padLeft(2, '0');
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    } else {
      List<String> parts = [];
      if (hours > 0) {
        parts.add('${hours}saat');
      }
      if (minutes > 0) {
        if (hours > 0) {
          parts.add('${minutes}dk');
        } else {
          parts.add('${minutes}dakika');
        }
      }
      if (hours == 0 && minutes == 0) {
        parts.add('${seconds}saniye');
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
    notifyListeners();
  }

  /// Hata mesajını temizler
  void _clearError() {
    _errorMessage = null;
  }

  /// Hata mesajını temizler (public method)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    _themeUpdateTimer?.cancel();
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
} 

/// Geri sayım metni için iki görünüm modu
enum CountdownFormat { verbose, hms }