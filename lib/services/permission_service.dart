import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'widget_bridge.dart';

/// Uygulama izinlerini yöneten servis.
/// MVVM: ViewModel'ler bu servis üzerinden izin durumlarını okur/ister.
class PermissionService {
  /// Bildirim izni mevcut mu?
  Future<bool> isNotificationGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    // iOS: izni Notification API ile istemek gerekir, permission_handler iOS'ta destekler.
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited;
  }

  /// Bildirim iznini iste.
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final result = await Permission.notification.request();
    return result.isGranted || result.isLimited;
  }

  /// Konum izni mevcut mu?
  Future<bool> isLocationGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Konum iznini iste.
  Future<bool> requestLocationPermission() async {
    final result = await Permission.location.request();
    return result.isGranted;
  }

  /// Kesin alarm planlama izni mevcut mu? (Android 12+)
  Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await WidgetBridgeService.isExactAlarmAllowed();
    } catch (_) {
      return true; // Eski sürümlerde sorun yaratmamak için true döner
    }
  }

  /// Kesin alarm izni talep et (Android 12+ ayar sayfasına yönlendirir)
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    await WidgetBridgeService.requestExactAlarmPermission();
  }

  /// Pil optimizasyonundan çıkarılmış mı? (Android)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await WidgetBridgeService.isIgnoringBatteryOptimizations();
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcıyı pil optimizasyonundan çıkmaya yönlendir
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await WidgetBridgeService.requestIgnoreBatteryOptimizations();
    } catch (_) {
      return false;
    }
  }

  /// Bildirimlerin düzgün çalışması için gerekli tüm izinleri kontrol et
  Future<Map<String, bool>> checkAllNotificationPermissions() async {
    final Map<String, bool> permissions = {};
    
    permissions['notification'] = await isNotificationGranted();
    permissions['exactAlarm'] = await isExactAlarmAllowed();
    permissions['batteryOptimization'] = await isIgnoringBatteryOptimizations();
    
    return permissions;
  }

  /// Eksik izinleri toplu olarak iste
  Future<void> requestMissingNotificationPermissions() async {
    final permissions = await checkAllNotificationPermissions();
    
    if (!permissions['notification']!) {
      await requestNotificationPermission();
    }
    
    if (!permissions['exactAlarm']!) {
      await requestExactAlarmPermission();
    }
    
    if (!permissions['batteryOptimization']!) {
      await requestIgnoreBatteryOptimizations();
    }
  }
}


