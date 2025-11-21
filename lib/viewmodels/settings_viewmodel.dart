import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/theme_service.dart';
import '../services/xiaomi_compatibility_service.dart';

enum SettingsPage {
  main,
  themeColor,
  notifications,
  language,
  xiaomiCompatibility,
}

enum AppLanguage {
  turkish,
  english,
  arabic,
}

class SettingsViewModel extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();

  SettingsPage _currentPage = SettingsPage.main;
  bool _isExpanded = false;

  // Xiaomi uyumluluk özellikleri
  bool _isXiaomiDevice = false;
  bool _xiaomiAutoStartEnabled = false;
  bool _xiaomiBatteryOptimizationDisabled = false;
  bool _xiaomiNotificationsEnabled = false;
  bool _xiaomiCompatibilityChecked = false;
  
  // Tema modu
  AppThemeMode _themeMode = AppThemeMode.system;
  
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
  
  // Getters
  SettingsPage get currentPage => _currentPage;
  bool get isExpanded => _isExpanded;
  AppThemeMode get themeMode => _themeMode;
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

  // Xiaomi uyumluluk getter'ları
  bool get isXiaomiDevice => _isXiaomiDevice;
  bool get xiaomiAutoStartEnabled => _xiaomiAutoStartEnabled;
  bool get xiaomiBatteryOptimizationDisabled => _xiaomiBatteryOptimizationDisabled;
  bool get xiaomiNotificationsEnabled => _xiaomiNotificationsEnabled;
  bool get xiaomiCompatibilityChecked => _xiaomiCompatibilityChecked;
  bool get showXiaomiWarning => _isXiaomiDevice && !_xiaomiCompatibilityChecked;
  
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

  void showXiaomiCompatibilityPage() {
    _currentPage = SettingsPage.xiaomiCompatibility;
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
    await _themeService.setThemeColorMode(mode);
    notifyListeners(); // UI güncellemesi için
  }
  
  Future<void> changeThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _saveThemeMode(mode);
    notifyListeners();
  }
  
  // Tema modunu kaydet
  Future<void> _saveThemeMode(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', mode.name);
    } catch (e) {
      debugPrint('Tema modu kaydetme hatası: $e');
    }
  }
  
  // Tema modunu yükle
  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('app_theme_mode');
      if (savedMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => AppThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Tema modu yükleme hatası: $e');
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
  
  void collapse() {
    _isExpanded = false;
    _currentPage = SettingsPage.main;
    notifyListeners();
  }
  
  // ThemeService'i dinle
  void startListeningToThemeService() {
    _themeService.addListener(() {
      notifyListeners();
    });
  }
  
  // Dinamik renk güncellemesini tetikle
  void updateDynamicColor() {
    _themeService.checkAndUpdateDynamicColor();
  }

  // Xiaomi uyumluluk methodları
  Future<void> checkXiaomiCompatibility() async {
    _isXiaomiDevice = XiaomiCompatibilityService.isXiaomiDevice();

    if (_isXiaomiDevice) {
      try {
        final compatibility = await XiaomiCompatibilityService.checkXiaomiCompatibility();
        _xiaomiAutoStartEnabled = compatibility['autoStartEnabled'] ?? false;
        _xiaomiBatteryOptimizationDisabled = compatibility['batteryOptimizationDisabled'] ?? false;
        _xiaomiNotificationsEnabled = compatibility['notificationsEnabled'] ?? false;
        _xiaomiCompatibilityChecked = true;
      } catch (e) {
        _xiaomiCompatibilityChecked = false;
      }
    } else {
      _xiaomiAutoStartEnabled = true;
      _xiaomiBatteryOptimizationDisabled = true;
      _xiaomiNotificationsEnabled = true;
      _xiaomiCompatibilityChecked = true;
    }

    notifyListeners();
  }

  Future<void> applyXiaomiOptimizations() async {
    if (!_isXiaomiDevice) return;

    try {
      await XiaomiCompatibilityService.applyXiaomiOptimizations();
      await checkXiaomiCompatibility(); // Durumu tekrar kontrol et
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  Future<bool> openXiaomiAutoStartSettings() async {
    if (!_isXiaomiDevice) return false;

    try {
      final result = await XiaomiCompatibilityService.openXiaomiAutoStartSettings();
      if (result) {
        await checkXiaomiCompatibility(); // Durumu güncelle
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> getXiaomiCompatibilityMessages() {
    return XiaomiCompatibilityService.getCompatibilityMessages();
  }

  List<String> getXiaomiPerformanceTips() {
    return XiaomiCompatibilityService.getPerformanceTips();
  }
} 