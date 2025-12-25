import 'package:flutter/material.dart';
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
      return _getDefaultMessage(errorCode);
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

  /// Varsayılan hata mesajları (localization yüklenemezse)
  static String _getDefaultMessage(ErrorCode errorCode) {
    switch (errorCode) {
      case ErrorCode.gpsLocationNotAvailable:
        return 'GPS konumu alınamadı';
      case ErrorCode.qiblaDirectionCalculationFailed:
        return 'Kıble yönü hesaplanamadı';
      case ErrorCode.locationRefreshFailed:
        return 'Konum yenilenemedi';
    }
  }

  /// İnternet bağlantısı hatası (context ile)
  static String noInternetConnection(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.noInternetConnection ?? 'İnternet bağlantısı yok.';
    }
    return 'İnternet bağlantısı yok.';
  }

  /// Veri bulunamadı hatası (context ile)
  static String dataNotFound(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.dataNotFound ?? 'Veri bulunamadı.';
    }
    return 'Veri bulunamadı.';
  }

  /// Sunucu hatası (context ile)
  static String serverError(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.serverError ?? 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';
    }
    return 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';
  }

  /// Bilinmeyen hata (context ile)
  static String unknownError(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.unknownError ?? 'Bilinmeyen hata oluştu.';
    }
    return 'Bilinmeyen hata oluştu.';
  }

  /// GPS konumu alınamadı hatası (context ile)
  static String gpsLocationNotAvailable(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.gpsLocationNotAvailable ?? 'GPS konumu alınamadı';
    }
    return 'GPS konumu alınamadı';
  }

  /// Şehir bulunamadı hatası (context ile)
  static String cityNotFoundForLocation(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.cityNotFoundForLocation ?? 'Konumunuz için şehir bulunamadı';
    }
    return 'Konumunuz için şehir bulunamadı';
  }

  /// İçerik bulunamadı hatası
  static String contentNotFound(BuildContext context) {
    return AppLocalizations.of(context)?.contentNotFound ?? 'İçerik bulunamadı';
  }

  /// Tekrar deneme butonu metni (küçük harf)
  static String retryLowercase(BuildContext context) {
    return AppLocalizations.of(context)?.retryLowercase ?? 'tekrar dene';
  }

  /// Namaz vakitleri yükleme hatası
  static String prayerTimesLoadError(String date, String error) {
    return '$date tarihinin namaz vakitleri yüklenirken hata oluştu: $error';
  }

  /// Local dosya temizleme hatası
  static String localFilesClearError(String error) {
    return 'Local dosyalar temizlenirken hata oluştu: $error';
  }

  /// Ülke listesi yükleme hatası
  static String countryListLoadError(String error) {
    return 'Ülke listesi yüklenirken hata oluştu: $error';
  }

  /// Eyalet listesi yükleme hatası
  static String stateListLoadError(String error) {
    return 'Eyalet listesi yüklenirken hata oluştu: $error';
  }

  /// Şehir listesi yükleme hatası
  static String cityListLoadError(String error) {
    return 'Şehir listesi yüklenirken hata oluştu: $error';
  }

  /// Konum kaydetme hatası
  static String locationSaveError(String error) {
    return 'Konum kaydedilirken hata oluştu: $error';
  }

  /// Kaydedilen konum yükleme hatası
  static String savedLocationLoadError(String error) {
    return 'Kaydedilen konum yüklenirken hata oluştu: $error';
  }

  /// Konum başlatma hatası
  static String locationInitError(String error) {
    return 'Konum başlatılırken hata oluştu: $error';
  }

  /// Ülke arama hatası
  static String countrySearchError(String error) {
    return 'Ülke arama yapılırken hata oluştu: $error';
  }

  /// Eyalet arama hatası
  static String stateSearchError(String error) {
    return 'Eyalet arama yapılırken hata oluştu: $error';
  }

  /// Şehir arama hatası
  static String citySearchError(String error) {
    return 'Şehir arama yapılırken hata oluştu: $error';
  }

  /// Konum seçme hatası
  static String locationSelectError(String error) {
    return 'Konum seçilirken hata oluştu: $error';
  }

  /// Varsayılan konum yükleme hatası
  static String defaultLocationLoadError(String error) {
    return 'Varsayılan konum yüklenirken hata oluştu: $error';
  }

  /// GPS konumu alma hatası
  static String gpsLocationFetchError(String error) {
    return 'GPS konumu alınırken hata oluştu: $error';
  }

  /// Pusula kalibrasyon gerekliliği (context ile)
  static String compassCalibrationRequired(BuildContext? context) {
    if (context != null) {
      return AppLocalizations.of(context)?.compassCalibrationRequired ?? 'Pusula kalibrasyonu gerekli';
    }
    return 'Pusula kalibrasyonu gerekli';
  }
}

