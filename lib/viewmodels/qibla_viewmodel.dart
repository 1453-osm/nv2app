import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_messages.dart';
import '../utils/app_logger.dart';

/// Kıble durumu
enum QiblaStatus {
  loading,
  ready,
  error,
  needsCalibration,
}

/// Kıble yönü hesaplama ve pusula yönetimi ViewModel'i.
///
/// Bu sınıf şunları yönetir:
/// - GPS koordinatlarından Kıble yönü hesaplama
/// - Pusula sensörü okuma ve yumuşatma
/// - Kabe'ye mesafe hesaplama
/// - Kalibrasyon durumu takibi
class QiblaViewModel extends ChangeNotifier {
  bool _isExpanded = false;
  QiblaStatus _status = QiblaStatus.loading;
  double _qiblaDirection = 0.0;
  double _currentDirection = 0.0;
  double _distanceToKaaba = 0.0;
  String _errorMessage = '';
  ErrorCode? _errorCode;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _compassTimer;
  bool _isUsingGPS = false;

  // Throttle için - 50ms ile daha akıcı güncelleme
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _notifyDebounce = Duration(milliseconds: 50);

  // Stabilite ve kalibrasyon takibi
  DateTime _lastValidHeadingAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _unreliableSinceAt;
  DateTime? _lastReliableAt;
  static const Duration _unreliableGrace = Duration(seconds: 2);
  static const Duration _reliableRecovery = Duration(seconds: 1);

  // Kabe koordinatları
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  // Getters
  bool get isExpanded => _isExpanded;
  QiblaStatus get status => _status;
  double get qiblaDirection => _qiblaDirection;
  double get currentDirection => _currentDirection;
  double get distanceToKaaba => _distanceToKaaba;
  String get errorMessage => _errorMessage;
  ErrorCode? get errorCode => _errorCode;
  bool get isUsingGPS => _isUsingGPS;

  /// UI katmanında hata mesajını oluşturur.
  String getErrorMessage(BuildContext context) {
    if (_errorCode != null) {
      return ErrorMessages.fromErrorCode(context, _errorCode!);
    }
    return _errorMessage;
  }

  /// Kıbleye yönelim kontrolü (5 derece tolerans).
  bool get isPointingToQibla {
    if (_status != QiblaStatus.ready) return false;

    final bool headingIsFresh =
        DateTime.now().difference(_lastValidHeadingAt) < const Duration(seconds: 2);
    if (!headingIsFresh) return false;

    final difference = (_currentDirection - _qiblaDirection).abs();
    return difference <= 5.0 || difference >= 355.0;
  }

  void toggleExpansion() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  void closeQiblaBar() {
    _isExpanded = false;
    notifyListeners();
  }

  /// Kıble yönünü hesaplar.
  Future<void> calculateQiblaDirection() async {
    try {
      _status = QiblaStatus.loading;
      notifyListeners();

      final coordinates = await _getCurrentLocationCoordinates();
      if (coordinates == null) {
        _status = QiblaStatus.error;
        _isUsingGPS = false;
        _errorCode = ErrorCode.gpsLocationNotAvailable;
        _errorMessage = '';
        notifyListeners();
        return;
      }

      _isUsingGPS = true;
      _applyQiblaMetrics(coordinates);
    } catch (e, stackTrace) {
      AppLogger.error('Kıble yönü hesaplama hatası', tag: 'QiblaViewModel', error: e, stackTrace: stackTrace);
      _status = QiblaStatus.error;
      _isUsingGPS = false;
      _errorCode = ErrorCode.qiblaDirectionCalculationFailed;
      _errorMessage = '';
    }

    notifyListeners();
  }

  /// Pusula sensörünü başlatır.
  void _startCompassSimulation() {
    _compassSubscription?.cancel();
    _compassTimer?.cancel();

    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final DateTime now = DateTime.now();
      final bool hasHeading = event.heading != null;
      final bool isReliable = _isCompassEventReliable(event);

      // Yumuşatma filtresi ile açı güncelle (alpha: 0.25 = daha hızlı tepki)
      if (hasHeading) {
        _currentDirection = _smoothAngleDegrees(_currentDirection, event.heading!, 0.25);
        if (_currentDirection < 0) _currentDirection += 360;
        if (_currentDirection >= 360) _currentDirection -= 360;
        _lastValidHeadingAt = now;
        _lastReliableAt = isReliable ? now : _lastReliableAt;

        // Throttle: Çok sık notifyListeners çağrısını engelle
        if (now.difference(_lastNotifyTime) > _notifyDebounce) {
          notifyListeners();
          _lastNotifyTime = now;
        }
      }

      // Kalibrasyon gereksinimi tespiti (histerezis ile)
      _handleCalibrationStatus(now, hasHeading, isReliable);
    });

    // Yardımcı stabilizasyon timer'ı
    _compassTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final DateTime now = DateTime.now();
      final bool headingTimedOut = now.difference(_lastValidHeadingAt) > const Duration(seconds: 2);

      if (headingTimedOut) {
        final double previous = _currentDirection;
        _currentDirection = _smoothAngleDegrees(_currentDirection, _qiblaDirection, 0.05);
        if (_currentDirection < 0) _currentDirection += 360;
        if (_currentDirection >= 360) _currentDirection -= 360;

        if ((previous - _currentDirection).abs() > 0.0001) {
          notifyListeners();
        }
      }
    });
  }

  /// Kalibrasyon durumunu yönetir.
  void _handleCalibrationStatus(DateTime now, bool hasHeading, bool isReliable) {
    if (!isReliable || !hasHeading) {
      _unreliableSinceAt ??= now;

      if (_status == QiblaStatus.ready || _status == QiblaStatus.needsCalibration) {
        if (now.difference(_unreliableSinceAt!) >= _unreliableGrace) {
          if (_status != QiblaStatus.needsCalibration) {
            _status = QiblaStatus.needsCalibration;
            notifyListeners();
          }
        }
      }
    } else {
      _unreliableSinceAt = null;

      if (_status == QiblaStatus.needsCalibration && _lastReliableAt != null) {
        if (now.difference(_lastReliableAt!) >= _reliableRecovery) {
          _status = QiblaStatus.ready;
          notifyListeners();
        }
      }
    }
  }

  /// Pusulayı yeniler.
  Future<void> refreshCompass() async {
    _status = QiblaStatus.loading;
    notifyListeners();

    try {
      final coordinates = await _getCurrentLocationCoordinates();
      if (coordinates != null) {
        _isUsingGPS = true;
        _applyQiblaMetrics(coordinates);
      } else {
        _status = QiblaStatus.error;
        _isUsingGPS = false;
        _errorCode = ErrorCode.gpsLocationNotAvailable;
        _errorMessage = '';
      }
    } catch (e, stackTrace) {
      AppLogger.error('Konum yenileme hatası', tag: 'QiblaViewModel', error: e, stackTrace: stackTrace);
      _status = QiblaStatus.error;
      _isUsingGPS = false;
      _errorCode = ErrorCode.locationRefreshFailed;
      _errorMessage = '';
    }

    notifyListeners();
  }

  /// Cihazın konum servisleri ayarlarını açar.
  Future<void> openLocationSettings() async {
    try {
      final bool opened = await Geolocator.openLocationSettings();
      if (!opened) {
        await Geolocator.openAppSettings();
      }
    } catch (e) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {
        AppLogger.warning('Konum ayarları açılamadı', tag: 'QiblaViewModel');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HESAPLAMA METODLARİ
  // ═══════════════════════════════════════════════════════════════════════════

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  double _radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  /// İki koordinat arasındaki mesafeyi hesaplar (Haversine formülü).
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Gerçek zamanlı GPS koordinatlarını alır.
  Future<Map<String, double>?> _getCurrentLocationCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Konum servisi kapalı', tag: 'QiblaViewModel');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Konum izni reddedildi', tag: 'QiblaViewModel');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Konum izni kalıcı olarak reddedildi', tag: 'QiblaViewModel');
        return null;
      }

      final LocationSettings locationSettings = _buildLocationSettings();
      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
      } on TimeoutException {
        AppLogger.warning('GPS timeout, son bilinen konum deneniyor', tag: 'QiblaViewModel');
        position = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: _isAndroid,
        );
      }

      position ??= await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: _isAndroid,
      );

      if (position == null) {
        AppLogger.warning('Konum alınamadı', tag: 'QiblaViewModel');
        return null;
      }

      AppLogger.debug('Konum alındı: ${position.latitude}, ${position.longitude}', tag: 'QiblaViewModel');

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Konum alma hatası', tag: 'QiblaViewModel', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  LocationSettings _buildLocationSettings() {
    const Duration timeout = Duration(seconds: 12);

    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        timeLimit: timeout,
      );
    }

    if (_isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        timeLimit: timeout,
        pauseLocationUpdatesAutomatically: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 12),
    );
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Pusula event güvenilirliğini kontrol eder.
  bool _isCompassEventReliable(CompassEvent event) {
    final num? accuracy = event.accuracy;
    final bool hasHeading = event.heading != null;

    if (!hasHeading) return false;
    if (accuracy == null) return true; // iOS için

    return accuracy >= 2; // Android: 2=medium, 3=high
  }

  /// Açıları yumuşatır (exponential smoothing).
  double _smoothAngleDegrees(double currentDeg, double targetDeg, double alpha) {
    double delta = ((targetDeg - currentDeg + 540) % 360) - 180;
    double next = currentDeg + alpha * delta;
    next %= 360;
    if (next < 0) next += 360;
    return next;
  }

  /// Kıble metriklerini uygular.
  void _applyQiblaMetrics(Map<String, double> coordinates) {
    final lat1 = _degreesToRadians(coordinates['latitude']!);
    final lon1 = _degreesToRadians(coordinates['longitude']!);
    final lat2 = _degreesToRadians(kaabaLatitude);
    final lon2 = _degreesToRadians(kaabaLongitude);

    final deltaLon = lon2 - lon1;
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

    _qiblaDirection = _radiansToDegrees(math.atan2(y, x));
    if (_qiblaDirection < 0) {
      _qiblaDirection += 360;
    }

    _distanceToKaaba = _calculateDistance(
      coordinates['latitude']!,
      coordinates['longitude']!,
      kaabaLatitude,
      kaabaLongitude,
    );

    _status = QiblaStatus.ready;
    _startCompassSimulation();

    AppLogger.success('Kıble yönü: ${_qiblaDirection.toStringAsFixed(1)}°, Mesafe: ${_distanceToKaaba.toStringAsFixed(0)} km', tag: 'QiblaViewModel');
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _compassTimer?.cancel();
    super.dispose();
  }
}
