import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

enum QiblaStatus {
  loading,
  ready,
  error,
  needsCalibration,
}

class QiblaViewModel extends ChangeNotifier {
  bool _isExpanded = false;
  QiblaStatus _status = QiblaStatus.loading;
  double _qiblaDirection = 0.0;
  double _currentDirection = 0.0;
  double _distanceToKaaba = 0.0;
  String _errorMessage = '';
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _compassTimer;
  bool _isUsingGPS = false;
  
  // Stabilite ve kalibrasyon takibi
  DateTime _lastValidHeadingAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _unreliableSinceAt;
  DateTime? _lastReliableAt;
  static const Duration _unreliableGrace = Duration(seconds: 2);
  static const Duration _reliableRecovery = Duration(seconds: 1);
  
  // Kabe koordinatları
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;
  
  bool get isExpanded => _isExpanded;
  QiblaStatus get status => _status;
  double get qiblaDirection => _qiblaDirection;
  double get currentDirection => _currentDirection;
  double get distanceToKaaba => _distanceToKaaba;
  String get errorMessage => _errorMessage;
  bool get isUsingGPS => _isUsingGPS;
  
  bool get isPointingToQibla {
    if (_status != QiblaStatus.ready) return false;
    // Son geçerli başlık verisi taze olmalı
    final bool headingIsFresh = DateTime.now().difference(_lastValidHeadingAt) < const Duration(seconds: 2);
    if (!headingIsFresh) return false;
    final difference = (_currentDirection - _qiblaDirection).abs();
    return difference <= 5.0 || difference >= 355.0; // 5 derece tolerans
  }
  
  void toggleExpansion() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }
  
  void closeQiblaBar() {
    _isExpanded = false;
    notifyListeners();
  }
  
  Future<void> calculateQiblaDirection() async {
    try {
      _status = QiblaStatus.loading;
      notifyListeners();
      
      // Sadece gerçek zamanlı GPS koordinatlarını kullan
      final coordinates = await _getCurrentLocationCoordinates();
      if (coordinates == null) {
        _status = QiblaStatus.error;
        _isUsingGPS = false;
        _errorMessage = 'GPS konumu alınamadı';
        notifyListeners();
        return;
      }
      _isUsingGPS = true;
      
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
      
      // Kabe'ye olan mesafe hesaplama (km)
      _distanceToKaaba = _calculateDistance(
        coordinates['latitude']!, 
        coordinates['longitude']!, 
        kaabaLatitude, 
        kaabaLongitude
      );
      
      _status = QiblaStatus.ready;
      _startCompassSimulation();
      
    } catch (e) {
      _status = QiblaStatus.error;
      _isUsingGPS = false;
      _errorMessage = 'Kıble yönü hesaplanamadı';
    }
    
    notifyListeners();
  }
  
  void _startCompassSimulation() {
    _compassSubscription?.cancel();
    _compassTimer?.cancel();
    
    // Gerçek pusula sensörünü kullan
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final DateTime now = DateTime.now();
      final bool hasHeading = event.heading != null;
      final bool isReliable = _isCompassEventReliable(event);
      
      // Yumuşatma filtresi ile açı güncelle
      if (hasHeading) {
        _currentDirection = _smoothAngleDegrees(_currentDirection, event.heading!, 0.15);
        if (_currentDirection < 0) _currentDirection += 360;
        if (_currentDirection >= 360) _currentDirection -= 360;
        _lastValidHeadingAt = now;
        _lastReliableAt = isReliable ? now : _lastReliableAt;
        notifyListeners();
      }
      
      // Kalibrasyon gereksinimi tespiti (histerezis ile)
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
    });
    
    // Yardımcı stabilizasyon: Bir süre geçerli başlık gelmezse kıble yönüne doğru yumuşak yaklaşım
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
  
  void refreshCompass() async {
    _status = QiblaStatus.loading;
    notifyListeners();
    
    try {
      // Sadece GPS koordinatlarını kullan
      final coordinates = await _getCurrentLocationCoordinates();
      if (coordinates != null) {
        _isUsingGPS = true;
        // Koordinatlar ile kıble yönünü hesapla
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
        
        // Kabe'ye olan mesafe hesaplama (km)
        _distanceToKaaba = _calculateDistance(
          coordinates['latitude']!, 
          coordinates['longitude']!, 
          kaabaLatitude, 
          kaabaLongitude
        );
        
        _status = QiblaStatus.ready;
        _startCompassSimulation();
      } else {
        _status = QiblaStatus.error;
        _isUsingGPS = false;
        _errorMessage = 'GPS konumu alınamadı';
      }
    } catch (e) {
      _status = QiblaStatus.error;
      _isUsingGPS = false;
      _errorMessage = 'Konum yenilenemedi';
    }
    
    notifyListeners();
  }

  /// Cihazın konum servisleri ayarlarını açar
  Future<void> openLocationSettings() async {
    try {
      final bool opened = await Geolocator.openLocationSettings();
      if (!opened) {
        // Bazı cihazlarda geri dönen değer güvenilir olmayabilir; app ayarlarını da dene
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
    }
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  double _radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Gerçek zamanlı GPS koordinatlarını alır
  Future<Map<String, double>?> _getCurrentLocationCoordinates() async {
    try {
      // Konum izinlerini kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Mevcut konumu al
      final LocationSettings locationSettings = _buildLocationSettings();
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: _isAndroid,
        );
      }

      position ??= await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: _isAndroid,
      );

      if (position == null) {
        return null;
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('GPS koordinat alma hatası: $e');
      return null;
    }
  }

  LocationSettings _buildLocationSettings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        timeLimit: Duration(seconds: 12),
      );
    }

    if (_isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        timeLimit: Duration(seconds: 12),
        pauseLocationUpdatesAutomatically: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 12),
    );
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Şehir tabanlı koordinat kullanımı kaldırıldı
  
  // -- Yardımcı metotlar --
  bool _isCompassEventReliable(CompassEvent event) {
    // Android: 0=unreliable, 1=low, 2=medium, 3=high
    final num? accuracy = event.accuracy;
    final bool hasHeading = event.heading != null;
    if (!hasHeading) return false;
    if (accuracy == null) return true; // iOS veya desteklenmeyen durumda sadece heading'e göre karar ver
    return accuracy >= 2; // medium ve üzeri güvenilir kabul edilir
  }

  double _smoothAngleDegrees(double currentDeg, double targetDeg, double alpha) {
    // Dairesel fark hesapla: [-180, 180)
    double delta = ((targetDeg - currentDeg + 540) % 360) - 180;
    double next = currentDeg + alpha * delta;
    next %= 360;
    if (next < 0) next += 360;
    return next;
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _compassTimer?.cancel();
    super.dispose();
  }
}