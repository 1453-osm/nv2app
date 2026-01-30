import 'package:flutter/foundation.dart';
import '../services/onboarding_service.dart';
import '../services/permission_service.dart';

class OnboardingViewModel extends ChangeNotifier {
  final OnboardingService _onboardingService = OnboardingService();
  final PermissionService _permissionService = PermissionService();

  bool _isLoading = true;
  bool? _isFirstLaunch; // nullable - başlangıçta bilinmeyen
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
  bool get isFirstLaunch => _isFirstLaunch ?? true; // Varsayılan true (güvenli)
  int get currentPage => _currentPage;
  bool get isManualLocationMode => _isManualLocationMode;

  bool get isInitialized =>
      _isFirstLaunch != null; // Başlatılıp başlatılmadığını kontrol et

  /// Uygulama başlatıldığında çağrılır
  Future<void> initialize() async {
    // Eğer zaten başlatıldıysa, tekrar başlatma
    if (isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // İlk kurulum durumunu oku - timeout ile
      try {
        _isFirstLaunch = await _onboardingService.isFirstLaunch().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Timeout durumunda varsayılan olarak ilk kurulum kabul et
            if (kDebugMode) {
              debugPrint('OnboardingService.isFirstLaunch timeout');
            }
            return true;
          },
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('OnboardingService.isFirstLaunch error: $e');
        }
        _isFirstLaunch = true; // Güvenli varsayılan
      }

      // İzin durumlarını paralel olarak oku (daha hızlı başlatma)
      await Future.wait([
        _loadNotificationPermission(),
        _loadLocationPermission(),
        _loadExactAlarmPermission(),
        _loadBatteryOptimizationStatus(),
      ]);
    } catch (e) {
      // Herhangi bir beklenmeyen hata durumunda varsayılanları kullan
      if (kDebugMode) {
        debugPrint('OnboardingViewModel initialize failed: $e');
      }
    } finally {
      // Her durumda _isFirstLaunch set edilmiş olmalı (isInitialized için gerekli)
      _isFirstLaunch ??= true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadNotificationPermission() async {
    try {
      _notificationGranted =
          await _permissionService.isNotificationGranted().timeout(
                const Duration(seconds: 2),
                onTimeout: () => false,
              );
    } catch (_) {
      _notificationGranted = false;
    }
  }

  Future<void> _loadLocationPermission() async {
    try {
      _locationGranted = await _permissionService.isLocationGranted().timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
    } catch (_) {
      _locationGranted = false;
    }
  }

  Future<void> _loadExactAlarmPermission() async {
    try {
      _exactAlarmAllowed =
          await _permissionService.isExactAlarmAllowed().timeout(
                const Duration(seconds: 2),
                onTimeout: () =>
                    true, // Varsayılan olarak true (eski Android sürümleri için)
              );
    } catch (_) {
      _exactAlarmAllowed = true;
    }
  }

  Future<void> _loadBatteryOptimizationStatus() async {
    try {
      _ignoringBatteryOptimizations =
          await _permissionService.isIgnoringBatteryOptimizations().timeout(
                const Duration(seconds: 2),
                onTimeout: () => false,
              );
    } catch (_) {
      _ignoringBatteryOptimizations = false;
    }
  }

  /// Tüm izin durumlarını yeniden okur
  Future<void> refreshPermissions() async {
    try {
      _notificationGranted = await _permissionService.isNotificationGranted();
      _locationGranted = await _permissionService.isLocationGranted();
      _exactAlarmAllowed = await _permissionService.isExactAlarmAllowed();
      _ignoringBatteryOptimizations =
          await _permissionService.isIgnoringBatteryOptimizations();
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
