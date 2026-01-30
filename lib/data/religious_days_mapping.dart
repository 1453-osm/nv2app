/// Hicri ay isimlerini normalize eder (API'den gelen formattan canonical formata)
/// Büyük/küçük harf kullanımına dikkat eder, kısaltma kullanmaz
class HijriMonthMapping {
  // API'den gelen ay isimlerinden canonical isimlere mapping (case-insensitive lookup için uppercase key)
  // Canonical format: İlk harf büyük, geri kalan küçük (Title Case)
  static const Map<String, String> _apiToCanonical = {
    // Tam isimler (uppercase variations)
    'MUHARREM': 'Muharrem',
    'SAFER': 'Safer',
    // Rebiülevvel - tüm varyasyonlar
    'REBIÜLEVVEL': 'Rebiülevvel',
    'REBIULEVVEL': 'Rebiülevvel',
    // Kısaltma formatları - tam isme dönüştürülüyor
    'R.EVVEL': 'Rebiülevvel',
    'R.EVVEL.': 'Rebiülevvel',
    'R.VVEL.': 'Rebiülevvel',
    'R.VVEL': 'Rebiülevvel',
    // Rebiülahir - tüm varyasyonlar
    'REBIÜLAHİR': 'Rebiülahir',
    'REBIULAHIR': 'Rebiülahir',
    // Kısaltma formatları
    'R.AHİR': 'Rebiülahir',
    'R.AHİR.': 'Rebiülahir',
    'R.AHIR': 'Rebiülahir',
    'R.HİR.': 'Rebiülahir',
    'R.HIR.': 'Rebiülahir',
    'C.EVVEL': 'Cemaziyelevvel',
    'C.EVVEL.': 'Cemaziyelevvel',
    'C.VVEL.': 'Cemaziyelevvel',
    'C.VVEL': 'Cemaziyelevvel',
    'CEVVEL.': 'Cemaziyelevvel',
    'CEMAZİYELEVVEL': 'Cemaziyelevvel',
    'CEMAZIYELEVVEL': 'Cemaziyelevvel',
    'CEMAZİYÜLEVVEL': 'Cemaziyelevvel',
    'CEMAZIYULEVVEL': 'Cemaziyelevvel',
    'CEMAZİYÜLAHİR': 'Cemaziyelahir',
    'CEMAZIYELAHIR': 'Cemaziyelahir',
    'CEMAZIYÜLAHİR': 'Cemaziyelahir',
    'CEMAZIYULAHIR': 'Cemaziyelahir',
    'C.AHİR': 'Cemaziyelahir',
    'C.HİR': 'Cemaziyelahir',
    'RECEB': 'Recep',
    'RECEP': 'Recep',
    'ŞABAN': 'Şaban',
    'SABAN': 'Şaban',
    'RAMAZAN': 'Ramazan',
    'RAMADHAN': 'Ramazan',
    'ŞEVVAL': 'Şevval',
    'SEVVAL': 'Şevval',
    'ZİLKADE': 'Zilkade',
    'ZILKADE': 'Zilkade',
    'ZİLHİCCE': 'Zilhicce',
    'ZILHİCCE': 'Zilhicce',
    'ZILHICCE': 'Zilhicce',
    // Mixed case variations (nadir durumlar için)
    'Muharrem': 'Muharrem',
    'Safer': 'Safer',
    'Rebiülevvel': 'Rebiülevvel',
    'Rebiülahir': 'Rebiülahir',
    'Cemaziyelevvel': 'Cemaziyelevvel',
    'Cemaziyelahir': 'Cemaziyelahir',
    'Recep': 'Recep',
    'Şaban': 'Şaban',
    'Ramazan': 'Ramazan',
    'Şevval': 'Şevval',
    'Zilkade': 'Zilkade',
    'Zilhicce': 'Zilhicce',
  };

  /// API'den gelen ay ismini canonical forma dönüştürür
  /// Performans: O(1) Map lookup kullanır
  static String normalize(String apiMonthName) {
    if (apiMonthName.isEmpty) return apiMonthName;
    
    final trimmed = apiMonthName.trim();
    
    // Önce direkt lookup dene (case-sensitive)
    final directMatch = _apiToCanonical[trimmed];
    if (directMatch != null) return directMatch;
    
    // Sonra uppercase lookup dene (case-insensitive)
    final upper = trimmed.toUpperCase();
    return _apiToCanonical[upper] ?? _fallbackNormalize(trimmed);
  }
  
  /// Fallback: eğer mapping'de yoksa ilk harfi büyük yap
  static String _fallbackNormalize(String input) {
    if (input.isEmpty) return input;
    // İlk harfi büyük, geri kalanını küçük yap
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Canonical ay ismini farklı dillere çevirir
  static String translate(String canonicalMonth, String languageCode) {
    final translations = _monthTranslations[canonicalMonth];
    if (translations == null) return canonicalMonth;
    return translations[languageCode] ?? translations['tr'] ?? canonicalMonth;
  }

  static const Map<String, Map<String, String>> _monthTranslations = {
    'Muharrem': {
      'tr': 'Muharrem',
      'en': 'Muharram',
      'ar': 'محرم',
    },
    'Safer': {
      'tr': 'Safer',
      'en': 'Safar',
      'ar': 'صفر',
    },
    'Rebiülevvel': {
      'tr': 'Rebiülevvel',
      'en': 'Rabi\' al-awwal',
      'ar': 'ربيع الأول',
    },
    'Rebiülahir': {
      'tr': 'Rebiülahir',
      'en': 'Rabi\' al-thani',
      'ar': 'ربيع الآخر',
    },
    'Cemaziyelevvel': {
      'tr': 'Cemaziyelevvel',
      'en': 'Jumada al-awwal',
      'ar': 'جمادى الأول',
    },
    'Cemaziyelahir': {
      'tr': 'Cemaziyelahir',
      'en': 'Jumada al-thani',
      'ar': 'جمادى الآخر',
    },
    'Recep': {
      'tr': 'Recep',
      'en': 'Rajab',
      'ar': 'رجب',
    },
    'Şaban': {
      'tr': 'Şaban',
      'en': 'Sha\'ban',
      'ar': 'شعبان',
    },
    'Ramazan': {
      'tr': 'Ramazan',
      'en': 'Ramadan',
      'ar': 'رمضان',
    },
    'Şevval': {
      'tr': 'Şevval',
      'en': 'Shawwal',
      'ar': 'شوال',
    },
    'Zilkade': {
      'tr': 'Zilkade',
      'en': 'Dhu al-Qi\'dah',
      'ar': 'ذو القعدة',
    },
    'Zilhicce': {
      'tr': 'Zilhicce',
      'en': 'Dhu al-Hijjah',
      'ar': 'ذو الحجة',
    },
  };
}

/// Dini gün event isimlerini normalize eder ve canonical key'e dönüştürür
/// Büyük/küçük harf kullanımına dikkat eder, kısaltma kullanmaz
class ReligiousEventMapping {
  // API'den gelen event isimlerinden canonical key'lere mapping (case-insensitive lookup için uppercase key)
  static const Map<String, String> _apiToCanonical = {
    // Tam isimler
    'ÜÇ AYLARIN BAŞLANGICI': 'uc_aylarin_baslangici',
    'REGAİB KANDİLİ': 'regaib_kandili',
    'REGAYIP KANDİLİ': 'regaib_kandili',
    'REGAİP KANDİLİ': 'regaib_kandili',
    'MİRAC KANDİLİ': 'mirac_kandili',
    'MİRAÇ KANDİLİ': 'mirac_kandili',
    'BERAT KANDİLİ': 'berat_kandili',
    'RAMAZAN BAŞLANGICI': 'ramazan_baslangici',
    'KADİR GECESİ': 'kadir_gecesi',
    'KADIR GECESİ': 'kadir_gecesi',
    'KADİR GECESİ.': 'kadir_gecesi',
    'AREFE': 'arefe', // arefeType'a göre ayrılacak
    'RAMAZAN BAYRAMI (1 GÜN)': 'ramazan_bayrami_1_gun',
    'RAMAZAN BAYRAMI (1. Gün)': 'ramazan_bayrami_1_gun',
    'RAMAZAN BAYRAMI (1 GUN)': 'ramazan_bayrami_1_gun',
    'RAMAZAN BAYRAMI (2 GÜN)': 'ramazan_bayrami_2_gun',
    'RAMAZAN BAYRAMI (2. Gün)': 'ramazan_bayrami_2_gun',
    'RAMAZAN BAYRAMI (2 GUN)': 'ramazan_bayrami_2_gun',
    'RAMAZAN BAYRAMI (3 GÜN)': 'ramazan_bayrami_3_gun',
    'RAMAZAN BAYRAMI (3. Gün)': 'ramazan_bayrami_3_gun',
    'RAMAZAN BAYRAMI (3 GUN)': 'ramazan_bayrami_3_gun',
    'KURBAN BAYRAMI (1 GÜN)': 'kurban_bayrami_1_gun',
    'KURBAN BAYRAMI (1. Gün)': 'kurban_bayrami_1_gun',
    'KURBAN BAYRAMI (1 GUN)': 'kurban_bayrami_1_gun',
    'KURBAN BAYRAMI (2 GÜN)': 'kurban_bayrami_2_gun',
    'KURBAN BAYRAMI (2. Gün)': 'kurban_bayrami_2_gun',
    'KURBAN BAYRAMI (2 GUN)': 'kurban_bayrami_2_gun',
    'KURBAN BAYRAMI (3 GÜN)': 'kurban_bayrami_3_gun',
    'KURBAN BAYRAMI (3. Gün)': 'kurban_bayrami_3_gun',
    'KURBAN BAYRAMI (3 GUN)': 'kurban_bayrami_3_gun',
    'KURBAN BAYRAMI (4 GÜN)': 'kurban_bayrami_4_gun',
    'KURBAN BAYRAMI (4. Gün)': 'kurban_bayrami_4_gun',
    'KURBAN BAYRAMI (4 GUN)': 'kurban_bayrami_4_gun',
    'HİCRİ YILBAŞI': 'hicri_yilbasi',
    'HICRI YILBAŞI': 'hicri_yilbasi',
    'AŞURE GÜNÜ': 'asure_gunu',
    'ASURE GUNU': 'asure_gunu',
    'MEVLİD KANDİLİ': 'mevlid_kandili',
    'MEVLID KANDİLİ': 'mevlid_kandili',
    'MEVLİD KANDİLİ.': 'mevlid_kandili',
    // Mixed case variations
    'Üç Ayların Başlangıcı': 'uc_aylarin_baslangici',
    'Regaip Kandili': 'regaib_kandili',
    'Miraç Kandili': 'mirac_kandili',
    'Berat Kandili': 'berat_kandili',
    'Ramazan Başlangıcı': 'ramazan_baslangici',
    'Kadir Gecesi': 'kadir_gecesi',
    'Arefe': 'arefe',
    'Ramazan Bayramı (1. Gün)': 'ramazan_bayrami_1_gun',
    'Ramazan Bayramı (2. Gün)': 'ramazan_bayrami_2_gun',
    'Ramazan Bayramı (3. Gün)': 'ramazan_bayrami_3_gun',
    'Kurban Bayramı (1. Gün)': 'kurban_bayrami_1_gun',
    'Kurban Bayramı (2. Gün)': 'kurban_bayrami_2_gun',
    'Kurban Bayramı (3. Gün)': 'kurban_bayrami_3_gun',
    'Kurban Bayramı (4. Gün)': 'kurban_bayrami_4_gun',
    'Hicri Yılbaşı': 'hicri_yilbasi',
    'Aşure Günü': 'asure_gunu',
    'Mevlid Kandili': 'mevlid_kandili',
  };

  /// API'den gelen event ismini canonical key'e dönüştürür
  /// Performans: O(1) Map lookup kullanır
  static String toCanonicalKey(String apiEventName, String? arefeType) {
    if (apiEventName.isEmpty) return '';
    
    final trimmed = apiEventName.trim();
    
    // Önce direkt lookup dene (case-sensitive)
    var key = _apiToCanonical[trimmed];
    
    // Sonra uppercase lookup dene (case-insensitive)
    if (key == null) {
      final upper = trimmed.toUpperCase();
      key = _apiToCanonical[upper];
    }
    
    // Fallback: normalize et
    if (key == null) {
      key = _fallbackNormalize(trimmed);
    }
    
    // Arefe için özel işlem
    if (key == 'arefe' && arefeType != null && arefeType.trim().isNotEmpty) {
      final normalizedType = arefeType.toLowerCase().trim();
      if (normalizedType == 'ramazan') {
        key = 'arefe_ramazan';
      } else if (normalizedType == 'kurban') {
        key = 'arefe_kurban';
      }
    }
    
    return key;
  }
  
  /// Fallback: event ismini normalize et
  static String _fallbackNormalize(String input) {
    final lower = input.toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
