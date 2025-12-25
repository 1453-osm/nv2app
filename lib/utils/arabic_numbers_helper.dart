/// Arapça rakam dönüşümü için yardımcı fonksiyonlar
/// 
/// Arapça rakamlar:
/// 0: ٠, 1: ١, 2: ٢, 3: ٣, 4: ٤, 5: ٥, 6: ٦, 7: ٧, 8: ٨, 9: ٩

/// Batı rakamlarını (0-9) Arapça rakamlara (٠-٩) dönüştürür
String convertToArabicNumerals(String input) {
  if (input.isEmpty) return input;
  
  final arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final buffer = StringBuffer();
  
  for (final char in input.runes) {
    final charString = String.fromCharCode(char);
    if (charString.codeUnitAt(0) >= 48 && charString.codeUnitAt(0) <= 57) {
      // 0-9 arası rakam
      final digit = int.parse(charString);
      buffer.write(arabicNumerals[digit]);
    } else {
      // Rakam değilse olduğu gibi ekle
      buffer.write(charString);
    }
  }
  
  return buffer.toString();
}

/// Arapça rakamları (٠-٩) batı rakamlarına (0-9) dönüştürür
String convertFromArabicNumerals(String input) {
  if (input.isEmpty) return input;
  
  final arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final buffer = StringBuffer();
  
  for (final char in input.runes) {
    final charString = String.fromCharCode(char);
    final index = arabicNumerals.indexOf(charString);
    if (index != -1) {
      // Arapça rakam bulundu
      buffer.write(index.toString());
    } else {
      // Arapça rakam değilse olduğu gibi ekle
      buffer.write(charString);
    }
  }
  
  return buffer.toString();
}

/// Verilen dil koduna göre rakamları dönüştürür
/// Arapça (ar) için Arapça rakamları, diğer diller için batı rakamlarını döndürür
String localizeNumerals(String input, String languageCode) {
  if (languageCode == 'ar') {
    return convertToArabicNumerals(input);
  }
  return input;
}

