import 'dart:math' as math;

/// World Magnetic Model 2025 (WMM2025) tabanlı manyetik sapma hesaplama servisi.
///
/// Bu servis, verilen koordinatlar için manyetik sapma (declination) değerini
/// hesaplar. Manyetik sapma, manyetik kuzey ile coğrafi kuzey arasındaki açıdır.
///
/// Referans: NOAA National Centers for Environmental Information
/// https://www.ncei.noaa.gov/products/world-magnetic-model
class MagneticDeclinationService {
  MagneticDeclinationService._();
  static final MagneticDeclinationService instance = MagneticDeclinationService._();

  // WGS84 Ellipsoid parametreleri
  static const double _a = 6378137.0; // Semi-major axis (metre)
  static const double _b = 6356752.314245; // Semi-minor axis (metre)

  // WMM2025 Epoch
  static const double _epoch = 2025.0;

  // WMM2025 Ana Gauss katsayıları (degree 1-6, basitleştirilmiş model)
  // Tam model 12 dereceye kadar gider, ancak pratik kullanım için
  // ilk 6 derece yeterli doğruluk sağlar (~0.5° hata payı)
  static const List<List<double>> _gnm = [
    // n=1
    [-29351.8, -1410.8],
    // n=2
    [-2556.6, 2951.1, 1649.3],
    // n=3
    [1361.0, -2404.1, 1243.8, 453.4],
    // n=4
    [895.0, 799.5, 55.8, -281.1, 12.3],
    // n=5
    [-233.2, 357.6, 200.3, -141.5, -151.2, -14.8],
    // n=6
    [72.3, 68.2, 76.2, -141.4, -22.9, 14.0, -56.1],
  ];

  static const List<List<double>> _hnm = [
    // n=1
    [0.0, 4545.4],
    // n=2
    [0.0, -3133.6, -815.1],
    // n=3
    [0.0, -56.5, 237.6, -549.5],
    // n=4
    [0.0, 283.3, -242.6, 107.0, -304.8],
    // n=5
    [0.0, 46.9, 141.3, -121.6, -77.5, 97.9],
    // n=6
    [0.0, -104.3, -24.5, 10.0, -17.4, 64.6, -63.5],
  ];

  // Secular variation katsayıları (yıllık değişim, nT/yıl)
  static const List<List<double>> _gtnm = [
    [5.7, 7.4],
    [-11.0, -7.0, -30.2],
    [-2.1, -5.9, 2.5, -12.0],
    [-1.2, -1.4, 0.2, 1.3, 0.7],
    [0.1, -0.3, 0.3, 0.7, -0.5, 0.2],
    [-0.1, 0.1, -0.6, 0.3, -0.4, 0.4, 0.0],
  ];

  static const List<List<double>> _htnm = [
    [0.0, -25.9],
    [0.0, -32.5, -23.6],
    [0.0, -0.6, -1.0, 6.5],
    [0.0, 0.0, -0.6, 2.3, -7.0],
    [0.0, 0.6, 1.3, 1.6, -0.2, -0.9],
    [0.0, -0.5, -0.4, 0.5, 1.2, -1.0, 0.1],
  ];

  /// Verilen koordinatlar ve tarih için manyetik sapma hesaplar.
  ///
  /// [latitude] Enlem (derece, -90 ile 90 arası)
  /// [longitude] Boylam (derece, -180 ile 180 arası)
  /// [altitudeKm] Deniz seviyesinden yükseklik (km)
  /// [date] Hesaplama tarihi (varsayılan: şu an)
  ///
  /// Dönen değer: Manyetik sapma (derece)
  /// Pozitif değer = Doğu sapması (manyetik kuzey coğrafi kuzeyin doğusunda)
  /// Negatif değer = Batı sapması (manyetik kuzey coğrafi kuzeyin batısında)
  double calculate({
    required double latitude,
    required double longitude,
    double altitudeKm = 0.0,
    DateTime? date,
  }) {
    final DateTime now = date ?? DateTime.now();
    final double decimalYear = _toDecimalYear(now);

    // Yıl farkı (epoch'tan itibaren)
    final double dt = decimalYear - _epoch;

    // Koordinatları radyana çevir
    final double latRad = latitude * math.pi / 180.0;
    final double lonRad = longitude * math.pi / 180.0;

    // Geocentric koordinatlara dönüştür
    final double sinLat = math.sin(latRad);
    final double cosLat = math.cos(latRad);

    // Geocentric latitude ve radius hesapla
    final double a2 = _a * _a;
    final double b2 = _b * _b;
    final double e2 = (a2 - b2) / a2;

    final double altM = altitudeKm * 1000.0;
    final double rc = _a / math.sqrt(1.0 - e2 * sinLat * sinLat);
    final double prc = (rc + altM) * cosLat;
    final double zrc = (rc * (1.0 - e2) + altM) * sinLat;
    final double r = math.sqrt(prc * prc + zrc * zrc);

    // Geocentric latitude
    final double latGc = math.asin(zrc / r);
    final double sinLatGc = math.sin(latGc);
    final double cosLatGc = math.cos(latGc);

    // Referans yarıçapı (Earth's mean radius)
    const double rRef = 6371200.0;
    final double ratio = rRef / r;

    // Legendre fonksiyonları ve türevleri için değişkenler
    final List<List<double>> p = List.generate(7, (_) => List.filled(7, 0.0));
    final List<List<double>> dp = List.generate(7, (_) => List.filled(7, 0.0));

    // P(0,0) ve P(1,0), P(1,1) başlangıç değerleri
    p[0][0] = 1.0;
    p[1][0] = sinLatGc;
    p[1][1] = cosLatGc;
    dp[0][0] = 0.0;
    dp[1][0] = cosLatGc;
    dp[1][1] = -sinLatGc;

    // Legendre polinomlarını hesapla (rekürif)
    for (int n = 2; n <= 6; n++) {
      for (int m = 0; m <= n; m++) {
        if (m == n) {
          p[n][m] = cosLatGc * p[n - 1][m - 1];
          dp[n][m] = cosLatGc * dp[n - 1][m - 1] - sinLatGc * p[n - 1][m - 1];
        } else if (m == n - 1) {
          p[n][m] = sinLatGc * p[n - 1][m];
          dp[n][m] = sinLatGc * dp[n - 1][m] + cosLatGc * p[n - 1][m];
        } else {
          final double k1 = (2 * n - 1) / (n - m).toDouble();
          final double k2 = (n + m - 1) / (n - m).toDouble();
          p[n][m] = k1 * sinLatGc * p[n - 1][m] - k2 * p[n - 2][m];
          dp[n][m] = k1 * (sinLatGc * dp[n - 1][m] + cosLatGc * p[n - 1][m]) -
              k2 * dp[n - 2][m];
        }
      }
    }

    // Schmidt normalizasyon faktörleri ve manyetik alan bileşenlerini hesapla
    double bx = 0.0; // Kuzey bileşeni
    double by = 0.0; // Doğu bileşeni

    double rn = ratio * ratio;

    for (int n = 1; n <= 6; n++) {
      rn *= ratio;
      final int nIdx = n - 1;

      for (int m = 0; m <= n; m++) {
        // Zamanla güncellenen katsayılar
        final double gnm = _gnm[nIdx][m] + _gtnm[nIdx][m] * dt;
        final double hnm = _hnm[nIdx][m] + _htnm[nIdx][m] * dt;

        // Schmidt quasi-normalizasyon
        double schmidtFactor = 1.0;
        if (m > 0) {
          double factorialRatio = 1.0;
          for (int i = n - m + 1; i <= n + m; i++) {
            factorialRatio *= i;
          }
          schmidtFactor = math.sqrt(2.0 / factorialRatio);
        }

        final double pnm = p[n][m] * schmidtFactor;
        final double dpnm = dp[n][m] * schmidtFactor;

        final double cosMLon = math.cos(m * lonRad);
        final double sinMLon = math.sin(m * lonRad);

        // Manyetik alan bileşenleri
        bx += rn * (gnm * cosMLon + hnm * sinMLon) * dpnm;
        by += rn * m * (gnm * sinMLon - hnm * cosMLon) * pnm;
      }
    }

    // Doğu bileşenini cosLatGc ile düzelt
    if (cosLatGc.abs() > 1e-10) {
      by /= cosLatGc;
    }

    // Manyetik sapma (declination) hesapla
    final double declination = math.atan2(by, bx) * 180.0 / math.pi;

    return declination;
  }

  /// DateTime'ı ondalık yıla çevirir.
  double _toDecimalYear(DateTime date) {
    final int year = date.year;
    final startOfYear = DateTime(year);
    final startOfNextYear = DateTime(year + 1);
    final int daysInYear =
        startOfNextYear.difference(startOfYear).inDays;
    final int dayOfYear = date.difference(startOfYear).inDays;
    return year + dayOfYear / daysInYear;
  }

  /// Manyetik yönü coğrafi (true) yöne çevirir.
  ///
  /// [magneticHeading] Pusulanın okuduğu manyetik yön (derece)
  /// [declination] Manyetik sapma (derece)
  double magneticToTrue(double magneticHeading, double declination) {
    return (magneticHeading + declination + 360) % 360;
  }

  /// Coğrafi (true) yönü manyetik yöne çevirir.
  ///
  /// Bu metod, hesaplanan kıble yönünü (true north'a göre)
  /// pusula için manyetik yöne çevirmek için kullanılır.
  ///
  /// [trueHeading] Coğrafi kuzey'e göre yön (derece)
  /// [declination] Manyetik sapma (derece)
  double trueToMagnetic(double trueHeading, double declination) {
    return (trueHeading - declination + 360) % 360;
  }
}
