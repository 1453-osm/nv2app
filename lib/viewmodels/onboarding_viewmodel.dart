import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import '../services/permission_service.dart';

class OnboardingViewModel extends ChangeNotifier {
  final OnboardingService _onboardingService = OnboardingService();
  final PermissionService _permissionService = PermissionService();
  
  bool _isLoading = true;
  bool _isFirstLaunch = true;
  int _currentPage = 0;
  bool _isManualLocationMode = false;
  
  // Permissions state
  bool _notificationGranted = false;
  bool _locationGranted = false;
  bool _exactAlarmAllowed = true;
  bool _ignoringBatteryOptimizations = false;
  
  bool get notificationGranted => _notificationGranted;
  bool get locationGranted => _locationGranted;
  bool get exactAlarmAllowed => _exactAlarmAllowed;
  bool get ignoringBatteryOptimizations => _ignoringBatteryOptimizations;
  
  bool get isLoading => _isLoading;
  bool get isFirstLaunch => _isFirstLaunch;
  int get currentPage => _currentPage;
  bool get isManualLocationMode => _isManualLocationMode;
  
  /// Uygulama başlatıldığında çağrılır
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _isFirstLaunch = await _onboardingService.isFirstLaunch();
      // İzin durumlarını oku
      _notificationGranted = await _permissionService.isNotificationGranted();
      _locationGranted = await _permissionService.isLocationGranted();
      _exactAlarmAllowed = await _permissionService.isExactAlarmAllowed();
      _ignoringBatteryOptimizations = await _permissionService.isIgnoringBatteryOptimizations();
    } catch (e) {
      // Hata durumunda varsayılan olarak ilk kurulum kabul et
      _isFirstLaunch = true;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Tüm izin durumlarını yeniden okur
  Future<void> refreshPermissions() async {
    try {
      _notificationGranted = await _permissionService.isNotificationGranted();
      _locationGranted = await _permissionService.isLocationGranted();
      _exactAlarmAllowed = await _permissionService.isExactAlarmAllowed();
      _ignoringBatteryOptimizations = await _permissionService.isIgnoringBatteryOptimizations();
    } finally {
      notifyListeners();
    }
  }
  
  /// Bildirim iznini ister ve günceller
  Future<void> requestNotificationPermission() async {
    final ok = await _permissionService.requestNotificationPermission();
    _notificationGranted = ok;
    notifyListeners();
  }
  
  /// Konum iznini ister ve günceller
  Future<void> requestLocationPermission() async {
    final ok = await _permissionService.requestLocationPermission();
    _locationGranted = ok;
    notifyListeners();
  }
  
  /// Kesin alarm iznini ayarlar sayfasından ister
  Future<void> requestExactAlarmPermission() async {
    await _permissionService.requestExactAlarmPermission();
    // Ayarlardan dönünce lifecycle ile tekrar kontrol edilecek
  }

  /// Pil optimizasyonundan çıkarma yönlendirmesi
  Future<void> requestIgnoreBatteryOptimizations() async {
    final ok = await _permissionService.requestIgnoreBatteryOptimizations();
    if (ok) {
      // Kullanıcı ayara gitti; döndüğünde refreshPermissions çağrısı ile durum güncellenecek
    }
  }
  
  /// Sayfa değişikliğini yönetir
  void onPageChanged(int page) {
    _currentPage = page;
    notifyListeners();
  }
  
  /// Manuel konum seçimi modunu açar/kapatır
  void toggleManualLocationMode() {
    _isManualLocationMode = !_isManualLocationMode;
    notifyListeners();
  }
  
  /// Manuel konum seçimi modunu kapatır
  void exitManualLocationMode() {
    _isManualLocationMode = false;
    notifyListeners();
  }
  
  /// Onboarding'i tamamlar
  Future<void> completeOnboarding() async {
    try {
      await _onboardingService.setFirstLaunchCompleted();
      _isFirstLaunch = false;
      notifyListeners();
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi verilebilir
      debugPrint('Onboarding tamamlanırken hata: $e');
    }
  }
} 