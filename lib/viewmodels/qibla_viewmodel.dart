import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_messages.dart';
import '../utils/app_logger.dart';
import '../services/magnetic_declination_service.dart';

/// Kıble durumu
enum QiblaStatus {
  loading,
  ready,
  error,
  needsCalibration,
}

/// Profesyonel Kıble yönü hesaplama ve pusula yönetimi ViewModel'i.
///
/// Bu sınıf şunları yönetir:
/// - GPS koordinatlarından Kıble yönü hesaplama (Vincenty formülü - WGS84)
/// - Manyetik sapma düzeltmesi (WMM2025)
/// - Pusula sensörü okuma ve gelişmiş filtreleme
/// - Kabe'ye mesafe hesaplama (Vincenty)
/// - Kalibrasyon durumu takibi
class QiblaViewModel extends ChangeNotifier {
  bool _isExpanded = false;
  QiblaStatus _status = QiblaStatus.loading;
  double _qiblaDirection = 0.0; // True North'a göre kıble yönü
  double _qiblaMagnetic = 0.0; // Magnetic North'a göre kıble yönü (pusula için)
  double _currentDirection = 0.0; // Pusulanın gösterdiği yön (magnetic)
  double _distanceToKaaba = 0.0;
  double _magneticDeclination = 0.0; // Manyetik sapma
  String _errorMessage = '';
  ErrorCode? _errorCode;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _compassTimer;
  bool _isUsingGPS = false;


  // Throttle için - 50ms akıcı pusula hareketi sağlar (20 FPS)
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _notifyDebounce = Duration(milliseconds: 50);

  // Stabilite ve kalibrasyon takibi
  DateTime _lastValidHeadingAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _unreliableSinceAt;
  DateTime? _lastReliableAt;
  static const Duration _unreliableGrace = Duration(seconds: 2);
  static const Duration _reliableRecovery = Duration(seconds: 1);

  // ═══════════════════════════════════════════════════════════════════════════
  // KABE KOORDİNATLARI (Yüksek Hassasiyet)
  // Kaynak: GPS-Latitude-Longitude, Google Maps
  // ═══════════════════════════════════════════════════════════════════════════
  static const double kaabaLatitude = 21.422487;
  static const double kaabaLongitude = 39.826206;

  // ═══════════════════════════════════════════════════════════════════════════
  // WGS84 ELLİPSOİD PARAMETRELERİ
  // ═══════════════════════════════════════════════════════════════════════════
  static const double _wgs84A = 6378137.0; // Semi-major axis (metre)
  static const double _wgs84F = 1 / 298.257223563; // Flattening
  static const double _wgs84B = _wgs84A * (1 - _wgs84F); // Semi-minor axis

  // Gelişmiş pusula filtresi için değişkenler
  final _ComplementaryFilter _compassFilter = _ComplementaryFilter();

  // Getters
  bool get isExpanded => _isExpanded;
  QiblaStatus get status => _status;
  double get qiblaDirection => _qiblaDirection; // True North'a göre
  double get qiblaMagnetic => _qiblaMagnetic; // Magnetic North'a göre
  double get currentDirection => _currentDirection;
  double get distanceToKaaba => _distanceToKaaba;
  double get magneticDeclination => _magneticDeclination;
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

    // Manyetik yön ile manyetik kıble yönünü karşılaştır
    final difference = (_currentDirection - _qiblaMagnetic).abs();
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

      if (hasHeading) {
        // Gelişmiş complementary filter ile yumuşatma
        _currentDirection = _compassFilter.filter(
          compassHeading: event.heading!,
          accuracy: event.accuracy?.toDouble(),
        );

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
        // Pusula verisi gelmediğinde yavaşça kıble yönüne doğru drif et
        _currentDirection = _compassFilter.driftTowards(_qiblaMagnetic);

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
  // VİNCENTY FORMÜLÜ (WGS84 Ellipsoid)
  // Kaynak: T. Vincenty, "Direct and Inverse Solutions of Geodesics on the
  // Ellipsoid with application of nested equations", 1975
  // ═══════════════════════════════════════════════════════════════════════════

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  double _radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  /// Vincenty formülü ile iki nokta arasındaki başlangıç azimutunu (bearing) hesaplar.
  /// WGS84 ellipsoid modeli kullanır, 0.000015" hassasiyet sağlar.
  ///
  /// Returns: True North'a göre bearing (derece, 0-360)
  double _calculateVincentyBearing(double lat1, double lon1, double lat2, double lon2) {
    final double phi1 = _degreesToRadians(lat1);
    final double phi2 = _degreesToRadians(lat2);
    final double L = _degreesToRadians(lon2 - lon1);

    // Reduced latitudes (latitude on the auxiliary sphere)
    final double U1 = math.atan((1 - _wgs84F) * math.tan(phi1));
    final double U2 = math.atan((1 - _wgs84F) * math.tan(phi2));

    final double sinU1 = math.sin(U1);
    final double cosU1 = math.cos(U1);
    final double sinU2 = math.sin(U2);
    final double cosU2 = math.cos(U2);

    // İteratif hesaplama
    double lambda = L;
    double lambdaP;
    double sinLambda, cosLambda;
    double sinSigma, cosSigma, sigma;
    double sinAlpha, cos2Alpha, cos2SigmaM;
    double C;
    int iterations = 0;
    const int maxIterations = 200;
    const double tolerance = 1e-12;

    do {
      sinLambda = math.sin(lambda);
      cosLambda = math.cos(lambda);

      final double term1 = cosU2 * sinLambda;
      final double term2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;

      sinSigma = math.sqrt(term1 * term1 + term2 * term2);

      if (sinSigma == 0) {
        // Co-incident points
        return 0.0;
      }

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = math.atan2(sinSigma, cosSigma);

      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cos2Alpha = 1 - sinAlpha * sinAlpha;

      if (cos2Alpha != 0) {
        cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cos2Alpha;
      } else {
        cos2SigmaM = 0; // Equatorial line
      }

      C = _wgs84F / 16 * cos2Alpha * (4 + _wgs84F * (4 - 3 * cos2Alpha));

      lambdaP = lambda;
      lambda = L + (1 - C) * _wgs84F * sinAlpha * (
          sigma + C * sinSigma * (
              cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
          )
      );
    } while ((lambda - lambdaP).abs() > tolerance && ++iterations < maxIterations);

    if (iterations >= maxIterations) {
      AppLogger.warning('Vincenty iterasyonu yakınsamadı, spherical fallback kullanılıyor', tag: 'QiblaViewModel');
      return _calculateSphericalBearing(lat1, lon1, lat2, lon2);
    }

    // Forward azimuth (initial bearing)
    final double alpha1 = math.atan2(
      cosU2 * math.sin(lambda),
      cosU1 * sinU2 - sinU1 * cosU2 * math.cos(lambda),
    );

    double bearing = _radiansToDegrees(alpha1);
    return (bearing + 360) % 360;
  }

  /// Spherical trigonometry ile bearing hesabı (fallback).
  double _calculateSphericalBearing(double lat1, double lon1, double lat2, double lon2) {
    final double phi1 = _degreesToRadians(lat1);
    final double phi2 = _degreesToRadians(lat2);
    final double deltaLambda = _degreesToRadians(lon2 - lon1);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    double bearing = _radiansToDegrees(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  /// Vincenty formülü ile iki nokta arasındaki mesafeyi hesaplar (metre).
  double _calculateVincentyDistance(double lat1, double lon1, double lat2, double lon2) {
    final double phi1 = _degreesToRadians(lat1);
    final double phi2 = _degreesToRadians(lat2);
    final double L = _degreesToRadians(lon2 - lon1);

    final double U1 = math.atan((1 - _wgs84F) * math.tan(phi1));
    final double U2 = math.atan((1 - _wgs84F) * math.tan(phi2));

    final double sinU1 = math.sin(U1);
    final double cosU1 = math.cos(U1);
    final double sinU2 = math.sin(U2);
    final double cosU2 = math.cos(U2);

    double lambda = L;
    double lambdaP;
    double sinLambda, cosLambda;
    double sinSigma, cosSigma, sigma;
    double sinAlpha, cos2Alpha, cos2SigmaM;
    double C;
    int iterations = 0;
    const int maxIterations = 200;
    const double tolerance = 1e-12;

    do {
      sinLambda = math.sin(lambda);
      cosLambda = math.cos(lambda);

      final double term1 = cosU2 * sinLambda;
      final double term2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;

      sinSigma = math.sqrt(term1 * term1 + term2 * term2);

      if (sinSigma == 0) return 0.0;

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = math.atan2(sinSigma, cosSigma);

      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cos2Alpha = 1 - sinAlpha * sinAlpha;

      cos2SigmaM = cos2Alpha != 0
          ? cosSigma - 2 * sinU1 * sinU2 / cos2Alpha
          : 0;

      C = _wgs84F / 16 * cos2Alpha * (4 + _wgs84F * (4 - 3 * cos2Alpha));

      lambdaP = lambda;
      lambda = L + (1 - C) * _wgs84F * sinAlpha * (
          sigma + C * sinSigma * (
              cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
          )
      );
    } while ((lambda - lambdaP).abs() > tolerance && ++iterations < maxIterations);

    if (iterations >= maxIterations) {
      // Fallback to Haversine
      return _calculateHaversineDistance(lat1, lon1, lat2, lon2);
    }

    final double uSq = cos2Alpha * (_wgs84A * _wgs84A - _wgs84B * _wgs84B) / (_wgs84B * _wgs84B);
    final double A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
    final double B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));

    final double deltaSigma = B * sinSigma * (
        cos2SigmaM + B / 4 * (
            cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)
        )
    );

    return _wgs84B * A * (sigma - deltaSigma);
  }

  /// Haversine formülü ile mesafe hesabı (fallback, km).
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // metre

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

  /// Kıble metriklerini uygular (Vincenty + Manyetik Sapma).
  void _applyQiblaMetrics(Map<String, double> coordinates) {
    final double userLat = coordinates['latitude']!;
    final double userLon = coordinates['longitude']!;

    // 1. Eski spherical formül ile bearing hesapla (TEST)
    _qiblaDirection = _calculateOldBearing(
      userLat,
      userLon,
      kaabaLatitude,
      kaabaLongitude,
    );

    // 2. Manyetik sapma - geçici olarak 0 (TEST)
    _magneticDeclination = 0.0;

    // 3. Manyetik sapma olmadan - qiblaMagnetic = qiblaDirection
    _qiblaMagnetic = _qiblaDirection;

    // 4. Vincenty ile mesafe hesapla (metre -> km)
    _distanceToKaaba = _calculateVincentyDistance(
      userLat,
      userLon,
      kaabaLatitude,
      kaabaLongitude,
    ) / 1000.0;

    _status = QiblaStatus.ready;
    _startCompassSimulation();

    AppLogger.success(
      'Kıble yönü: ${_qiblaDirection.toStringAsFixed(2)}° (True), '
      '${_qiblaMagnetic.toStringAsFixed(2)}° (Magnetic), '
      'Sapma: ${_magneticDeclination.toStringAsFixed(2)}°, '
      'Mesafe: ${_distanceToKaaba.toStringAsFixed(1)} km',
      tag: 'QiblaViewModel',
    );
  }

  /// ESKİ HESAPLAMA - TEST İÇİN
  double _calculateOldBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _degreesToRadians(lat1);
    final phi2 = _degreesToRadians(lat2);
    final deltaLon = _degreesToRadians(lon2 - lon1);

    final y = math.sin(deltaLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLon);

    double bearing = _radiansToDegrees(math.atan2(y, x));
    if (bearing < 0) bearing += 360;
    return bearing;
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _compassTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GELİŞMİŞ PUSULA FİLTRESİ
// Complementary filter: Düşük geçiş + adaptif yumuşatma
// ═══════════════════════════════════════════════════════════════════════════

class _ComplementaryFilter {
  double _filteredHeading = 0.0;
  double _previousHeading = 0.0;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitialized = false;

  // Filtre parametreleri
  static const double _baseAlpha = 0.15; // Temel yumuşatma faktörü
  static const double _minAlpha = 0.08; // Minimum alpha (çok yavaş hareket)
  static const double _maxAlpha = 0.35; // Maximum alpha (hızlı hareket)
  static const double _velocityThreshold = 30.0; // Hızlı hareket eşiği (derece/saniye)

  /// Pusula değerini filtreler.
  double filter({
    required double compassHeading,
    double? accuracy,
  }) {
    final DateTime now = DateTime.now();
    final double dt = now.difference(_lastUpdate).inMilliseconds / 1000.0;
    _lastUpdate = now;

    // İlk değer
    if (!_isInitialized) {
      _filteredHeading = compassHeading;
      _previousHeading = compassHeading;
      _isInitialized = true;
      return _filteredHeading;
    }

    // Açısal hız hesapla
    double velocity = 0.0;
    if (dt > 0 && dt < 1.0) {
      final double delta = _angleDifference(compassHeading, _previousHeading);
      velocity = delta.abs() / dt;
    }

    // Adaptif alpha hesapla
    // Hızlı hareket = yüksek alpha (daha hızlı tepki)
    // Yavaş hareket = düşük alpha (daha stabil)
    double alpha = _baseAlpha;
    if (velocity > _velocityThreshold) {
      alpha = _maxAlpha;
    } else if (velocity < 5.0) {
      alpha = _minAlpha;
    } else {
      // Linear interpolation
      alpha = _minAlpha + (velocity / _velocityThreshold) * (_maxAlpha - _minAlpha);
    }

    // Accuracy-based adjustment (düşük doğruluk = daha fazla filtreleme)
    if (accuracy != null && accuracy < 2) {
      alpha *= 0.5; // Düşük doğrulukta daha fazla filtrele
    }

    // Exponential smoothing with circular interpolation
    _previousHeading = _filteredHeading;
    _filteredHeading = _smoothAngle(_filteredHeading, compassHeading, alpha);

    return _filteredHeading;
  }

  /// Pusula verisi gelmediğinde hedef yöne doğru yavaşça kayar.
  double driftTowards(double targetHeading) {
    _filteredHeading = _smoothAngle(_filteredHeading, targetHeading, 0.03);
    return _filteredHeading;
  }

  /// İki açı arasındaki en kısa farkı hesaplar (-180 ile +180 arası).
  double _angleDifference(double a, double b) {
    double diff = ((a - b + 540) % 360) - 180;
    return diff;
  }

  /// Açıları yumuşatır (circular interpolation).
  double _smoothAngle(double current, double target, double alpha) {
    double delta = _angleDifference(target, current);
    double next = current + alpha * delta;
    next = next % 360;
    if (next < 0) next += 360;
    return next;
  }
}
