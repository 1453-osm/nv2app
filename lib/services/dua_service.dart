import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../utils/app_keys.dart';
import '../utils/app_logger.dart';

/// Dua modeli.
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

  /// Dil koduna göre dua metnini döndürür.
  String getText(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case AppKeys.langTurkish:
        return tr.text;
      case AppKeys.langArabic:
        return ar.text;
      case AppKeys.langEnglish:
        return en.text;
      default:
        return tr.text;
    }
  }

  @override
  String toString() => 'Dua(id: $id)';
}

/// Dua metni modeli.
class DuaText {
  final String text;

  const DuaText({required this.text});

  factory DuaText.fromJson(Map<String, dynamic> json) {
    return DuaText(
      text: json['text'] as String? ?? '',
    );
  }
}

/// Duaları yöneten singleton servis.
///
/// JSON dosyasından duaları yükler ve rastgele dua seçimi sağlar.
class DuaService {
  static final DuaService _instance = DuaService._internal();
  factory DuaService() => _instance;
  DuaService._internal();

  List<Dua>? _dualar;
  bool _isLoaded = false;
  final Random _random = Random();

  List<Dua>? get dualar => _dualar;
  bool get isLoaded => _isLoaded;

  /// dualar.json dosyasını yükler (sadece bir kez).
  Future<void> loadDualar() async {
    if (_isLoaded) {
      AppLogger.debug('Dualar already loaded', tag: 'DuaService');
      return;
    }

    final stopwatch = AppLogger.startTimer('DuaService.loadDualar');

    try {
      final String jsonString = await rootBundle.loadString(AppKeys.assetsDualarPath);
      final List<String> lines = jsonString
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      _dualar = <Dua>[];
      int successCount = 0;
      int failCount = 0;

      for (final line in lines) {
        try {
          final Map<String, dynamic> duaJson = json.decode(line.trim());
          final dua = Dua.fromJson(duaJson);
          _dualar!.add(dua);
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.warning('Failed to parse dua line', tag: 'DuaService');
        }
      }

      _isLoaded = true;

      AppLogger.stopTimer(stopwatch, 'DuaService.loadDualar');
      AppLogger.success('Loaded $successCount dualar (${failCount > 0 ? "$failCount failed" : "all success"})', tag: 'DuaService');
    } catch (e, stackTrace) {
      AppLogger.error('Error loading dualar', tag: 'DuaService', error: e, stackTrace: stackTrace);
      _dualar = [];
      _isLoaded = true;
    }
  }

  /// Rastgele bir dua seçer.
  Dua? getRandomDua() {
    if (!_isLoaded || _dualar == null || _dualar!.isEmpty) {
      AppLogger.warning('No dualar available for random selection', tag: 'DuaService');
      return null;
    }

    final int randomIndex = _random.nextInt(_dualar!.length);
    final selectedDua = _dualar![randomIndex];

    AppLogger.debug('Selected random dua with id: ${selectedDua.id}', tag: 'DuaService');
    return selectedDua;
  }

  /// ID'ye göre dua getirir.
  Dua? getDuaById(int id) {
    if (!_isLoaded || _dualar == null || _dualar!.isEmpty) {
      return null;
    }

    try {
      return _dualar!.firstWhere((dua) => dua.id == id);
    } catch (e) {
      AppLogger.warning('Dua with id $id not found', tag: 'DuaService');
      return null;
    }
  }

  /// Rastgele dua metnini belirli dilde döndürür.
  String? getRandomDuaText({String language = AppKeys.langTurkish}) {
    final dua = getRandomDua();
    return dua?.getText(language);
  }

  /// Servisi sıfırlar (test amaçlı).
  void reset() {
    _dualar = null;
    _isLoaded = false;
    AppLogger.debug('Service reset', tag: 'DuaService');
  }
}
