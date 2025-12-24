import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Dua modeli
class Dua {
  final int id;
  final DuaText tr;
  final DuaText ar;
  final DuaText en;

  const Dua({
    required this.id,
    required this.tr,
    required this.ar,
    required this.en,
  });

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      id: json['id'] as int,
      tr: DuaText.fromJson(json['tr'] as Map<String, dynamic>),
      ar: DuaText.fromJson(json['ar'] as Map<String, dynamic>),
      en: DuaText.fromJson(json['en'] as Map<String, dynamic>),
    );
  }
}

/// Dua metni modeli
class DuaText {
  final String text;

  const DuaText({
    required this.text,
  });

  factory DuaText.fromJson(Map<String, dynamic> json) {
    return DuaText(
      text: json['text'] as String,
    );
  }
}

/// dualar.json dosyasından duaları okur ve rastgele dua seçimi yapar
/// MVVM mimarisine uygun singleton service
class DuaService {
  static final DuaService _instance = DuaService._internal();
  factory DuaService() => _instance;
  DuaService._internal();

  List<Dua>? _dualar;
  bool _isLoaded = false;
  final Random _random = Random();

  List<Dua>? get dualar => _dualar;
  bool get isLoaded => _isLoaded;

  /// dualar.json dosyasını yükle (sadece bir kez)
  Future<void> loadDualar() async {
    if (_isLoaded) {
      if (kDebugMode) {
        print('DuaService: Dualar already loaded');
      }
      return;
    }

    if (kDebugMode) {
      print('DuaService: Loading dualar...');
    }

    try {
      // assets/notifications/dualar.json dosyasını oku
      final String jsonString = await rootBundle.loadString('assets/notifications/dualar.json');
      
      // JSON satırlarını ayrı ayrı parse et
      final List<String> lines = jsonString.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      _dualar = <Dua>[];
      for (final line in lines) {
        try {
          final Map<String, dynamic> duaJson = json.decode(line.trim());
          final dua = Dua.fromJson(duaJson);
          _dualar!.add(dua);
        } catch (e) {
          if (kDebugMode) {
            print('DuaService: Error parsing line: $line, error: $e');
          }
        }
      }

      _isLoaded = true;
      
      if (kDebugMode) {
        print('DuaService: Successfully loaded ${_dualar!.length} dualar');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DuaService: Error loading dualar: $e');
      }
      _dualar = [];
      _isLoaded = true;
    }
  }

  /// Rastgele bir dua seç
  Dua? getRandomDua() {
    if (!_isLoaded || _dualar == null || _dualar!.isEmpty) {
      if (kDebugMode) {
        print('DuaService: No dualar available for random selection');
      }
      return null;
    }

    final int randomIndex = _random.nextInt(_dualar!.length);
    final selectedDua = _dualar![randomIndex];
    
    if (kDebugMode) {
      print('DuaService: Selected random dua with id: ${selectedDua.id}');
    }
    
    return selectedDua;
  }

  /// ID'ye göre dua getir
  Dua? getDuaById(int id) {
    if (!_isLoaded || _dualar == null || _dualar!.isEmpty) {
      return null;
    }

    try {
      return _dualar!.firstWhere((dua) => dua.id == id);
    } catch (e) {
      if (kDebugMode) {
        print('DuaService: Dua with id $id not found');
      }
      return null;
    }
  }

  /// Belirli bir dil için dua metnini al
  String getDuaText(Dua dua, {String language = 'tr'}) {
    switch (language.toLowerCase()) {
      case 'tr':
        return dua.tr.text;
      case 'ar':
        return dua.ar.text;
      case 'en':
        return dua.en.text;
      default:
        return dua.tr.text; // varsayılan Türkçe
    }
  }

  /// Rastgele dua metnini belirli dilde al
  String? getRandomDuaText({String language = 'tr'}) {
    final dua = getRandomDua();
    if (dua == null) return null;
    
    return getDuaText(dua, language: language);
  }

  /// Servisi sıfırla (test amaçlı)
  void reset() {
    _dualar = null;
    _isLoaded = false;
  }
}
