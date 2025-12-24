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

  /// "12 Ramazan 1446" benzeri metinden gün ve ayı çıkarır
  (int, String)? _parseHijriLong(String value) {
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
    return (day, canonical);
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
}


