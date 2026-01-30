import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../l10n/app_localizations.dart';

/// Hata kodları
enum ErrorCode {
  gpsLocationNotAvailable,
  qiblaDirectionCalculationFailed,
  locationRefreshFailed,
}

/// Hata mesajları için yardımcı sınıf
class ErrorMessages {
  /// ErrorCode'dan lokalize hata mesajı döndürür
  static String fromErrorCode(BuildContext context, ErrorCode errorCode) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      final locale = Localizations.localeOf(context);
      return _getDefaultMessage(errorCode, locale);
    }
    
    switch (errorCode) {
      case ErrorCode.gpsLocationNotAvailable:
        return localizations.gpsLocationNotAvailable;
      case ErrorCode.qiblaDirectionCalculationFailed:
        return localizations.qiblaDirectionCalculationFailed;
      case ErrorCode.locationRefreshFailed:
        return localizations.locationRefreshFailed;
    }
  }
  
  /// Context'ten locale'i alır veya sistem locale'ini döndürür
  static Locale _getLocale(BuildContext? context) {
    if (context != null) {
      try {
        return Localizations.localeOf(context);
      } catch (_) {
        // Context'ten locale alınamazsa sistem locale'ini kullan
      }
    }
    return ui.PlatformDispatcher.instance.locale;
  }
  
  /// Locale'e göre fallback mesaj döndürür
  static String _getFallbackMessage(String key, Locale locale) {
    final langCode = locale.languageCode;
    
    // Tüm hata mesajları için fallback değerler
    final fallbackMessages = {
      'tr': {
        'noInternetConnection': 'İnternet bağlantısı yok.',
        'dataNotFound': 'Veri bulunamadı.',
        'serverError': 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.',
        'unknownError': 'Bilinmeyen hata oluştu.',
        'gpsLocationNotAvailable': 'GPS konumu alınamadı',
        'cityNotFoundForLocation': 'Konumunuz için şehir bulunamadı',
        'contentNotFound': 'İçerik bulunamadı',
        'retryLowercase': 'tekrar dene',
        'countryListLoadError': 'Ülke listesi yüklenirken hata oluştu.',
        'stateListLoadError': 'Eyalet listesi yüklenirken hata oluştu.',
        'cityListLoadError': 'Şehir listesi yüklenirken hata oluştu.',
        'locationSaveError': 'Konum kaydedilirken hata oluştu.',
        'savedLocationLoadError': 'Kaydedilen konum yüklenirken hata oluştu.',
        'locationInitError': 'Konum başlatılırken hata oluştu.',
        'countrySearchError': 'Ülke arama yapılırken hata oluştu.',
        'stateSearchError': 'Eyalet arama yapılırken hata oluştu.',
        'citySearchError': 'Şehir arama yapılırken hata oluştu.',
        'locationSelectError': 'Konum seçilirken hata oluştu.',
        'defaultLocationLoadError': 'Varsayılan konum yüklenirken hata oluştu.',
        'gpsLocationFetchError': 'GPS konumu alınırken hata oluştu, lütfen ayarlarınızı kontrol ediniz.',
        'compassCalibrationRequired': 'Pusula kalibrasyonu gerekli',
      },
      'ar': {
        'noInternetConnection': 'لا يوجد اتصال بالإنترنت.',
        'dataNotFound': 'البيانات غير موجودة.',
        'serverError': 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.',
        'unknownError': 'حدث خطأ غير معروف.',
        'gpsLocationNotAvailable': 'موقع GPS غير متاح',
        'cityNotFoundForLocation': 'لم يتم العثور على المدينة لموقعك',
        'contentNotFound': 'المحتوى غير موجود',
        'retryLowercase': 'إعادة المحاولة',
        'countryListLoadError': 'حدث خطأ أثناء تحميل قائمة البلدان.',
        'stateListLoadError': 'حدث خطأ أثناء تحميل قائمة الولايات.',
        'cityListLoadError': 'حدث خطأ أثناء تحميل قائمة المدن.',
        'locationSaveError': 'حدث خطأ أثناء حفظ الموقع.',
        'savedLocationLoadError': 'حدث خطأ أثناء تحميل الموقع المحفوظ.',
        'locationInitError': 'حدث خطأ أثناء تهيئة الموقع.',
        'countrySearchError': 'حدث خطأ أثناء البحث عن البلدان.',
        'stateSearchError': 'حدث خطأ أثناء البحث عن الولايات.',
        'citySearchError': 'حدث خطأ أثناء البحث عن المدن.',
        'locationSelectError': 'حدث خطأ أثناء اختيار الموقع.',
        'defaultLocationLoadError': 'حدث خطأ أثناء تحميل الموقع الافتراضي.',
        'gpsLocationFetchError': 'حدث خطأ أثناء جلب موقع GPS، يرجى التحقق من إعداداتك.',
        'compassCalibrationRequired': 'معايرة البوصلة مطلوبة',
      },
      'en': {
        'noInternetConnection': 'No internet connection.',
        'dataNotFound': 'Data not found.',
        'serverError': 'Server error occurred. Please try again later.',
        'unknownError': 'Unknown error occurred.',
        'gpsLocationNotAvailable': 'GPS location not available',
        'cityNotFoundForLocation': 'City not found for your location',
        'contentNotFound': 'Content not found',
        'retryLowercase': 'retry',
        'countryListLoadError': 'Error loading country list.',
        'stateListLoadError': 'Error loading state list.',
        'cityListLoadError': 'Error loading city list.',
        'locationSaveError': 'Error saving location.',
        'savedLocationLoadError': 'Error loading saved location.',
        'locationInitError': 'Error initializing location.',
        'countrySearchError': 'Error searching countries.',
        'stateSearchError': 'Error searching states.',
        'citySearchError': 'Error searching cities.',
        'locationSelectError': 'Error selecting location.',
        'defaultLocationLoadError': 'Error loading default location.',
        'gpsLocationFetchError': 'Error fetching GPS location, please check your settings.',
        'compassCalibrationRequired': 'Compass calibration required',
      },
    };
    
    final messages = fallbackMessages[langCode] ?? fallbackMessages['en']!;
    return messages[key] ?? messages['unknownError']!;
  }

  /// Varsayılan hata mesajları (localization yüklenemezse)
  static String _getDefaultMessage(ErrorCode errorCode, [Locale? locale]) {
    final langCode = locale?.languageCode ?? ui.PlatformDispatcher.instance.locale.languageCode;
    
    switch (errorCode) {
      case ErrorCode.gpsLocationNotAvailable:
        switch (langCode) {
          case 'tr':
            return 'GPS konumu alınamadı';
          case 'ar':
            return 'موقع GPS غير متاح';
          default:
            return 'GPS location not available';
        }
      case ErrorCode.qiblaDirectionCalculationFailed:
        switch (langCode) {
          case 'tr':
            return 'Kıble yönü hesaplanamadı';
          case 'ar':
            return 'فشل حساب اتجاه القبلة';
          default:
            return 'Qibla direction calculation failed';
        }
      case ErrorCode.locationRefreshFailed:
        switch (langCode) {
          case 'tr':
            return 'Konum yenilenemedi';
          case 'ar':
            return 'فشل تحديث الموقع';
          default:
            return 'Location refresh failed';
        }
    }
  }

  /// İnternet bağlantısı hatası (context ile)
  static String noInternetConnection(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.noInternetConnection;
      }
      return _getFallbackMessage('noInternetConnection', _getLocale(context));
    }
    return _getFallbackMessage('noInternetConnection', _getLocale(null));
  }

  /// Veri bulunamadı hatası (context ile)
  static String dataNotFound(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.dataNotFound;
      }
      return _getFallbackMessage('dataNotFound', _getLocale(context));
    }
    return _getFallbackMessage('dataNotFound', _getLocale(null));
  }

  /// Sunucu hatası (context ile)
  static String serverError(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.serverError;
      }
      return _getFallbackMessage('serverError', _getLocale(context));
    }
    return _getFallbackMessage('serverError', _getLocale(null));
  }

  /// Bilinmeyen hata (context ile)
  static String unknownError(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.unknownError;
      }
      return _getFallbackMessage('unknownError', _getLocale(context));
    }
    return _getFallbackMessage('unknownError', _getLocale(null));
  }

  /// GPS konumu alınamadı hatası (context ile)
  static String gpsLocationNotAvailable(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.gpsLocationNotAvailable;
      }
      return _getFallbackMessage('gpsLocationNotAvailable', _getLocale(context));
    }
    return _getFallbackMessage('gpsLocationNotAvailable', _getLocale(null));
  }

  /// Şehir bulunamadı hatası (context ile)
  static String cityNotFoundForLocation(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.cityNotFoundForLocation;
      }
      return _getFallbackMessage('cityNotFoundForLocation', _getLocale(context));
    }
    return _getFallbackMessage('cityNotFoundForLocation', _getLocale(null));
  }

  /// İçerik bulunamadı hatası
  static String contentNotFound(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations.contentNotFound;
    }
    return _getFallbackMessage('contentNotFound', _getLocale(context));
  }

  /// Tekrar deneme butonu metni (küçük harf)
  static String retryLowercase(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations.retryLowercase;
    }
    return _getFallbackMessage('retryLowercase', _getLocale(context));
  }

  /// Namaz vakitleri yükleme hatası
  static String prayerTimesLoadError(BuildContext? context, String date, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.prayerTimesLoadError(date, error);
      }
      // Fallback: locale'e göre mesaj
      final locale = _getLocale(context);
      final langCode = locale.languageCode;
      switch (langCode) {
        case 'tr':
          return '$date tarihinin namaz vakitleri yüklenirken hata oluştu: $error';
        case 'ar':
          return 'حدث خطأ أثناء تحميل أوقات الصلاة لـ $date: $error';
        default:
          return 'Error loading prayer times for $date: $error';
      }
    }
    final locale = _getLocale(null);
    final langCode = locale.languageCode;
    switch (langCode) {
      case 'tr':
        return '$date tarihinin namaz vakitleri yüklenirken hata oluştu: $error';
      case 'ar':
        return 'حدث خطأ أثناء تحميل أوقات الصلاة لـ $date: $error';
      default:
        return 'Error loading prayer times for $date: $error';
    }
  }

  /// Local dosya temizleme hatası
  static String localFilesClearError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.localFilesClearError(error);
      }
      // Fallback: locale'e göre mesaj
      final locale = _getLocale(context);
      final langCode = locale.languageCode;
      switch (langCode) {
        case 'tr':
          return 'Local dosyalar temizlenirken hata oluştu: $error';
        case 'ar':
          return 'حدث خطأ أثناء مسح الملفات المحلية: $error';
        default:
          return 'Error clearing local files: $error';
      }
    }
    final locale = _getLocale(null);
    final langCode = locale.languageCode;
    switch (langCode) {
      case 'tr':
        return 'Local dosyalar temizlenirken hata oluştu: $error';
      case 'ar':
        return 'حدث خطأ أثناء مسح الملفات المحلية: $error';
      default:
        return 'Error clearing local files: $error';
    }
  }

  /// Ülke listesi yükleme hatası
  static String countryListLoadError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        // Exception detaylarını gizle, sadece genel mesajı göster
        // error parametresi sadece log için, kullanıcıya gösterilmez
        return localizations.countryListLoadError('');
      }
    }
    return _getFallbackMessage('countryListLoadError', _getLocale(context));
  }

  /// Eyalet listesi yükleme hatası
  static String stateListLoadError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.stateListLoadError('');
      }
    }
    return _getFallbackMessage('stateListLoadError', _getLocale(context));
  }

  /// Şehir listesi yükleme hatası
  static String cityListLoadError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.cityListLoadError('');
      }
    }
    return _getFallbackMessage('cityListLoadError', _getLocale(context));
  }

  /// Konum kaydetme hatası
  static String locationSaveError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.locationSaveError('');
      }
    }
    return _getFallbackMessage('locationSaveError', _getLocale(context));
  }

  /// Kaydedilen konum yükleme hatası
  static String savedLocationLoadError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.savedLocationLoadError('');
      }
    }
    return _getFallbackMessage('savedLocationLoadError', _getLocale(context));
  }

  /// Konum başlatma hatası
  static String locationInitError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.locationInitError('');
      }
    }
    return _getFallbackMessage('locationInitError', _getLocale(context));
  }

  /// Ülke arama hatası
  static String countrySearchError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.countrySearchError('');
      }
    }
    return _getFallbackMessage('countrySearchError', _getLocale(context));
  }

  /// Eyalet arama hatası
  static String stateSearchError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.stateSearchError('');
      }
    }
    return _getFallbackMessage('stateSearchError', _getLocale(context));
  }

  /// Şehir arama hatası
  static String citySearchError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.citySearchError('');
      }
    }
    return _getFallbackMessage('citySearchError', _getLocale(context));
  }

  /// Konum seçme hatası
  static String locationSelectError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.locationSelectError('');
      }
    }
    return _getFallbackMessage('locationSelectError', _getLocale(context));
  }

  /// Varsayılan konum yükleme hatası
  static String defaultLocationLoadError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.defaultLocationLoadError('');
      }
    }
    return _getFallbackMessage('defaultLocationLoadError', _getLocale(context));
  }

  /// GPS konumu alma hatası
  static String gpsLocationFetchError(BuildContext? context, String error) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.gpsLocationFetchError('');
      }
    }
    return _getFallbackMessage('gpsLocationFetchError', _getLocale(context));
  }

  /// Pusula kalibrasyon gerekliliği (context ile)
  static String compassCalibrationRequired(BuildContext? context) {
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return localizations.compassCalibrationRequired;
      }
      return _getFallbackMessage('compassCalibrationRequired', _getLocale(context));
    }
    return _getFallbackMessage('compassCalibrationRequired', _getLocale(null));
  }
}

