import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/rtl_helper.dart';
import '../utils/app_keys.dart';
import '../utils/app_logger.dart';

/// Dil yönetimi servisi.
///
/// Bu servis şunları yönetir:
/// - Uygulama dilini yükleme ve kaydetme
/// - RTL/LTR metin yönü belirleme
/// - Desteklenen dilleri listeleme
class LocaleService extends ChangeNotifier {
  Locale _currentLocale = const Locale(AppKeys.langTurkish);
  SharedPreferences? _prefsCache;

  Locale get currentLocale => _currentLocale;

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

  /// Kaydedilmiş dili yükler, yoksa cihaz dilini algılar ve kaydeder.
  Future<void> loadSavedLocale() async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      final localeCode = _prefsCache!.getString(AppKeys.localeKey);

      if (localeCode != null && AppKeys.supportedLanguages.contains(localeCode)) {
        _currentLocale = Locale(localeCode);
        AppLogger.info('Kayıtlı dil yüklendi: $localeCode', tag: 'LocaleService');
      } else {
        // İlk kurulum: cihaz dilini algıla ve kaydet
        _currentLocale = _detectDeviceLocale();
        await _prefsCache!.setString(AppKeys.localeKey, _currentLocale.languageCode);
        AppLogger.info('Cihaz dili algılandı: ${_currentLocale.languageCode}', tag: 'LocaleService');
      }

      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Dil yükleme hatası', tag: 'LocaleService', error: e, stackTrace: stackTrace);
      _currentLocale = _detectDeviceLocale();
      notifyListeners();
    }
  }

  /// Dili değiştirir ve kaydeder.
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    if (!AppKeys.supportedLanguages.contains(locale.languageCode)) {
      AppLogger.warning('Desteklenmeyen dil: ${locale.languageCode}', tag: 'LocaleService');
      return;
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
