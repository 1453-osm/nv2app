import '../models/prayer_times_model.dart';
import '../models/religious_day.dart';

/// Hicrî tarih (gün-ay) bazlı kural seti ile dini günleri tespit eder.
class ReligiousDaysService {
  static const Map<String, String> _monthCanonical = {
    // Muharrem
    'muharrem': 'Muharrem', 'muharremay': 'Muharrem', 'muharrem ayi': 'Muharrem',
    // Safer
    'safer': 'Safer',
    // Rebiülevvel
    'rebiülevvel': 'Rebiülevvel', 'rebiulevvel': 'Rebiülevvel', 'rabiulevvel': 'Rebiülevvel',
    // Rebiülahir
    'rebiülahir': 'Rebiülahir', 'rebiulahir': 'Rebiülahir', 'rabiulahir': 'Rebiülahir',
    // Cemaziyelevvel
    'cemaziyelevvel': 'Cemaziyelevvel', 'cemaziyulevvel': 'Cemaziyelevvel',
    // Cemaziyelahir
    'cemaziyelahir': 'Cemaziyelahir', 'cemaziyu-lahir': 'Cemaziyelahir',
    // Recep
    'recep': 'Recep', 'receb': 'Recep',
    // Şaban
    'şaban': 'Şaban', 'saban': 'Şaban',
    // Ramazan
    'ramazan': 'Ramazan', 'ramadhan': 'Ramazan',
    // Şevval
    'şevval': 'Şevval', 'sevval': 'Şevval',
    // Zilkade
    'zilkade': 'Zilkade', 'zil-kaade': 'Zilkade', 'zilkaade': 'Zilkade',
    // Zilhicce
    'zilhicce': 'Zilhicce', 'zil-hicce': 'Zilhicce', 'zilhijce': 'Zilhicce', 'zilhijja': 'Zilhicce',
  };

  /// Tüm yılın verisinden dini günleri tespit eder.
  List<DetectedReligiousDay> detectFrom(PrayerTimesResponse response) {
    final List<DetectedReligiousDay> result = [];
    for (final pt in response.prayerTimes) {
      final hijri = pt.hijriDateLong;
      if (hijri.isEmpty) continue;

      final parsed = _parseHijriLong(hijri);
      if (parsed == null) continue;
      final int day = parsed.$1;
      final String month = parsed.$2; // canonical name

      final String gregShort = pt.gregorianDateShort;
      DateTime? gDate;
      if (pt.gregorianDateShortIso8601.isNotEmpty) {
        gDate = DateTime.tryParse(pt.gregorianDateShortIso8601);
      }
      gDate ??= _parseDdMmYyyy(gregShort);
      if (gDate == null) continue;

      final events = _eventsFor(month, day);
      for (final e in events) {
        result.add(DetectedReligiousDay(
          gregorianDate: gDate,
          gregorianDateShort: gregShort,
          hijriDateLong: hijri,
          eventName: e,
          year: gDate.year,
        ));
      }
    }
    // Aynı gün birden çok etiket oluşursa benzersizleştir (eventName'e göre değil, tarih+isim bazlı)
    final seen = <String>{};
    return result.where((e) => seen.add('${e.gregorianDateShort}:${e.eventName}')).toList();
  }

  /// Bilinen sabit gün/ay kuralları
  List<String> _eventsFor(String month, int day) {
    final List<String> events = [];

    switch (month) {
      case 'Muharrem':
        if (day == 1) events.add('Hicrî Yılbaşı');
        if (day == 10) events.add('Aşura Günü');
        break;
      case 'Rebiülevvel':
        if (day == 12) events.add('Mevlid Kandili');
        break;
      case 'Recep':
        if (day == 27) events.add('Miraç Kandili');
        // Regaip Kandili: Recep ayının ilk Cuma gecesi — haftaya bağlı olduğu için burada kesin tespit edilmiyor.
        break;
      case 'Şaban':
        if (day == 15) events.add('Berat Kandili');
        break;
      case 'Ramazan':
        if (day == 1) events.add('Ramazan Ayı Başlangıcı');
        // Yaygın kabule göre 27. gece Kadir Gecesi
        if (day == 27) events.add('Kadir Gecesi');
        break;
      case 'Şevval':
        if (day >= 1 && day <= 3) {
          events.add('Ramazan Bayramı - ${day}. Gün');
        }
        break;
      case 'Zilhicce':
        if (day == 9) events.add('Arefe Günü');
        if (day >= 10 && day <= 13) {
          events.add('Kurban Bayramı - ${day - 9}. Gün');
        }
        break;
    }

    return events;
  }

  /// "12 Ramazan 1446" benzeri metinden gün, ay ve (varsa) hicri yılı çıkarır
  /// Dönen kayıt: (gün, canonicalAyAdı, hicriYılOrNull)
  (int, String, int?)? _parseHijriLong(String value) {
    final lower = value.toLowerCase();
    final normalized = _normalize(lower);
    final dayMatch = RegExp(r'(\d{1,2})').firstMatch(normalized);
    if (dayMatch == null) return null;
    final int? day = int.tryParse(dayMatch.group(1)!);
    if (day == null) return null;

    // Ay adını tespit et
    String? canonical;
    for (final key in _monthCanonical.keys) {
      final keyNorm = _normalize(key.toLowerCase());
      if (normalized.contains(keyNorm)) {
        canonical = _monthCanonical[key];
        break;
      }
    }
    if (canonical == null) return null;

    // Hicri yıl varsa yakala (genelde 3-4 basamaklı)
    final digitMatches = RegExp(r'\d{3,4}').allMatches(normalized).toList();
    int? hijriYear;
    if (digitMatches.isNotEmpty) {
      // Eğer sadece bir adet 3-4 haneli sayı varsa muhtemelen yıl odur; eğer birkaç varsa sonuncuyu al
      final last = digitMatches.last.group(0);
      hijriYear = int.tryParse(last ?? '');
    }

    return (day, canonical, hijriYear);
  }

  /// Hicri tarih bilgisine dayanarak hedef Gregoryen yılı üretmeye çalışır.
  /// Bu fonksiyon server'da üretilmiş tam takvimler yerine yaklaşık aritmetik
  /// İslami takvim dönüşümü uygular; doğruluk çoğu sabit gün için yeterlidir.
  List<DetectedReligiousDay> detectForGregorianYear(PrayerTimesResponse baseResponse, int targetGregorianYear) {
    final List<DetectedReligiousDay> result = [];

    for (final pt in baseResponse.prayerTimes) {
      final hijri = pt.hijriDateLong;
      if (hijri.isEmpty) continue;
      final parsed = _parseHijriLong(hijri);
      if (parsed == null) continue;
      final int day = parsed.$1;
      final String monthName = parsed.$2;
      final int? hijriYear = parsed.$3;

      final int? monthIndex = _monthNameToIndex[monthName];
      if (monthIndex == null) continue;

      // Eğer hicri yıl varsa dene, yoksa baseResponse içindeki gregorian tarihten yola çıkar
      if (hijriYear != null) {
        for (final hyOffset in [-1, 0, 1]) {
          final candidateHy = hijriYear + hyOffset;
          final DateTime? gDate = _hijriToGregorian(candidateHy, monthIndex, day);
          if (gDate == null) continue;
          if (gDate.year == targetGregorianYear) {
            final events = _eventsFor(monthName, day);
            for (final e in events) {
              result.add(DetectedReligiousDay(
                gregorianDate: gDate,
                gregorianDateShort: '${gDate.day.toString().padLeft(2, '0')}.${gDate.month.toString().padLeft(2, '0')}.${gDate.year}',
                hijriDateLong: hijri,
                eventName: e,
                year: gDate.year,
              ));
            }
            break;
          }
        }
      } else {
        // Hicri yıl yoksa, fallback: baseResponse içindeki gregorian tarihi oku ve yıl eşitse al
        DateTime? gDate;
        if (pt.gregorianDateShortIso8601.isNotEmpty) {
          gDate = DateTime.tryParse(pt.gregorianDateShortIso8601);
        }
        gDate ??= _parseDdMmYyyy(pt.gregorianDateShort);
        if (gDate != null && gDate.year == targetGregorianYear) {
          final events = _eventsFor(monthName, day);
          for (final e in events) {
            result.add(DetectedReligiousDay(
              gregorianDate: gDate,
              gregorianDateShort: pt.gregorianDateShort,
              hijriDateLong: hijri,
              eventName: e,
              year: gDate.year,
            ));
          }
        }
      }
    }

    final seen = <String>{};
    return result.where((e) => seen.add('${e.gregorianDateShort}:${e.eventName}')).toList();
  }

  static const Map<String, int> _monthNameToIndex = {
    'Muharrem': 1,
    'Safer': 2,
    'Rebiülevvel': 3,
    'Rebiülahir': 4,
    'Cemaziyelevvel': 5,
    'Cemaziyelahir': 6,
    'Recep': 7,
    'Şaban': 8,
    'Ramazan': 9,
    'Şevval': 10,
    'Zilkade': 11,
    'Zilhicce': 12,
  };

  /// Yaklaşık aritmetik İslami -> Gregoryen dönüşümü uygulayan yardımcı.
  DateTime? _hijriToGregorian(int hYear, int hMonth, int hDay) {
    // Aritmetik İslami takvim üzerinden Julian Day Number (JDN) tahmini
    final int iy = hYear;
    final int im = hMonth;
    final int id = hDay;

    // Hesaplama: yaklaşık gün sayısı
    final int n = ((11 * iy) + 3) ~/ 30;
    final int monthDays = ((29.5 * (im - 1))).ceil();
    final int jd = id + monthDays + (iy - 1) * 354 + n + 1948439 - 1;

    // JDN -> Gregorian (Fliegel-Van Flandern algoritması)
    final int j = jd + 32044;
    final int g = j ~/ 146097;
    final int dg = j % 146097;
    final int c = ((dg ~/ 36524 + 1) * 3) ~/ 4;
    final int dc = dg - c * 36524;
    final int b = dc ~/ 1461;
    final int db = dc % 1461;
    final int a = ((db ~/ 365 + 1) * 3) ~/ 4;
    final int da = db - a * 365;
    final int y = g * 400 + c * 100 + b * 4 + a;
    final int m = ((5 * da + 308) ~/ 153) - 2;
    final int d = da - ((m + 4) * 153 ~/ 5 - 122) + 1;
    final int year = y - 4800 + ((m + 2) ~/ 12);
    final int month = ((m + 2) % 12) + 1;
    final int day = d;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _normalize(String input) {
    const repl = {
      'â': 'a', 'ä': 'a', 'à': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'ê': 'e', 'ë': 'e', 'è': 'e', 'é': 'e', 'ė': 'e', 'ē': 'e',
      'î': 'i', 'ï': 'i', 'ì': 'i', 'í': 'i', 'ī': 'i', 'ı': 'i',
      'ô': 'o', 'ö': 'o', 'ò': 'o', 'ó': 'o', 'õ': 'o', 'ō': 'o',
      'û': 'u', 'ü': 'u', 'ù': 'u', 'ú': 'u', 'ū': 'u',
      'ç': 'c', 'ş': 's', 'ğ': 'g',
    };
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      sb.write(repl[ch] ?? ch);
    }
    return sb.toString();
  }

  DateTime? _parseDdMmYyyy(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// Belirli bir yıl için dini günleri getirir
  /// Bu metod PrayerTimesResponse'u parametre olarak alır ve detectFrom çağırır
  /// languageCode parametresi şu an için kullanılmıyor, gelecekte çeviriler için kullanılabilir
  Future<List<DetectedReligiousDay>> fetchReligiousDays(
    int year, {
    String? languageCode,
    PrayerTimesResponse? response,
  }) async {
    // Eğer response verilmişse detectFrom kullan, yoksa boş liste döndür
    if (response != null) {
      return detectFrom(response);
    }
    // Response yoksa boş liste döndür (cache'den okunacak)
    return [];
  }
}


