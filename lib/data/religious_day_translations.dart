const Map<String, Map<String, String>> religiousDayTranslations = {
  'regaib_kandili': {
    'tr': 'Regaip Kandili',
    'en': 'Raghaib Night',
    'ar': 'ليلة الرغائب',
  },
  'uc_aylarin_baslangici': {
    'tr': 'Üç Ayların Başlangıcı',
    'en': 'Beginning of the Three Holy Months',
    'ar': 'بداية الأشهر الثلاثة',
  },
  'mirac_kandili': {
    'tr': 'Miraç Kandili',
    'en': "Isra and Mi'raj Night",
    'ar': 'ليلة المعراج',
  },
  'berat_kandili': {
    'tr': 'Berat Kandili',
    'en': 'Barāʾah Night',
    'ar': 'ليلة البراءة',
  },
  'ramazan_baslangici': {
    'tr': 'Ramazan Başlangıcı',
    'en': 'Start of Ramadan',
    'ar': 'بداية رمضان',
  },
  'kadir_gecesi': {
    'tr': 'Kadir Gecesi',
    'en': 'Laylat al-Qadr',
    'ar': 'ليلة القدر',
  },
  'arefe_ramazan': {
    'tr': 'Ramazan Bayramı Arefesi',
    'en': 'Eve of Eid al-Fitr',
    'ar': 'ليلة عيد الفطر',
  },
  'arefe_kurban': {
    'tr': 'Kurban Bayramı Arefesi',
    'en': 'Day of Arafah',
    'ar': 'يوم عرفة',
  },
  'ramazan_bayrami_1_gun': {
    'tr': 'Ramazan Bayramı 1. Gün',
    'en': 'Eid al-Fitr · Day 1',
    'ar': 'عيد الفطر · اليوم الأول',
  },
  'ramazan_bayrami_2_gun': {
    'tr': 'Ramazan Bayramı 2. Gün',
    'en': 'Eid al-Fitr · Day 2',
    'ar': 'عيد الفطر · اليوم الثاني',
  },
  'ramazan_bayrami_3_gun': {
    'tr': 'Ramazan Bayramı 3. Gün',
    'en': 'Eid al-Fitr · Day 3',
    'ar': 'عيد الفطر · اليوم الثالث',
  },
  'kurban_bayrami_1_gun': {
    'tr': 'Kurban Bayramı 1. Gün',
    'en': 'Eid al-Adha · Day 1',
    'ar': 'عيد الأضحى · اليوم الأول',
  },
  'kurban_bayrami_2_gun': {
    'tr': 'Kurban Bayramı 2. Gün',
    'en': 'Eid al-Adha · Day 2',
    'ar': 'عيد الأضحى · اليوم الثاني',
  },
  'kurban_bayrami_3_gun': {
    'tr': 'Kurban Bayramı 3. Gün',
    'en': 'Eid al-Adha · Day 3',
    'ar': 'عيد الأضحى · اليوم الثالث',
  },
  'kurban_bayrami_4_gun': {
    'tr': 'Kurban Bayramı 4. Gün',
    'en': 'Eid al-Adha · Day 4',
    'ar': 'عيد الأضحى · اليوم الرابع',
  },
  'hicri_yilbasi': {
    'tr': 'Hicri Yılbaşı',
    'en': 'Islamic New Year',
    'ar': 'رأس السنة الهجرية',
  },
  'asure_gunu': {
    'tr': 'Aşure Günü',
    'en': 'Day of Ashura',
    'ar': 'عاشوراء',
  },
  'mevlid_kandili': {
    'tr': 'Mevlid Kandili',
    'en': 'Mawlid an-Nabi',
    'ar': 'المولد النبوي',
  },
};

Map<String, String> getLocalizedReligiousDayNames(String canonicalKey) {
  final data = religiousDayTranslations[canonicalKey];
  if (data == null) return const {};
  return Map<String, String>.unmodifiable(data);
}

String canonicalizeReligiousEventKey(
  String rawName, {
  String? arefeType,
}) {
  final sanitized = _stripNonAscii(rawName);
  var canonical = sanitized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  canonical = canonical.replaceAll(RegExp(r'_+'), '_');
  canonical = canonical.replaceAll(RegExp(r'^_+'), '');
  canonical = canonical.replaceAll(RegExp(r'_+$'), '');

  if (canonical == 'arefe' && (arefeType?.trim().isNotEmpty ?? false)) {
    final normalizedType = _stripNonAscii(arefeType!);
    var typeKey = normalizedType
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    typeKey =
        typeKey.replaceAll(RegExp(r'^_+'), '').replaceAll(RegExp(r'_+$'), '');
    if (typeKey.isNotEmpty) {
      canonical = '${canonical}_$typeKey';
    }
  }

  return canonical;
}

String _stripNonAscii(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticMap[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> _diacriticMap = {
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
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ó': 'o',
  'ò': 'o',
  'ú': 'u',
  'ù': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
  'Á': 'a',
  'À': 'a',
  'Â': 'a',
  'Ä': 'a',
  'Ç': 'c',
  'Ğ': 'g',
  'İ': 'i',
  'I': 'i',
  'Ö': 'o',
  'Ş': 's',
  'Ü': 'u',
  '\u0307': '',
};
