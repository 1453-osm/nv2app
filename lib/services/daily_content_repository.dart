import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_content.dart';

class DailyContentRepository {
  static const String collectionName = 'daily_contents';
  
  // Adlandırılmış Firestore veritabanı: 'daily'
  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'daily',
      );

  Future<String> _todayKey() async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    return dateOnly.toIso8601String().substring(0, 10); // yyyy-MM-dd
  }

  int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1; // 1..366
  }

  Future<DailyContent> getTodayContent() async {
    final key = await _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('daily_content_$key');
    if (cached != null && cached.isNotEmpty) {
      final map = jsonDecode(cached) as Map<String, dynamic>;
      return DailyContent.fromFirestore(map);
    }

    // Firestore'dan çek
    final doc = await _db
        .collection(collectionName)
        .doc(key)
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

  /// Günü ayet + hadis olarak birlikte döndürmek için esnek okuma
  /// Öncelik: daily_contents/{yyyy-MM-dd} dokümanı içinde
  /// { ayet: {...}, hadis: {...} } alanları varsa onu kullanır.
  /// Aksi halde fallback: daily/ayetler/{dayOfYear} ve daily/hadisler/{dayOfYear}
  Future<(DailyContent?, DailyContent?)> getTodayPair() async {
    final todayKey = await _todayKey();
    final prefs = await SharedPreferences.getInstance();
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

    // 1) Tek doküman yaklaşımı
    try {
      final doc = await _db
          .collection(collectionName)
          .doc(todayKey)
          .get();
      if (doc.exists) {
        final map = doc.data() as Map<String, dynamic>;
        DailyContent? ayet;
        DailyContent? hadis;
        if (map['ayet'] is Map<String, dynamic>) {
          ayet = DailyContent.fromFirestore((map['ayet'] as Map<String, dynamic>));
          await prefs.setString('daily_content_ayet_$todayKey', jsonEncode(ayet.toMap()));
        }
        if (map['hadis'] is Map<String, dynamic>) {
          hadis = DailyContent.fromFirestore((map['hadis'] as Map<String, dynamic>));
          await prefs.setString('daily_content_hadis_$todayKey', jsonEncode(hadis.toMap()));
        }
        if (ayet != null || hadis != null) {
          return (ayet, hadis);
        }
      }
    } catch (_) {
      // yok say, fallback'e geç
    }

    // 2) Fallback: daily/ayetler/{day}, daily/hadisler/{day}
    try {
      final today = DateTime.now();
      final day = _dayOfYear(today).toString();
      final ayetDoc = await _db
          .collection('daily')
          .doc('ayetler')
          .collection('ayetler')
          .doc(day)
          .get();
      final hadisDoc = await _db
          .collection('daily')
          .doc('hadisler')
          .collection('hadisler')
          .doc(day)
          .get();

      DailyContent? ayet;
      DailyContent? hadis;
      if (ayetDoc.exists) {
        ayet = DailyContent.fromFirestore(ayetDoc.data() as Map<String, dynamic>);
        await prefs.setString('daily_content_ayet_$todayKey', jsonEncode(ayet.toMap()));
      }
      if (hadisDoc.exists) {
        hadis = DailyContent.fromFirestore(hadisDoc.data() as Map<String, dynamic>);
        await prefs.setString('daily_content_hadis_$todayKey', jsonEncode(hadis.toMap()));
      }
      if (ayet != null || hadis != null) {
        return (ayet, hadis);
      }
    } catch (_) {
      // yoksay
    }

    return (null, null);
  }

  /// Günlük rastgele seçim: Gün içinde aynı içerik kalır, yeni günde yeniden rastgele çekilir.
  /// İnternet yoksa en son başarılı cache (latest_*) gösterilir.
  Future<(DailyContent?, DailyContent?)> getRandomPairDailyCached() async {
    final todayKey = await _todayKey();
    final prefs = await SharedPreferences.getInstance();

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

    // 2) Rastgele ayet/hadis çek
    try {
      final rng = Random();

      // Olası koleksiyon yollarını sırayla dene (root ve 'daily/...' altında)
      final List<CollectionReference<Map<String, dynamic>>> ayetCollections = [
        _db.collection('ayetler'),
        _db.collection('daily').doc('ayetler').collection('ayetler'),
      ];
      final List<CollectionReference<Map<String, dynamic>>> hadisCollections = [
        _db.collection('hadisler'),
        _db.collection('daily').doc('hadisler').collection('hadisler'),
      ];

      Future<DailyContent?> pickRandomById(List<CollectionReference<Map<String, dynamic>>> candidates) async {
        for (final coll in candidates) {
          // Maksimum id'yi bul
          final maxSnap = await coll.orderBy('id', descending: true).limit(1).get();
          if (maxSnap.docs.isEmpty) continue;
          final int maxId = (maxSnap.docs.first.data()['id'] ?? 0) as int;
          if (maxId <= 0) continue;

          for (int i = 0; i < 5; i++) {
            final int candidate = rng.nextInt(maxId) + 1; // 1..maxId
            // 1) Doğrudan eşit id
            final eq = await coll.where('id', isEqualTo: candidate).limit(1).get();
            if (eq.docs.isNotEmpty) {
              return DailyContent.fromFirestore(eq.docs.first.data());
            }
            // 2) Sonraki mevcut id
            final gt = await coll.where('id', isGreaterThan: candidate).orderBy('id').limit(1).get();
            if (gt.docs.isNotEmpty) {
              return DailyContent.fromFirestore(gt.docs.first.data());
            }
            // 3) Baştan sar
            final first = await coll.orderBy('id').limit(1).get();
            if (first.docs.isNotEmpty) {
              return DailyContent.fromFirestore(first.docs.first.data());
            }
          }
        }
        return null;
      }

      ayet = await pickRandomById(ayetCollections);
      hadis = await pickRandomById(hadisCollections);

      // Birini bulamazsak da kalanla devam
      if (ayet != null) {
        await prefs.setString('daily_content_ayet_$todayKey', jsonEncode(ayet.toMap()));
        await prefs.setString('latest_daily_content_ayet', jsonEncode(ayet.toMap()));
      }
      if (hadis != null) {
        await prefs.setString('daily_content_hadis_$todayKey', jsonEncode(hadis.toMap()));
        await prefs.setString('latest_daily_content_hadis', jsonEncode(hadis.toMap()));
      }
      if (ayet != null || hadis != null) {
        return (ayet, hadis);
      }
    } catch (_) {
      // yok say, latest'a düş
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
    final prefs = await SharedPreferences.getInstance();
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


