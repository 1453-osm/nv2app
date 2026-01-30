import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/prayer_times_model.dart';
import '../utils/app_logger.dart';

class PrayerTimesService {
  static const String _baseUrl = 'https://storage.googleapis.com/namazvaktimdepo';
  
  PrayerTimesResponse? _cachedData;
  int? _cachedCityId;
  int? _cachedYear;

  /// Belirli bir şehir için namaz vakitlerini indirir
  Future<PrayerTimesResponse> getPrayerTimes(int cityId, int year) async {
    // Önce cache'den kontrol et
    if (_cachedData != null && _cachedCityId == cityId && _cachedYear == year) {
      return _cachedData!;
    }

    // Local dosyadan kontrol et
    final localData = await _loadFromLocal(cityId, year);
    if (localData != null) {
      _cachedData = localData;
      _cachedCityId = cityId;
      _cachedYear = year;
      return localData;
    }

    // API'den indir
    try {
      final url = '$_baseUrl/prayer-times-$cityId-$year.json';
      AppLogger.network('GET', url);

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Bağlantı zaman aşımına uğradı'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final prayerTimesResponse = PrayerTimesResponse.fromJson(jsonData);
        
        // Cache'e kaydet
        _cachedData = prayerTimesResponse;
        _cachedCityId = cityId;
        _cachedYear = year;
        
        // Local dosyaya kaydet
        await _saveToLocal(prayerTimesResponse, cityId, year);

        AppLogger.success('Namaz vakitleri indirildi: cityId=$cityId, year=$year', tag: 'PrayerTimes');
        return prayerTimesResponse;
      } else {
        throw Exception('Namaz vakitleri indirilemedi. HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Namaz vakitleri indirilirken hata oluştu: $e');
    }
  }

  /// Bugünün namaz vakitlerini döndürür
  Future<PrayerTime?> getTodayPrayerTimes(int cityId, int year) async {
    try {
      final prayerTimesResponse = await getPrayerTimes(cityId, year);
      final today = DateTime.now();
      
      // Debug için ilk birkaç tarihi logla
      if (prayerTimesResponse.prayerTimes.isNotEmpty) {
        AppLogger.debug('İlk tarih formatları:', tag: 'PrayerTimes');
        for (int i = 0; i < 3 && i < prayerTimesResponse.prayerTimes.length; i++) {
          final prayer = prayerTimesResponse.prayerTimes[i];
          AppLogger.debug('  $i: gregorianDateShort=${prayer.gregorianDateShort}, gregorianDateShortIso8601=${prayer.gregorianDateShortIso8601}', tag: 'PrayerTimes');
        }
        AppLogger.debug('Bugünün tarihi: ${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}', tag: 'PrayerTimes');
      }
      
      return prayerTimesResponse.prayerTimes.firstWhere(
        (prayer) {
          // İlk olarak gregorianDateShort ile kontrol et (DD.MM.YYYY formatında)
          final todayShort = '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
          if (prayer.gregorianDateShort == todayShort) {
            return true;
          }
          
          // İkinci olarak gregorianDateShortIso8601 ile kontrol et
          if (prayer.gregorianDateShortIso8601.isNotEmpty) {
            final prayerDate = DateTime.tryParse(prayer.gregorianDateShortIso8601);
            if (prayerDate != null) {
              return prayerDate.year == today.year &&
                     prayerDate.month == today.month &&
                     prayerDate.day == today.day;
            }
          }
          
          return false;
        },
        orElse: () => throw Exception('Bugünün namaz vakitleri bulunamadı'),
      );
    } catch (e) {
      AppLogger.error('Bugünün namaz vakitleri alınamadı', tag: 'PrayerTimes', error: e);
      return null;
    }
  }

  /// Belirli bir tarihin namaz vakitlerini döndürür
  Future<PrayerTime?> getPrayerTimesByDate(int cityId, int year, DateTime date) async {
    try {
      final prayerTimesResponse = await getPrayerTimes(cityId, year);
      final targetDate = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      
      return prayerTimesResponse.prayerTimes.firstWhere(
        (prayer) => prayer.gregorianDateShort == targetDate,
        orElse: () => throw Exception('$targetDate tarihinin namaz vakitleri bulunamadı'),
      );
    } catch (e) {
      final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      AppLogger.error('$dateStr tarihinin namaz vakitleri alınamadı', tag: 'PrayerTimes', error: e);
      return null;
    }
  }

  /// Local dosyaya kaydet
  Future<void> _saveToLocal(PrayerTimesResponse data, int cityId, int year) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_${cityId}_$year.json');
      
      final jsonData = json.encode(data.toJson());
      await file.writeAsString(jsonData);
      AppLogger.debug('Namaz vakitleri local dosyaya kaydedildi: cityId=$cityId', tag: 'PrayerTimes');
    } catch (e) {
      AppLogger.error('Local dosyaya kaydetme hatası', tag: 'PrayerTimes', error: e);
    }
  }

  /// Local dosyadan yükle
  Future<PrayerTimesResponse?> _loadFromLocal(int cityId, int year) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_${cityId}_$year.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonData = json.decode(jsonString);
        final prayerTimesResponse = PrayerTimesResponse.fromJson(jsonData);
        AppLogger.debug('Namaz vakitleri local cache\'den yüklendi: cityId=$cityId', tag: 'PrayerTimes');
        return prayerTimesResponse;
      }
    } catch (e) {
      AppLogger.error('Local dosyadan yükleme hatası', tag: 'PrayerTimes', error: e);
    }
    return null;
  }

  /// Cache'i temizle
  void clearCache() {
    _cachedData = null;
    _cachedCityId = null;
    _cachedYear = null;
  }

  /// Local dosyaları temizle
  Future<void> clearLocalFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      for (var file in files) {
        if (file is File && file.path.contains('prayer_times_')) {
          await file.delete();
        }
      }
      AppLogger.debug('Local cache dosyaları temizlendi', tag: 'PrayerTimes');
    } catch (e) {
      AppLogger.error('Local dosyaları temizleme hatası', tag: 'PrayerTimes', error: e);
    }
  }

  /// Belirli bir şehir ve yıl için local dosyayı temizler
  Future<void> clearLocalFile(int cityId, int year) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_${cityId}_$year.json');
      if (await file.exists()) {
        await file.delete();
        AppLogger.debug('Local cache dosyası silindi: cityId=$cityId', tag: 'PrayerTimes');
      }
    } catch (e) {
      AppLogger.error('Local dosya silme hatası', tag: 'PrayerTimes', error: e);
    }
  }

  /// Dosya boyutunu kontrol et
  Future<int> getLocalFileSize(int cityId, int year) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_${cityId}_$year.json');
      
      if (await file.exists()) {
        final size = await file.length();
        return size;
      }
    } catch (e) {
      AppLogger.warning('Dosya boyutu kontrol edilemedi', tag: 'PrayerTimes');
    }
    return 0;
  }

  /// İnternet bağlantısını kontrol et
  Future<bool> checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Belirli bir şehir ve yıl için local dosya var mı?
  Future<bool> hasLocalFile(int cityId, int year) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_times_${cityId}_$year.json');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Sunucuda belirli bir şehir ve yıl için veri var mı kontrol eder (HEAD request)
  /// Returns: true = veri mevcut, false = veri yok veya hata
  Future<bool> checkRemoteDataAvailable(int cityId, int year) async {
    try {
      final url = '$_baseUrl/prayer-times-$cityId-$year.json';
      AppLogger.network('HEAD', url);

      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Bağlantı zaman aşımına uğradı'),
      );

      final isAvailable = response.statusCode == 200;
      AppLogger.debug(
        'Gelecek yıl verisi kontrolü: cityId=$cityId, year=$year, available=$isAvailable',
        tag: 'PrayerTimes',
      );
      return isAvailable;
    } catch (e) {
      AppLogger.warning(
        'Gelecek yıl verisi kontrol hatası: cityId=$cityId, year=$year',
        tag: 'PrayerTimes',
      );
      return false;
    }
  }

  /// Gelecek yıl verisini ön yükler (arka planda indirir)
  /// Returns: true = başarıyla indirildi, false = indirilemedi
  Future<bool> prefetchNextYearData(int cityId, int nextYear) async {
    try {
      // Önce local dosya var mı kontrol et
      if (await hasLocalFile(cityId, nextYear)) {
        AppLogger.debug(
          'Gelecek yıl verisi zaten mevcut: cityId=$cityId, year=$nextYear',
          tag: 'PrayerTimes',
        );
        return true;
      }

      // Sunucuda veri var mı kontrol et
      final isAvailable = await checkRemoteDataAvailable(cityId, nextYear);
      if (!isAvailable) {
        AppLogger.debug(
          'Gelecek yıl verisi sunucuda henüz mevcut değil: cityId=$cityId, year=$nextYear',
          tag: 'PrayerTimes',
        );
        return false;
      }

      // Veriyi indir
      await getPrayerTimes(cityId, nextYear);
      AppLogger.success(
        'Gelecek yıl verisi ön yüklendi: cityId=$cityId, year=$nextYear',
        tag: 'PrayerTimes',
      );
      return true;
    } catch (e) {
      AppLogger.error(
        'Gelecek yıl verisi ön yükleme hatası',
        tag: 'PrayerTimes',
        error: e,
      );
      return false;
    }
  }
} 