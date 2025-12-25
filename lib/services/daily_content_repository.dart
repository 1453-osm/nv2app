import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/daily_content.dart';
import '../utils/app_logger.dart';

class DailyContentRepository {
  static const String collectionName = 'daily_contents';
  Future<SharedPreferences>? _prefsFuture;
  Future<SharedPreferences> _prefs() =>
      _prefsFuture ??= SharedPreferences.getInstance();

  // Adlandırılmış Firestore veritabanı: 'daily'
  FirebaseFirestore get _db {
    // Web platformunda instanceFor ile databaseId çalışmıyor, default instance kullan
    if (kIsWeb) {
      return FirebaseFirestore.instance;
    }
    // Mobil platformlarda named database kullan
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'daily',
    );
  }

  Future<String> _todayKey() async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    return dateOnly.toIso8601String().substring(0, 10); // yyyy-MM-dd
  }

  String _dayMonthKey(DateTime date) {
    return '${date.day}_${date.month}';
  }

  String _todayDocId() {
    final now = DateTime.now();
    return _dayMonthKey(now);
  }


  Future<DailyContent> getTodayContent() async {
    final key = await _todayKey();
    final prefs = await _prefs();
    final docId = _todayDocId();
    final cached = prefs.getString('daily_content_$key');
    if (cached != null && cached.isNotEmpty) {
      final map = jsonDecode(cached) as Map<String, dynamic>;
      return DailyContent.fromFirestore(map);
    }

    // Firestore'dan çek
    final doc = await _db
        .collection(collectionName)
        .doc(docId)
        .get();

    if (!doc.exists) {
      throw Exception('Bugün için içerik bulunamadı ($key)');
    }

    final data = doc.data() as Map<String, dynamic>;
    final content = DailyContent.fromFirestore(data);

    // Cache yaz
    await prefs.setString('daily_content_$key', jsonEncode(content.toMap()));
    return content;
  }

  /// Günü ayet + hadis olarak birlikte döndürmek için direkt okuma
  /// database: daily, collections: ayetler, hadisler, document: {gün_ay}
  Future<(DailyContent?, DailyContent?)> getTodayPair() async {
    final todayKey = await _todayKey();
    final prefs = await _prefs();
    final todayDocId = _todayDocId();

    // Cache kontrol
    DailyContent? cachedAyet;
    DailyContent? cachedHadis;
    final cAyet = prefs.getString('daily_content_ayet_$todayKey');
    final cHadis = prefs.getString('daily_content_hadis_$todayKey');
    if (cAyet != null) {
      cachedAyet = DailyContent.fromFirestore(jsonDecode(cAyet) as Map<String, dynamic>);
    }
    if (cHadis != null) {
      cachedHadis = DailyContent.fromFirestore(jsonDecode(cHadis) as Map<String, dynamic>);
    }
    if (cachedAyet != null || cachedHadis != null) {
      return (cachedAyet, cachedHadis);
    }

    // Firestore'dan direkt okuma: database 'daily', collections 'ayetler' ve 'hadisler'
    DailyContent? ayet;
    DailyContent? hadis;

    try {
      final ayetDoc = await _db.collection('ayetler').doc(todayDocId).get();
      if (ayetDoc.exists) {
        final data = ayetDoc.data() as Map<String, dynamic>;
        // Doküman ID'sini data'ya ekle
        data['id'] = todayDocId;
        ayet = DailyContent.fromFirestore(data);
        await prefs.setString('daily_content_ayet_$todayKey', jsonEncode(ayet.toMap()));
        AppLogger.success('Ayet başarıyla yüklendi: $todayDocId', tag: 'DailyContent');
      } else {
        AppLogger.warning('Ayet dokümanı bulunamadı: $todayDocId', tag: 'DailyContent');
      }
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        AppLogger.error('Ayet yüklenirken Firebase hatası', tag: 'DailyContent', error: '${e.code} - ${e.message}');
      } else {
        AppLogger.error('Ayet yüklenirken hata', tag: 'DailyContent', error: e, stackTrace: stackTrace);
      }
    }

    try {
      final hadisDoc = await _db.collection('hadisler').doc(todayDocId).get();
      if (hadisDoc.exists) {
        final data = hadisDoc.data() as Map<String, dynamic>;
        // Doküman ID'sini data'ya ekle
        data['id'] = todayDocId;
        hadis = DailyContent.fromFirestore(data);
        await prefs.setString('daily_content_hadis_$todayKey', jsonEncode(hadis.toMap()));
        AppLogger.success('Hadis başarıyla yüklendi: $todayDocId', tag: 'DailyContent');
      } else {
        AppLogger.warning('Hadis dokümanı bulunamadı: $todayDocId', tag: 'DailyContent');
      }
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        AppLogger.error('Hadis yüklenirken Firebase hatası', tag: 'DailyContent', error: '${e.code} - ${e.message}');
      } else {
        AppLogger.error('Hadis yüklenirken hata', tag: 'DailyContent', error: e, stackTrace: stackTrace);
      }
    }

    return (ayet, hadis);
  }

  /// Günlük rastgele seçim: Gün içinde aynı içerik kalır, yeni günde yeniden rastgele çekilir.
  /// İnternet yoksa en son başarılı cache (latest_*) gösterilir.
  Future<(DailyContent?, DailyContent?)> getRandomPairDailyCached() async {
    final todayKey = await _todayKey();
    final prefs = await _prefs();

    // 1) Günlük cache varsa direkt dön
    final cAyet = prefs.getString('daily_content_ayet_$todayKey');
    final cHadis = prefs.getString('daily_content_hadis_$todayKey');
    DailyContent? ayet;
    DailyContent? hadis;
    if (cAyet != null) {
      ayet = DailyContent.fromFirestore(jsonDecode(cAyet) as Map<String, dynamic>);
    }
    if (cHadis != null) {
      hadis = DailyContent.fromFirestore(jsonDecode(cHadis) as Map<String, dynamic>);
    }
    if (ayet != null || hadis != null) {
      return (ayet, hadis);
    }

    // 2) Günlük dokümanları kullanarak oku
    try {
      final pair = await getTodayPair();
      ayet = pair.$1;
      hadis = pair.$2;
      if (ayet != null) {
        await prefs.setString('latest_daily_content_ayet', jsonEncode(ayet.toMap()));
      }
      if (hadis != null) {
        await prefs.setString('latest_daily_content_hadis', jsonEncode(hadis.toMap()));
      }
      if (ayet != null || hadis != null) {
        return (ayet, hadis);
      }
    } catch (_) {
      // yok say, sonraki adıma geç
    }

    // 3) Offline: en son başarılı cache'i kullan
    final latestAyet = prefs.getString('latest_daily_content_ayet');
    final latestHadis = prefs.getString('latest_daily_content_hadis');
    if (latestAyet != null) {
      ayet = DailyContent.fromFirestore(jsonDecode(latestAyet) as Map<String, dynamic>);
    }
    if (latestHadis != null) {
      hadis = DailyContent.fromFirestore(jsonDecode(latestHadis) as Map<String, dynamic>);
    }
    return (ayet, hadis);
  }

  Future<void> clearOldCaches() async {
    final prefs = await _prefs();
    final keys = prefs.getKeys();
    final today = await _todayKey();
    for (final k in keys) {
      // latest_* anahtarlarını koru
      if (k.startsWith('latest_daily_content_')) continue;
      if (k.startsWith('daily_content_')) {
        // Sadece bugünkü ayet/hadis cache'lerini tut
        if (!(k.endsWith('_$today'))) {
          await prefs.remove(k);
        }
      }
    }
  }
}


