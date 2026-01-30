import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../utils/app_logger.dart';
import '../utils/app_keys.dart';
import '../services/theme_service.dart';

enum SettingsPage {
  main,
  themeColor,
  notifications,
  language,
}

enum AppLanguage {
  turkish,
  english,
  arabic,
}

class SettingsViewModel extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();
  VoidCallback? _themeServiceListener;

  SettingsPage _currentPage = SettingsPage.main;
  bool _isExpanded = false;

  // Tema modu (kullanıcının manuel seçimi)
  AppThemeMode _manualThemeMode = AppThemeMode.system;

  // Otomatik karanlık mod kontrolü için timer
  Timer? _autoDarkModeTimer;

  // Tema renkleri - artık ThemeService'ten alınıyor
  final List<Color> _themeColors = [
    const Color(0xFF588065), // primaryColor
    const Color(0xFF728EAD), // İmsak
    const Color(0xFFF9C784), // Güneş
    const Color(0xFFDDBF50), // Öğle
    const Color(0xFFE8BCAD), // İkindi
    const Color(0xFF91C7F0), // Akşam
    const Color(0xFFB39DDB), // Yatsı
  ];

  // Dil ayarları
  AppLanguage _selectedLanguage = AppLanguage.turkish;

  // Bildirim ayarları
  bool _notificationsEnabled = true;
  bool _prayerTimeNotifications = true;
  bool _dailyReminders = false;
  bool _weeklyReminders = false;

  // Otomatik karanlık mod
  bool _autoDarkMode = false;

  // Getters
  SettingsPage get currentPage => _currentPage;
  bool get isExpanded => _isExpanded;

  /// Tema modu getter'ı
  /// Artık autoDarkMode'dan etkilenmez, manuel seçimi döndürür
  AppThemeMode get themeMode => _manualThemeMode;
  List<Color> get themeColors => _themeColors;

  // Tema rengi bilgilerini ThemeService'ten al
  Color get selectedThemeColor => _themeService.selectedThemeColor;
  ThemeColorMode get themeColorMode => _themeService.themeColorMode;
  Color get currentThemeColor => _themeService.currentThemeColor;
  String? get currentPrayerTime => _themeService.currentPrayerTime;

  AppLanguage get selectedLanguage => _selectedLanguage;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get prayerTimeNotifications => _prayerTimeNotifications;
  bool get dailyReminders => _dailyReminders;
  bool get weeklyReminders => _weeklyReminders;
  bool get autoDarkMode => _autoDarkMode;

  // Actions
  void toggleExpansion() {
    _isExpanded = !_isExpanded;
    if (!_isExpanded) {
      _currentPage = SettingsPage.main;
    }
    notifyListeners();
  }

  void showThemeColorPage() {
    _currentPage = SettingsPage.themeColor;
    notifyListeners();
  }

  void showNotificationsPage() {
    _currentPage = SettingsPage.notifications;
    notifyListeners();
  }

  void showLanguagePage() {
    _currentPage = SettingsPage.language;
    notifyListeners();
  }

  void showMainPage() {
    _currentPage = SettingsPage.main;
    notifyListeners();
  }

  // Tema rengi seçimi - ThemeService'e yönlendir
  Future<void> selectThemeColor(Color color) async {
    await _themeService.setSelectedThemeColor(color);
    notifyListeners(); // UI güncellemesi için
  }

  // Tema rengi modu değiştir - ThemeService'e yönlendir
  Future<void> changeThemeColorMode(ThemeColorMode mode) async {
    // Eğer autoDarkMode aktifse ve kullanıcı manuel bir değişiklik yapıyorsa,
    // orijinal tema modunu güncellemeliyiz ki sabah ona dönsün.
    if (_autoDarkMode) {
      final prefs = await SharedPreferences.getInstance();
      final originalSaved =
          prefs.getString(AppKeys.autoDarkModeOriginalThemeColorMode);
      if (originalSaved != null) {
        // Eğer gece vaktindeysek ve kullanıcı siyah tema dışında bir şey seçerse,
        // bunu orijinal olarak kaydet ama o anki seçimini de uygula (siyah zorunlu değil).
        await prefs.setString(
            AppKeys.autoDarkModeOriginalThemeColorMode, mode.name);
      }
    }

    await _themeService.setThemeColorMode(mode);
    notifyListeners(); // UI güncellemesi için
  }

  Future<void> changeThemeMode(AppThemeMode mode) async {
    if (_manualThemeMode == mode) return;

    _manualThemeMode = mode;
    await _saveThemeMode(mode);
    notifyListeners();
  }

  // Tema modunu kaydet
  Future<void> _saveThemeMode(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppKeys.appThemeMode, mode.name);
    } catch (e) {
      AppLogger.error('Tema modu kaydetme hatası', tag: 'Settings', error: e);
    }
  }

  // Tema modunu yükle
  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(AppKeys.appThemeMode);
      if (savedMode != null) {
        _manualThemeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => AppThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Tema modu yükleme hatası', tag: 'Settings', error: e);
    }
  }

  /// Güneş doğuşu zamanını kullanarak otomatik tema modunu hesaplar ve uygular
  /// 00:00 ile güneş doğuşu arası 'Karanlık' tema rengini seçer
  /// Güneş doğuşu ile 00:00 (yarınki) arası orijinal tema rengine döner
  Future<void> _updateAutoThemeMode() async {
    if (!_autoDarkMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sunriseStr = prefs.getString(AppKeys.prayerSunrise);

      if (sunriseStr == null || sunriseStr.isEmpty) return;

      // Güneş doğuşu zamanını parse et (HH:mm formatında)
      final parts = sunriseStr.split(':');
      if (parts.length != 2) return;

      final sunriseHour = int.tryParse(parts[0]);
      final sunriseMinute = int.tryParse(parts[1]);

      if (sunriseHour == null || sunriseMinute == null) return;

      final now = DateTime.now();
      final todaySunrise =
          DateTime(now.year, now.month, now.day, sunriseHour, sunriseMinute);
      final midnight = DateTime(now.year, now.month, now.day, 0, 0);

      // 00:00 ile güneş doğuşu arası gece sayılır
      final bool isNight = now.isAfter(midnight) && now.isBefore(todaySunrise);

      if (isNight) {
        // Gece ve henüz karanlık temaya geçilmemişse
        if (_themeService.themeColorMode != ThemeColorMode.black) {
          // Orijinal modu kaydet (eğer zaten kaydedilmemişse)
          final originalSaved =
              prefs.getString(AppKeys.autoDarkModeOriginalThemeColorMode);
          if (originalSaved == null) {
            await prefs.setString(AppKeys.autoDarkModeOriginalThemeColorMode,
                _themeService.themeColorMode.name);
          }
          // Karanlık temaya geç
          await _themeService.setThemeColorMode(ThemeColorMode.black);
          notifyListeners();
        }
      } else {
        // Gündüz ve kaydedilmiş bir orijinal mod varsa geri dön
        final originalSaved =
            prefs.getString(AppKeys.autoDarkModeOriginalThemeColorMode);
        if (originalSaved != null) {
          final originalMode = ThemeColorMode.values.firstWhere(
            (m) => m.name == originalSaved,
            orElse: () => ThemeColorMode.static,
          );
          await _themeService.setThemeColorMode(originalMode);
          await prefs.remove(AppKeys.autoDarkModeOriginalThemeColorMode);
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.error('Auto dark mode güncelleme hatası',
          tag: 'Settings', error: e);
    }
  }

  /// Otomatik karanlık mod geçişini bir sonraki vakte planlar
  void _scheduleNextAutoDarkModeTransition() {
    _autoDarkModeTimer?.cancel();
    _autoDarkModeTimer = null;

    if (!_autoDarkMode) return;

    // Şu anki durumu kontrol et ve uygula
    // ignore: unawaited_futures
    unawaited(_updateAutoThemeMode());

    try {
      final now = DateTime.now();

      // 1) Sıradaki gece yarısı (00:00)
      final tomorrowMidnight =
          DateTime(now.year, now.month, now.day + 1, 0, 0, 1);

      // 2) Sıradaki gün doğumu
      // SharedPreferences'tan bugün ve yarın güneş vakitlerini alalım
      // Not: Basitlik adına her zaman 2 saniye sonra tekrar planlama yapacak bir Timer kurabiliriz
      // ama en iyisi bir sonraki olası vakti bulmaktır.

      Future<void> findAndSchedule() async {
        final prefs = await SharedPreferences.getInstance();
        final sunriseStr = prefs.getString(AppKeys.prayerSunrise);
        if (sunriseStr == null || sunriseStr.isEmpty) {
          // Vakit yoksa 1 saat sonra tekrar dene
          _autoDarkModeTimer = Timer(
              const Duration(hours: 1), _scheduleNextAutoDarkModeTransition);
          return;
        }

        final parts = sunriseStr.split(':');
        final sunriseHour = int.tryParse(parts[0]) ?? 6;
        final sunriseMinute = int.tryParse(parts[1]) ?? 0;

        final todaySunrise = DateTime(
            now.year, now.month, now.day, sunriseHour, sunriseMinute, 1);

        DateTime nextTransition;
        if (now.isBefore(todaySunrise)) {
          nextTransition = todaySunrise;
        } else if (now.isBefore(tomorrowMidnight)) {
          nextTransition = tomorrowMidnight;
        } else {
          nextTransition = tomorrowMidnight.add(const Duration(seconds: 5));
        }

        final duration = nextTransition.difference(now);
        _autoDarkModeTimer =
            Timer(duration, _scheduleNextAutoDarkModeTransition);
        AppLogger.debug(
            'Oto karartma sıradaki geçiş planlandı: $nextTransition (Süre: $duration)',
            tag: 'Settings');
      }

      findAndSchedule();
    } catch (e) {
      // Hata durumunda güvenli bir süre sonra tekrar dene
      _autoDarkModeTimer = Timer(
          const Duration(minutes: 5), _scheduleNextAutoDarkModeTransition);
    }
  }

  void selectLanguage(AppLanguage language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  String getLanguageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.turkish:
        return 'Türkçe';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.arabic:
        return 'العربية';
    }
  }

  String getLanguageFlag(AppLanguage language) {
    switch (language) {
      case AppLanguage.turkish:
        return '🇹🇷';
      case AppLanguage.english:
        return '🇺🇸';
      case AppLanguage.arabic:
        return '🇸🇦';
    }
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
  }

  void togglePrayerTimeNotifications() {
    _prayerTimeNotifications = !_prayerTimeNotifications;
    notifyListeners();
  }

  void toggleDailyReminders() {
    _dailyReminders = !_dailyReminders;
    notifyListeners();
  }

  void toggleWeeklyReminders() {
    _weeklyReminders = !_weeklyReminders;
    notifyListeners();
  }

  void setAutoDarkMode(bool value) async {
    if (_autoDarkMode == value) return;
    _autoDarkMode = value;
    await _saveAutoDarkMode(value);

    if (value) {
      _scheduleNextAutoDarkModeTransition();
    } else {
      _autoDarkModeTimer?.cancel();
      _autoDarkModeTimer = null;

      // Eğer geçersiz kılınmış bir tema varsa geri dön
      try {
        final prefs = await SharedPreferences.getInstance();
        final originalSaved =
            prefs.getString(AppKeys.autoDarkModeOriginalThemeColorMode);
        if (originalSaved != null) {
          final originalMode = ThemeColorMode.values.firstWhere(
            (m) => m.name == originalSaved,
            orElse: () => ThemeColorMode.static,
          );
          await _themeService.setThemeColorMode(originalMode);
          await prefs.remove(AppKeys.autoDarkModeOriginalThemeColorMode);
        }
      } catch (e) {
        AppLogger.error('Auto dark mode kapatma hatası',
            tag: 'Settings', error: e);
      }
    }
    notifyListeners();
  }

  Future<void> _saveAutoDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppKeys.autoDarkMode, value);
    } catch (e) {
      AppLogger.error('Auto dark mode kaydetme hatası',
          tag: 'Settings', error: e);
    }
  }

  Future<void> loadAutoDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(AppKeys.autoDarkMode);
      if (saved != null) {
        _autoDarkMode = saved;
        if (_autoDarkMode) {
          // Yükledikten sonra geçişi planla
          _scheduleNextAutoDarkModeTransition();
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Auto dark mode yükleme hatası',
          tag: 'Settings', error: e);
    }
  }

  void collapse() {
    _isExpanded = false;
    _currentPage = SettingsPage.main;
    notifyListeners();
  }

  // ThemeService'i dinle
  void startListeningToThemeService() {
    // Önceki listener'ı temizle
    if (_themeServiceListener != null) {
      _themeService.removeListener(_themeServiceListener!);
    }
    _themeServiceListener = () {
      notifyListeners();
    };
    _themeService.addListener(_themeServiceListener!);
  }

  @override
  void dispose() {
    if (_themeServiceListener != null) {
      _themeService.removeListener(_themeServiceListener!);
      _themeServiceListener = null;
    }
    _autoDarkModeTimer?.cancel();
    _autoDarkModeTimer = null;
    super.dispose();
  }

  // Dinamik renk güncellemesini tetikle
  void updateDynamicColor() {
    _themeService.checkAndUpdateDynamicColor();
  }
}
