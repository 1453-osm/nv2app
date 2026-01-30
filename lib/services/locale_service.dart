import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import '../utils/rtl_helper.dart';
import '../utils/app_keys.dart';
import '../utils/app_logger.dart';

/// Dil yönetimi servisi.
///
/// Bu servis şunları yönetir:
/// - Uygulama dilini yükleme ve kaydetme
/// - RTL/LTR metin yönü belirleme
/// - Desteklenen dilleri listeleme
/// - Otomatik dil algılama ve cihaz dilini dinleme
class LocaleService extends ChangeNotifier {
  Locale _currentLocale = const Locale(AppKeys.langEnglish);
  bool _isAutoMode = true; // Varsayılan olarak otomatik mod
  SharedPreferences? _prefsCache;
  ui.PlatformDispatcher? _platformDispatcher;

  Locale get currentLocale => _currentLocale;
  
  /// Otomatik mod aktif mi?
  bool get isAutoMode => _isAutoMode;

  /// Mevcut locale'in RTL dil olup olmadığını kontrol eder.
  bool get isRTL => RTLHelper.isRTL(_currentLocale);

  /// Mevcut locale'e göre TextDirection döndürür.
  TextDirection get textDirection => RTLHelper.getTextDirection(_currentLocale);

  /// Cihaz dilini algılar ve desteklenen bir dile dönüştürür.
  Locale _detectDeviceLocale() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final deviceLangCode = deviceLocale.languageCode.toLowerCase();

    if (deviceLangCode == AppKeys.langTurkish) {
      return const Locale(AppKeys.langTurkish);
    }

    if (deviceLangCode == AppKeys.langArabic) {
      return const Locale(AppKeys.langArabic);
    }

    // Diğer tüm diller için İngilizce
    return const Locale(AppKeys.langEnglish);
  }

  /// Cihaz dilini dinler ve otomatik modda günceller.
  void _listenToDeviceLocale() {
    _platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    _platformDispatcher?.onLocaleChanged = () {
      if (_isAutoMode) {
        final newLocale = _detectDeviceLocale();
        if (_currentLocale != newLocale) {
          _currentLocale = newLocale;
          AppLogger.info('Cihaz dili değişti, otomatik güncellendi: ${newLocale.languageCode}', tag: 'LocaleService');
          notifyListeners();
        }
      }
    };
  }

  /// Kaydedilmiş dili yükler, yoksa otomatik modu aktif eder.
  Future<void> loadSavedLocale() async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      
      // Otomatik mod ayarını yükle
      final autoMode = _prefsCache!.getBool(AppKeys.localeAutoModeKey);
      _isAutoMode = autoMode ?? true; // Varsayılan olarak otomatik mod
      
      if (_isAutoMode) {
        // Otomatik mod: cihaz dilini algıla
        _currentLocale = _detectDeviceLocale();
        _listenToDeviceLocale(); // Cihaz dilini dinle
        AppLogger.info('Otomatik mod aktif, cihaz dili: ${_currentLocale.languageCode}', tag: 'LocaleService');
      } else {
        // Manuel mod: kayıtlı dili yükle
        final localeCode = _prefsCache!.getString(AppKeys.localeKey);
        if (localeCode != null && AppKeys.supportedLanguages.contains(localeCode)) {
          _currentLocale = Locale(localeCode);
          AppLogger.info('Kayıtlı dil yüklendi: $localeCode', tag: 'LocaleService');
        } else {
          // Kayıtlı dil yoksa cihaz dilini kullan
          _currentLocale = _detectDeviceLocale();
          await _prefsCache!.setString(AppKeys.localeKey, _currentLocale.languageCode);
          AppLogger.info('Cihaz dili algılandı: ${_currentLocale.languageCode}', tag: 'LocaleService');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Dil yükleme hatası', tag: 'LocaleService', error: e, stackTrace: stackTrace);
      _currentLocale = _detectDeviceLocale();
      _isAutoMode = true;
      notifyListeners();
    }
  }

  /// Otomatik modu aktif eder veya devre dışı bırakır.
  Future<void> setAutoMode(bool enabled) async {
    if (_isAutoMode == enabled) return;

    _isAutoMode = enabled;

    if (enabled) {
      // Otomatik moda geç: cihaz dilini algıla ve dinle
      _currentLocale = _detectDeviceLocale();
      _listenToDeviceLocale();
      AppLogger.info('Otomatik mod aktif edildi, cihaz dili: ${_currentLocale.languageCode}', tag: 'LocaleService');
    } else {
      // Manuel moda geç: cihaz dilini dinlemeyi durdur
      _platformDispatcher?.onLocaleChanged = null;
      // Mevcut dili kaydet
      try {
        _prefsCache ??= await SharedPreferences.getInstance();
        await _prefsCache!.setString(AppKeys.localeKey, _currentLocale.languageCode);
      } catch (e) {
        AppLogger.error('Dil kaydetme hatası', tag: 'LocaleService', error: e);
      }
      AppLogger.info('Manuel moda geçildi, dil: ${_currentLocale.languageCode}', tag: 'LocaleService');
    }

    notifyListeners();

    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setBool(AppKeys.localeAutoModeKey, enabled);
    } catch (e, stackTrace) {
      AppLogger.error('Otomatik mod kaydetme hatası', tag: 'LocaleService', error: e, stackTrace: stackTrace);
    }
  }

  /// Dili değiştirir ve kaydeder (manuel mod).
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    if (!AppKeys.supportedLanguages.contains(locale.languageCode)) {
      AppLogger.warning('Desteklenmeyen dil: ${locale.languageCode}', tag: 'LocaleService');
      return;
    }

    // Manuel moda geç (kullanıcı manuel seçim yaptı)
    if (_isAutoMode) {
      await setAutoMode(false);
    }

    _currentLocale = locale;
    notifyListeners();

    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setString(AppKeys.localeKey, locale.languageCode);
      AppLogger.success('Dil değiştirildi: ${locale.languageCode}', tag: 'LocaleService');
    } catch (e, stackTrace) {
      AppLogger.error('Dil kaydetme hatası', tag: 'LocaleService', error: e, stackTrace: stackTrace);
    }
  }

  /// Desteklenen diller.
  static const List<Locale> supportedLocales = [
    Locale(AppKeys.langTurkish),
    Locale(AppKeys.langEnglish),
    Locale(AppKeys.langArabic),
  ];

  /// Dil adlarını döndürür.
  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case AppKeys.langTurkish:
        return 'Türkçe';
      case AppKeys.langEnglish:
        return 'English';
      case AppKeys.langArabic:
        return 'العربية';
      default:
        return locale.languageCode;
    }
  }

  /// Dil bayrağını döndürür (emoji).
  static String getLanguageFlag(Locale locale) {
    switch (locale.languageCode) {
      case AppKeys.langTurkish:
        return '🇹🇷';
      case AppKeys.langEnglish:
        return '🇺🇸';
      case AppKeys.langArabic:
        return '🇸🇦';
      default:
        return '🌐';
    }
  }
}
