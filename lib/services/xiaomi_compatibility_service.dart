import 'dart:io';
import 'package:flutter/services.dart';

class XiaomiCompatibilityService {
  static const MethodChannel _channel = MethodChannel('com.osm.namazvaktim/xiaomi');

  // Xiaomi cihaz kontrolü
  static bool isXiaomiDevice() {
    if (!Platform.isAndroid) return false;

    final manufacturer = Platform.operatingSystemVersion.toLowerCase();
    final model = Platform.localeName.toLowerCase();

    return manufacturer.contains('xiaomi') ||
           model.contains('xiaomi') ||
           manufacturer.contains('mi ') ||
           model.contains('mi ');
  }

  // Xiaomi cihazlarda gerekli optimizasyonları uygula
  static Future<void> applyXiaomiOptimizations() async {
    if (!isXiaomiDevice()) return;

    try {
      // Platform kanalı üzerinden Xiaomi optimizasyonlarını uygula
      await _channel.invokeMethod('applyXiaomiOptimizations');
    } on PlatformException catch (e) {
      print('Xiaomi optimizasyon hatası: ${e.message}');
    }
  }

  // Xiaomi AutoStart ayarlarını aç
  static Future<bool> openXiaomiAutoStartSettings() async {
    if (!isXiaomiDevice()) return false;

    try {
      final result = await _channel.invokeMethod('openMiuiAutostartSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Xiaomi AutoStart ayarları açma hatası: ${e.message}');
      return false;
    }
  }

  // Xiaomi cihaz uyumluluk mesajlarını al
  static Map<String, String> getCompatibilityMessages() {
    return {
      'title': 'Xiaomi Cihaz Uyumluluğu',
      'message': 'Xiaomi cihazınızda en iyi deneyim için aşağıdaki ayarları yapmanız önerilir:',
      'autostart': '• Güvenlik uygulamasında AutoStart\'ı etkinleştirin',
      'battery': '• Pil optimizasyonlarını devre dışı bırakın',
      'notifications': '• Bildirim izinlerini kontrol edin',
      'background': '• Arka plan çalışmasına izin verin',
    };
  }

  // Xiaomi cihazlarda performans tavsiyeleri
  static List<String> getPerformanceTips() {
    return [
      'Xiaomi cihazlarda pil optimizasyonlarını devre dışı bırakın',
      'Güvenlik uygulamasından AutoStart özelliğini etkinleştirin',
      'Bildirim ayarlarında uygulamanın tam izinlere sahip olduğundan emin olun',
      'Uygulama kilitlemeyi etkinleştirerek arka plan çalışmasını sağlayın',
      'MIUI\'da "Uygulama kilitleme" özelliğini kullanın'
    ];
  }

  // Xiaomi uyumluluk kontrolü
  static Future<Map<String, bool>> checkXiaomiCompatibility() async {
    if (!isXiaomiDevice()) {
      return {
        'isXiaomi': false,
        'autoStartEnabled': true,
        'batteryOptimizationDisabled': true,
        'notificationsEnabled': true,
      };
    }

    try {
      final result = await _channel.invokeMethod('checkXiaomiCompatibility');
      return Map<String, bool>.from(result ?? {});
    } catch (e) {
      return {
        'isXiaomi': true,
        'autoStartEnabled': false,
        'batteryOptimizationDisabled': false,
        'notificationsEnabled': false,
      };
    }
  }
}
