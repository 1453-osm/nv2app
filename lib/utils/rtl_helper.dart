import 'package:flutter/material.dart';

/// RTL (Right-to-Left) dil desteği için yardımcı sınıf
class RTLHelper {
  /// RTL dilleri listesi
  static const List<String> rtlLanguages = [
    'ar', // Arapça
    'he', // İbranice
    'fa', // Farsça
    'ur', // Urduca
    'yi', // Yidiş
  ];

  /// Verilen locale'in RTL dil olup olmadığını kontrol eder
  static bool isRTL(Locale? locale) {
    if (locale == null) return false;
    return rtlLanguages.contains(locale.languageCode);
  }

  /// BuildContext'ten RTL olup olmadığını kontrol eder
  static bool isRTLFromContext(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

  /// Verilen locale'e göre TextDirection döndürür
  static TextDirection getTextDirection(Locale? locale) {
    return isRTL(locale) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// BuildContext'ten TextDirection döndürür
  static TextDirection getTextDirectionFromContext(BuildContext context) {
    return Directionality.of(context);
  }
}
