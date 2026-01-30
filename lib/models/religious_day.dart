import '../data/religious_day_translations.dart';
import '../data/religious_days_mapping.dart';

class DetectedReligiousDay {
  final DateTime gregorianDate;
  final String gregorianDateShort; // e.g. 01.01.2025
  final String hijriDateLong; // e.g. 12 Rebiülevvel 1447
  final String eventName; // e.g. Mevlid Kandili
  final int year; // Gregoryen yılı (gruplama için)

  DetectedReligiousDay({
    required this.gregorianDate,
    required this.gregorianDateShort,
    required this.hijriDateLong,
    required this.eventName,
    required this.year,
  });

  /// JSON map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'gregorianDate': gregorianDate.toIso8601String(),
      'gregorianDateShort': gregorianDateShort,
      'hijriDateLong': hijriDateLong,
      'eventName': eventName,
      'year': year,
    };
  }

  /// JSON map'ten oluşturur
  factory DetectedReligiousDay.fromMap(Map<String, dynamic> map) {
    return DetectedReligiousDay(
      gregorianDate: DateTime.parse(map['gregorianDate'] as String),
      gregorianDateShort: map['gregorianDateShort'] as String,
      hijriDateLong: map['hijriDateLong'] as String,
      eventName: map['eventName'] as String,
      year: map['year'] as int,
    );
  }

  /// Locale tag'e göre lokalize edilmiş dini gün ismini döndürür
  String getLocalizedName(String localeTag) {
    // localeTag formatı: "tr", "en", "ar" veya "tr-TR", "en-US" gibi
    final languageCode = localeTag.split('-').first.toLowerCase();
    
    // Event name'i canonical key'e dönüştür
    final canonicalKey = canonicalizeReligiousEventKey(eventName);
    
    // Translation'ları al
    final translations = getLocalizedReligiousDayNames(canonicalKey);
    
    // Dil koduna göre çevrilmiş versiyonu al
    if (translations.containsKey(languageCode)) {
      return translations[languageCode]!;
    }
    
    // Fallback: eventName'i döndür
    return eventName;
  }

  /// Locale tag'e göre lokalize edilmiş Hicri tarihi döndürür
  /// Örnek: "12 Rebiülevvel 1447" -> "12 Rabi' al-awwal 1447" (en) veya "12 ربيع الأول 1447" (ar)
  String getLocalizedHijriDate(String localeTag) {
    // localeTag formatı: "tr", "en", "ar" veya "tr-TR", "en-US" gibi
    final languageCode = localeTag.split('-').first.toLowerCase();
    
    // Hicri tarihi parse et: "12 Rebiülevvel 1447" formatından
    final parts = hijriDateLong.split(' ');
    if (parts.length < 3) {
      // Format beklenen gibi değilse, orijinali döndür
      return hijriDateLong;
    }
    
    final day = parts[0];
    final monthName = parts[1];
    final year = parts[2];
    
    // Ay ismini çevir
    final canonicalMonth = HijriMonthMapping.normalize(monthName);
    final translatedMonth = HijriMonthMapping.translate(canonicalMonth, languageCode);
    
    // Çevrilmiş Hicri tarihi oluştur
    return '$day $translatedMonth $year';
  }
}


