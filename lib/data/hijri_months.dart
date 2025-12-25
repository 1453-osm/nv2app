/// Hicri ay isimleri için ortak veri yapıları
/// Dini gün ve gecelerin tarih formatlamasında kullanılır

/// Hicri ay isimlerini normalize eden map (farklı yazımları canonical forma çevirir)
const Map<String, String> hijriMonthCanonical = {
  'muharrem': 'muharram',
  'muharram': 'muharram',
  'safer': 'safar',
  'safar': 'safar',
  'rebiulevvel': 'rabiulawwal',
  'rebiyulevvel': 'rabiulawwal',
  'rabiulevvel': 'rabiulawwal',
  'rabiulawwal': 'rabiulawwal',
  'rebiulahir': 'rabiulthani',
  'rebiyulahir': 'rabiulthani',
  'rabiulahir': 'rabiulthani',
  'rabiulakhir': 'rabiulthani',
  'rabiulthani': 'rabiulthani',
  'cemaziyelevvel': 'jumadaulawwal',
  'cemaziyyelevvel': 'jumadaulawwal',
  'jumadaulawwal': 'jumadaulawwal',
  'cemaziyelakhir': 'jumadaulthani',
  'cemaziyelahir': 'jumadaulthani',
  'jumadaulthani': 'jumadaulthani',
  'recep': 'rajab',
  'receb': 'rajab',
  'rajab': 'rajab',
  'saban': 'shaban',
  'shaban': 'shaban',
  'ramazan': 'ramadan',
  'ramadan': 'ramadan',
  'sevval': 'shawwal',
  'sewwal': 'shawwal',
  'shawwal': 'shawwal',
  'zilkade': 'dhualqadah',
  'zilqade': 'dhualqadah',
  'dhualqadah': 'dhualqadah',
  'zilhicce': 'dhualhijjah',
  'zulhicce': 'dhualhijjah',
  'dhualhijjah': 'dhualhijjah',
};

/// Hicri ay isimlerinin çevirileri (dil koduna göre)
const Map<String, Map<String, String>> hijriMonthTranslations = {
  'muharram': {
    'tr': 'Muharrem',
    'en': 'Muharram',
    'ar': 'محرم',
  },
  'safar': {
    'tr': 'Safer',
    'en': 'Safar',
    'ar': 'صفر',
  },
  'rabiulawwal': {
    'tr': 'Rebiülevvel',
    'en': 'Rabi al-awwal',
    'ar': 'ربيع الأول',
  },
  'rabiulthani': {
    'tr': 'Rebiülahir',
    'en': 'Rabi al-akhir',
    'ar': 'ربيع الآخر',
  },
  'jumadaulawwal': {
    'tr': 'Cemaziyelevvel',
    'en': 'Jumada al-awwal',
    'ar': 'جمادى الأولى',
  },
  'jumadaulthani': {
    'tr': 'Cemaziyelahir',
    'en': 'Jumada al-akhirah',
    'ar': 'جمادى الآخرة',
  },
  'rajab': {
    'tr': 'Recep',
    'en': 'Rajab',
    'ar': 'رجب',
  },
  'shaban': {
    'tr': 'Şaban',
    'en': "Sha'ban",
    'ar': 'شعبان',
  },
  'ramadan': {
    'tr': 'Ramazan',
    'en': 'Ramadan',
    'ar': 'رمضان',
  },
  'shawwal': {
    'tr': 'Şevval',
    'en': 'Shawwal',
    'ar': 'شوال',
  },
  'dhualqadah': {
    'tr': 'Zilkade',
    'en': 'Dhu al-Qadah',
    'ar': 'ذو القعدة',
  },
  'dhualhijjah': {
    'tr': 'Zilhicce',
    'en': 'Dhu al-Hijjah',
    'ar': 'ذو الحجة',
  },
};

/// Hicri ay isimlerini normalize eder (diacritic karakterleri temizler)
String normalizeHijriMonthLabel(String input) {
  if (input.isEmpty) return input;
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(hijriDiacriticMap[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z]'), '');
}

/// Diacritic karakterleri temizleyen map
const Map<String, String> hijriDiacriticMap = {
  'â': 'a',
  'î': 'i',
  'û': 'u',
  'ô': 'o',
  'ê': 'e',
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  '\u2019': '', // Right single quotation mark
  '\'': '', // Single quote
};

/// Hicri ay ismini normalize edip Türkçe karşılığını döndürür
/// Eğer bulunamazsa orijinal değeri döndürür
String getHijriMonthName(String rawMonth, {String languageCode = 'tr'}) {
  final normalized = normalizeHijriMonthLabel(rawMonth);
  final canonical = hijriMonthCanonical[normalized];
  if (canonical == null) return rawMonth;
  
  final translations = hijriMonthTranslations[canonical];
  if (translations == null) return rawMonth;
  
  return translations[languageCode] ?? translations['tr'] ?? rawMonth;
}

