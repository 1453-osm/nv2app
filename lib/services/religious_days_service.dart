import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/religious_day.dart';
import '../models/religious_days_api_model.dart';
import '../data/religious_days_mapping.dart';
import '../data/religious_day_translations.dart';
import '../utils/app_logger.dart';

/// API'den dini günleri çeker ve DetectedReligiousDay formatına dönüştürür
class ReligiousDaysService {
  static const String _baseUrl = 'https://storage.googleapis.com/namazvaktimdepo';

  /// Belirli bir yıl için API'den dini günleri çeker
  Future<List<DetectedReligiousDay>> fetchReligiousDaysFromApi(int year) async {
    try {
      final url = '$_baseUrl/religious-days-$year.json';
      AppLogger.network('GET', url);

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Bağlantı zaman aşımına uğradı'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final apiResponse = ReligiousDaysApiResponse.fromJson(jsonData as Map<String, dynamic>);
        
        final List<DetectedReligiousDay> result = [];
        
        for (final event in apiResponse.events) {
          // Miladi tarihi parse et
          final miladiDay = int.tryParse(event.miladi.day);
          final miladiMonth = _parseTurkishMonth(event.miladi.month);
          final miladiYear = int.tryParse(event.miladi.year);
          
          if (miladiDay == null || miladiMonth == null || miladiYear == null) {
            AppLogger.warning('Tarih parse edilemedi: ${event.miladi.day}.${event.miladi.month}.${event.miladi.year}');
            continue;
          }

          final gregorianDate = DateTime(miladiYear, miladiMonth, miladiDay);
          final gregorianDateShort = '${miladiDay.toString().padLeft(2, '0')}.${miladiMonth.toString().padLeft(2, '0')}.$miladiYear';

          // Hicri tarihi formatla - mapping ile normalize et
          final canonicalHijriMonth = HijriMonthMapping.normalize(event.hijri.month);
          // Hicri tarih formatı: "01 Muharrem 1446" (başında sıfır olabilir)
          final hijriDayFormatted = event.hijri.day.startsWith('0') && event.hijri.day.length > 1
              ? event.hijri.day.substring(1) // Başındaki sıfırı kaldır
              : event.hijri.day;
          final hijriDateLong = '$hijriDayFormatted $canonicalHijriMonth ${event.hijri.year}';

          // Event ismini canonical key'e dönüştür
          final canonicalKey = ReligiousEventMapping.toCanonicalKey(event.event, event.arefeType);
          
          // Türkçe event ismini al (translation dosyasından veya API'den)
          String eventName;
          final translations = getLocalizedReligiousDayNames(canonicalKey);
          if (translations.isNotEmpty && translations.containsKey('tr')) {
            eventName = translations['tr']!;
          } else {
            // Fallback: API'den gelen displayName'i kullan, ama Türkçe karakterleri düzelt
            eventName = event.displayName;
          }

          result.add(DetectedReligiousDay(
            gregorianDate: gregorianDate,
            gregorianDateShort: gregorianDateShort,
            hijriDateLong: hijriDateLong,
            eventName: eventName,
            year: miladiYear,
          ));
        }

        AppLogger.success('Dini günler API\'den indirildi: year=$year, count=${result.length}');
        return result;
      } else if (response.statusCode == 404) {
        AppLogger.warning('Dini günler verisi bulunamadı: year=$year');
        return [];
      } else {
        throw Exception('Dini günler indirilemedi. HTTP ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Dini günler indirilirken hata oluştu: year=$year', tag: 'ReligiousDays', error: e);
      rethrow;
    }
  }

  /// Türkçe ay ismini sayıya çevirir
  int? _parseTurkishMonth(String monthName) {
    const months = {
      'OCAK': 1,
      'ŞUBAT': 2,
      'MART': 3,
      'NİSAN': 4,
      'MAYIS': 5,
      'HAZİRAN': 6,
      'TEMMUZ': 7,
      'AĞUSTOS': 8,
      'EYLÜL': 9,
      'EKİM': 10,
      'KASIM': 11,
      'ARALIK': 12,
    };
    return months[monthName.toUpperCase()];
  }

  /// Birden fazla yıl için dini günleri çeker ve birleştirir
  Future<List<DetectedReligiousDay>> fetchReligiousDaysForYears(List<int> years) async {
    final List<DetectedReligiousDay> allDays = [];
    
    for (final year in years) {
      try {
        final days = await fetchReligiousDaysFromApi(year);
        allDays.addAll(days);
      } catch (e) {
        // Bir yıl için hata olsa bile diğer yılları çekmeye devam et
        AppLogger.warning('Yıl için dini günler çekilemedi: year=$year, error=$e');
      }
    }
    
    // Tarihe göre sırala
    allDays.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    
    return allDays;
  }

  // Eski metodları geriye dönük uyumluluk için tutuyoruz (deprecated)
  @Deprecated('Use fetchReligiousDaysFromApi instead')
  Future<List<DetectedReligiousDay>> fetchReligiousDays(
    int year, {
    String? languageCode,
    dynamic response,
  }) async {
    return fetchReligiousDaysFromApi(year);
  }
}