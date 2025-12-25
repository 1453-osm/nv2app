import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Namaz vakitleri isimlerini çevirmek için yardımcı sınıf
class PrayerNameHelper {
  /// API'den gelen key'leri çevrilmiş isimlere dönüştürür
  static String getLocalizedPrayerName(BuildContext context, String prayerKey) {
    final localizations = AppLocalizations.of(context)!;
    switch (prayerKey) {
      case 'İmsak':
      case 'imsak':
      case 'fajr':
        return localizations.imsak;
      case 'Güneş':
      case 'gunes':
      case 'sunrise':
        return localizations.gunes;
      case 'Öğle':
      case 'ogle':
      case 'dhuhr':
        return localizations.ogle;
      case 'İkindi':
      case 'ikindi':
      case 'asr':
        return localizations.ikindi;
      case 'Akşam':
      case 'aksam':
      case 'maghrib':
        return localizations.aksam;
      case 'Yatsı':
      case 'yatsi':
      case 'isha':
        return localizations.yatsi;
      case 'Cuma':
      case 'cuma':
      case 'friday':
        return localizations.cuma;
      default:
        return prayerKey;
    }
  }

  /// Çevrilmiş isimden API key'ine dönüştürür (geriye dönük uyumluluk için)
  static String getPrayerKey(String localizedName) {
    // Bu fonksiyon çevrilmiş isimden key'e dönüştürür
    // Tüm dillerdeki çevirileri kontrol eder
    final lowerName = localizedName.toLowerCase();
    
    // Türkçe key'ler
    if (localizedName == 'İmsak' || lowerName == 'imsak' || lowerName == 'fajr') return 'İmsak';
    if (localizedName == 'Güneş' || lowerName == 'gunes' || lowerName == 'sunrise') return 'Güneş';
    if (localizedName == 'Öğle' || lowerName == 'ogle' || lowerName == 'dhuhr') return 'Öğle';
    if (localizedName == 'İkindi' || lowerName == 'ikindi' || lowerName == 'asr') return 'İkindi';
    if (localizedName == 'Akşam' || lowerName == 'aksam' || lowerName == 'maghrib') return 'Akşam';
    if (localizedName == 'Yatsı' || lowerName == 'yatsi' || lowerName == 'isha') return 'Yatsı';
    if (localizedName == 'Cuma' || lowerName == 'cuma' || lowerName == 'friday') return 'Cuma';
    
    // İngilizce çeviriler
    if (lowerName == 'fajr' || lowerName.contains('fajr')) return 'İmsak';
    if (lowerName == 'sunrise' || lowerName.contains('sunrise')) return 'Güneş';
    if (lowerName == 'dhuhr' || lowerName.contains('dhuhr') || lowerName == 'noon') return 'Öğle';
    if (lowerName == 'asr' || lowerName.contains('asr')) return 'İkindi';
    if (lowerName == 'maghrib' || lowerName.contains('maghrib')) return 'Akşam';
    if (lowerName == 'isha' || lowerName.contains('isha')) return 'Yatsı';
    if (lowerName == 'friday' || lowerName.contains('friday')) return 'Cuma';
    
    // Arapça çeviriler (genellikle API'den key olarak gelir, ama yine de kontrol edelim)
    // API'den gelen key'ler genellikle Türkçe veya İngilizce olduğu için burada kontrol yeterli
    
    return localizedName; // Fallback: eğer eşleşme yoksa orijinal değeri döndür
  }

  /// Namaz vakitleri sıralı listesini çevrilmiş isimlerle döndürür
  static List<String> getOrderedPrayerNames(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return [
      localizations.imsak,
      localizations.gunes,
      localizations.ogle,
      localizations.ikindi,
      localizations.aksam,
      localizations.yatsi,
    ];
  }

  /// Namaz vakitleri key'lerini sıralı liste olarak döndürür
  static const List<String> prayerKeys = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
}
