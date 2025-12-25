import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_content.dart';
import '../services/daily_content_repository.dart';
import '../services/locale_service.dart';

class DailyContentViewModel extends ChangeNotifier {
  final DailyContentRepository _repo = DailyContentRepository();
  LocaleService? _localeService;

  DailyContent? _ayet;
  DailyContent? _hadis;
  bool _isLoading = false;
  String? _errorMessage;
  String _lang = 'tr';
  Timer? _midnightTimer;

  DailyContent? get ayet => _ayet;
  DailyContent? get hadis => _hadis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentLang => _lang;

  set currentLang(String lang) {
    final normalized = lang.toLowerCase();
    if (_lang != normalized) {
      _lang = normalized;
      notifyListeners();
    }
  }

  void attachLocaleService(LocaleService localeService) {
    if (!identical(_localeService, localeService)) {
      _localeService?.removeListener(_onLocaleChanged);
      _localeService = localeService;
      _localeService?.addListener(_onLocaleChanged);
    }
    currentLang = localeService.currentLocale.languageCode;
  }

  Future<void> initialize({String? preferredLang}) async {
    _lang = preferredLang ?? _detectDeviceLang();
    await loadToday();
    _scheduleMidnightRefresh();
  }

  Future<void> loadToday() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.clearOldCaches();
      final pair = await _repo.getRandomPairDailyCached();
      _ayet = pair.$1;
      _hadis = pair.$2;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() {
    return loadToday();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final duration = tomorrow.difference(now);
    _midnightTimer = Timer(duration, () async {
      await loadToday();
      _scheduleMidnightRefresh();
    });
  }

  String _detectDeviceLang() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = locale.languageCode.toLowerCase();
    if (lang.startsWith('tr')) return 'tr';
    if (lang.startsWith('ar')) return 'ar';
    return 'en';
  }

  @override
  void dispose() {
    _localeService?.removeListener(_onLocaleChanged);
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _onLocaleChanged() {
    final langCode = _localeService?.currentLocale.languageCode;
    if (langCode != null && langCode.isNotEmpty) {
      currentLang = langCode;
    }
  }
}


