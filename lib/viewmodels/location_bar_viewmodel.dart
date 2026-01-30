import 'package:flutter/material.dart';
import 'dart:async';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../services/prayer_times_service.dart';

enum LocationBarStep {
  collapsed,
  selectingCity,
}

class LocationBarViewModel extends ChangeNotifier {
  List<SelectedLocation> _enrichHistory(
    List<SelectedLocation> rawHistory,
    List<StateProvince> states,
    List<Country> countries,
  ) {
    return rawHistory.map((sl) {
      final realState = states.firstWhere((s) => s.id == sl.state.id, orElse: () => sl.state);
      final realCountry = countries.firstWhere((c) => c.id == realState.countryId, orElse: () => sl.country);
      return SelectedLocation(country: realCountry, state: realState, city: sl.city);
    }).toList();
  }

  void _buildCityIndex(List<City> cities) {
    _cityIdToNormalizedName.clear();
    for (final city in cities) {
      // Hem normal hem Arapça hem de code (İngilizce) isimlerle arama yapabilmek için hepsini normalize et
      final normalizedName = _normalize(city.name);
      final normalizedNameAr = city.nameAr != null ? _normalize(city.nameAr!) : '';
      final normalizedCode = _normalize(city.code);
      // Tüm isimleri birleştirerek sakla (arama için)
      _cityIdToNormalizedName[city.id] = '$normalizedName $normalizedNameAr $normalizedCode';
    }
  }

  // Normalize Turkish 'i' and 'ı' for case-insensitive search
  String _normalize(String s) {
    return s.toLowerCase()
      .replaceAll('ı', 'i')
      // lowercase of 'İ' produces 'i̇' (i + combining dot)
      .replaceAll(RegExp(r'i\u0307'), 'i');
  }

  /// Arapça karakter içerip içermediğini kontrol eder
  bool _containsArabic(String text) {
    return text.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF);
  }
  
  final LocationService _locationService = LocationService();
  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  
  // Cache için
  List<StateProvince>? _cachedStates;
  List<Country>? _cachedCountries;
  List<SelectedLocation>? _cachedEnrichedHistory;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(hours: 1);
  
  /// Pre-load history when ViewModel is created (lazy - sadece drawer açıldığında)
  LocationBarViewModel() {
    // History'yi lazy load yap - drawer açıldığında yüklenecek
    // Bu sayede constructor'da ağır işlem yapılmaz
  }
  
  bool _isHistoryLoading = false;
  
  /// Cache'in geçerli olup olmadığını kontrol eder
  bool _isCacheValid() {
    if (_cachedStates == null || _cachedCountries == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration;
  }
  
  /// Cache'i temizler
  void _clearCache() {
    _cachedStates = null;
    _cachedCountries = null;
    _cachedEnrichedHistory = null;
    _cacheTimestamp = null;
  }
  
  /// Loads saved location history from SharedPreferences (lazy loading with cache)
  Future<void> _loadHistory() async {
    // Eğer history zaten yüklenmişse veya yükleniyorsa tekrar yükleme
    if (_history.isNotEmpty || _isHistoryLoading) return;
    
    _isHistoryLoading = true;
    
    try {
      // Önce raw history'yi yükle (hızlı)
      final rawHistory = await _locationService.loadLocationHistory();
      
      // Eğer history boşsa, states ve countries yüklemeden çık
      if (rawHistory.isEmpty) {
        _history = [];
        _isHistoryLoading = false;
        notifyListeners();
        return;
      }
      
      // Cache kontrolü - eğer cache geçerliyse direkt kullan
      if (_isCacheValid() && _cachedEnrichedHistory != null) {
        // Cache'deki history ile raw history'yi karşılaştır
        final rawHistoryIds = rawHistory.map((sl) => sl.city.id).toSet();
        final cachedHistoryIds = _cachedEnrichedHistory!.map((sl) => sl.city.id).toSet();
        
        // Eğer aynıysa cache'i kullan
        if (rawHistoryIds.length == cachedHistoryIds.length && 
            rawHistoryIds.every((id) => cachedHistoryIds.contains(id))) {
          _history = List.from(_cachedEnrichedHistory!);
          _isHistoryLoading = false;
          notifyListeners();
          return;
        }
      }
      
      // Önce raw history'yi göster (kullanıcı hemen görsün - UI responsive kalır)
      _history = List.from(rawHistory); // Yeni liste oluştur
      _isHistoryLoading = false;
      notifyListeners();
      
      // Sonra states ve countries'i paralel yükle ve zenginleştir (arka planda)
      // Bu işlem UI'ı bloke etmez çünkü await kullanmıyoruz
      Future.microtask(() async {
        try {
          List<StateProvince> states;
          List<Country> countries;
          
          // Cache'den states ve countries'i al veya yükle
          if (_isCacheValid() && _cachedStates != null && _cachedCountries != null) {
            states = _cachedStates!;
            countries = _cachedCountries!;
          } else {
            // Cache yoksa veya geçersizse yükle ve cache'le
            final statesFuture = _locationService.getStates();
            final countriesFuture = _locationService.getCountries();
            states = await statesFuture;
            countries = await countriesFuture;
            
            // Cache'e kaydet
            _cachedStates = states;
            _cachedCountries = countries;
            _cacheTimestamp = DateTime.now();
          }
          
          // History'yi zenginleştir (güncelle)
          final enrichedHistory = _enrichHistory(rawHistory, states, countries);
          _history = enrichedHistory;
          
          // Zenginleştirilmiş history'yi cache'le
          _cachedEnrichedHistory = List.from(enrichedHistory);
          
          notifyListeners();
        } catch (_) {
          // Hata durumunda sessizce devam et
        }
      });
    } catch (_) {
      // Hata durumunda boş history göster
      _history = [];
      _isHistoryLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh history (public metod)
  Future<void> refreshHistory() async {
    // Cache'i temizle ve history'yi sıfırla
    _clearCache();
    _history = [];
    _isHistoryLoading = false;
    await _loadHistory();
  }
  
  LocationBarStep _currentStep = LocationBarStep.collapsed;
  bool _isLoading = false;
  String _searchQuery = '';
  
  // Data lists
  List<City> _cities = [];
  List<SelectedLocation> _history = [];
  // Search helpers
  final Map<int, String> _cityIdToNormalizedName = {};
  final List<City> _filteredCities = [];
  Timer? _searchDebounce;
  
  // Selected items
  City? _selectedCity;
  
  // Getters
  LocationBarStep get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  List<City> get cities => _cities;
  City? get selectedCity => _selectedCity;
  List<SelectedLocation> get history => _history;
  
  bool get isExpanded => _currentStep != LocationBarStep.collapsed;

  /// History'yi arka planda preload et (uygulama açılışında çağrılır)
  void preloadHistory() {
    // Eğer history zaten yüklenmişse veya yükleniyorsa tekrar yükleme
    if (_history.isNotEmpty || _isHistoryLoading) return;
    
    // History'yi arka planda yükle (UI'ı bloke etmez)
    _loadHistory();
  }

  Future<void> ensureDataLoaded() async {
    // History'yi lazy load yap (ilk açılışta)
    // Sadece history yüklü değilse yükle, şehirleri yükleme (sadece arama yapıldığında yüklenecek)
    if (_history.isEmpty && !_isHistoryLoading) {
      // History'yi arka planda yükle (UI'ı bloke etmez)
      _loadHistory();
    }
    
    // Şehirleri sadece arama yapıldığında yükle (ilk açılışta yükleme)
    // Bu sayede drawer açılış performansı artar
  }
  
  /// Şehirleri arka planda yükler, UI'ı bloke etmez
  Future<void> _loadCitiesInBackground() async {
    if (_isLoading || _cities.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      // Sadece şehirleri yükle (history zaten yüklü)
      final cities = await _locationService.getCities();
      _cities = cities;
      _buildCityIndex(_cities);
      notifyListeners();
    } catch (_) {
      // Hata durumunda sessizce devam et
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> toggleExpansion() async {
    if (_currentStep == LocationBarStep.collapsed) {
      _currentStep = LocationBarStep.selectingCity;
      // Şehirleri arka planda yükle (history zaten yüklü)
      await _loadCitiesInBackground();
    } else {
      collapse();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
  
  void collapse() {
    _currentStep = LocationBarStep.collapsed;
    _searchQuery = '';
    _searchDebounce?.cancel();
    _filteredCities.clear();
    notifyListeners();
  }
  
  void selectCity(City city) {
    _selectedCity = city;
    // Seçim tamamlandı, collapse et
    collapse();
  }
  
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    
    // Eğer arama yapılıyorsa ve şehirler yüklenmemişse, önce yükle
    if (query.isNotEmpty && _cities.isEmpty && !_isLoading) {
      // Şehirleri arka planda yükle (UI'ı bloke etmez)
      _loadCitiesInBackground().then((_) {
        // Şehirler yüklendikten sonra arama yap
        if (_searchQuery == query && _cities.isNotEmpty) {
          _runSearch();
        }
      });
      // Arama yapılırken loading göster
      notifyListeners();
    } else if (query.isEmpty) {
      // Arama temizlendiğinde sonuçları temizle
      _filteredCities.clear();
      notifyListeners();
    } else if (_cities.isNotEmpty) {
      // Normal arama debounce (sadece şehirler yüklüyse) - 300ms optimizasyonu
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _runSearch();
      });
      notifyListeners();
    }
  }

  void _runSearch() {
    _filteredCities.clear();
    if (_searchQuery.isEmpty) {
      notifyListeners();
      return;
    }
    // Şehirler yüklenmemişse arama yapma
    if (_cities.isEmpty) {
      notifyListeners();
      return;
    }
    final String normQuery = _normalize(_searchQuery);
    final bool isArabicQuery = _containsArabic(_searchQuery);
    // Limit results to reduce build cost
    const int maxResults = 50;
    int added = 0;
    for (final city in _cities) {
      bool matches = false;
      
      if (isArabicQuery) {
        // Arapça arama yapılıyorsa öncelikle nameAr'da ara
        if (city.nameAr != null) {
          final normalizedNameAr = _normalize(city.nameAr!);
          if (normalizedNameAr.contains(normQuery)) {
            matches = true;
          } else {
            // Arapça isimde bulunamazsa diğer alanlarda ara
            final normalizedName = _normalize(city.name);
            final normalizedCode = _normalize(city.code);
            matches = normalizedName.contains(normQuery) || normalizedCode.contains(normQuery);
          }
        } else {
          // nameAr yoksa normal arama
          final normalizedName = _normalize(city.name);
          final normalizedCode = _normalize(city.code);
          matches = normalizedName.contains(normQuery) || normalizedCode.contains(normQuery);
        }
      } else {
        // Diğer dillerde normal arama
        final normalized = _cityIdToNormalizedName[city.id] ?? 
            '${_normalize(city.name)} ${city.nameAr != null ? _normalize(city.nameAr!) : ''} ${_normalize(city.code)}';
        matches = normalized.contains(normQuery);
      }
      
      if (matches) {
        _filteredCities.add(city);
        added++;
        if (added >= maxResults) break;
      }
    }
    notifyListeners();
  }

  List<City> get filteredCities => List.unmodifiable(_filteredCities);
  
  String get currentStepTitle {
    switch (_currentStep) {
      case LocationBarStep.selectingCity:
        return 'Şehir Seçin';
      default:
        return '';
    }
  }
  
  SelectedLocation? get selectedLocation {
    if (_selectedCity != null) {
      final dummyState = StateProvince(
        id: _selectedCity!.stateId,
        countryId: 0,
        code: '',
        name: '',
        nameAr: null,
        createdAt: '',
        updatedAt: '',
      );
      final dummyCountry = Country(
        id: 0,
        code: '',
        name: '',
        nameAr: null,
        createdAt: '',
        updatedAt: '',
      );
      return SelectedLocation(
        country: dummyCountry,
        state: dummyState,
        city: _selectedCity!,
      );
    }
    return null;
  }
  
  /// Fetch and select current location using GPS
  Future<SelectedLocation?> fetchCurrentLocation() async {
    _isLoading = true;
    notifyListeners();
    try {
      final position = await _locationService.getCurrentLocation();
      if (position == null) return null;
      final sl = await _locationService.findNearestLocation(position);
      if (sl != null) {
        selectCity(sl.city);
        return sl;
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Removes a location from history and updates the UI
  Future<void> removeLocationFromHistory(SelectedLocation location) async {
    try {
      await _locationService.removeLocationFromHistory(location);
      // Silinen konuma ait namaz vakitleri cache ve dosyasını temizle
      _prayerTimesService.clearCache();
      await _prayerTimesService.clearLocalFile(location.city.id, DateTime.now().year);
      // Silinen konumu seçili konum hafızasından sil
      await _locationService.clearSavedLocation();
      // Yeni liste oluştur (Selector'ın değişikliği algılaması için)
      _history = _history.where((sl) => sl.city.id != location.city.id).toList();
      
      // Cache'i de güncelle
      if (_cachedEnrichedHistory != null) {
        _cachedEnrichedHistory = _cachedEnrichedHistory!
            .where((sl) => sl.city.id != location.city.id)
            .toList();
      }
      
      notifyListeners();
    } catch (e) {
      // ignore errors
    }
  }
} 