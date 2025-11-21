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
  // Normalize Turkish 'i' and 'ı' for case-insensitive search
  String _normalize(String s) {
    return s.toLowerCase()
      .replaceAll('ı', 'i')
      // lowercase of 'İ' produces 'i̇' (i + combining dot)
      .replaceAll(RegExp(r'i\u0307'), 'i');
  }
  
  final LocationService _locationService = LocationService();
  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  
  /// Pre-load history when ViewModel is created
  LocationBarViewModel() {
    _loadHistory();
  }
  
  /// Loads saved location history from SharedPreferences
  Future<void> _loadHistory() async {
    try {
      // Load raw history, then enrich with actual state and country
      final rawHistory = await _locationService.loadLocationHistory();
      final states = await _locationService.getStates();
      final countries = await _locationService.getCountries();
      _history = rawHistory.map((sl) {
        final realState = states.firstWhere((s) => s.id == sl.state.id, orElse: () => sl.state);
        final realCountry = countries.firstWhere((c) => c.id == realState.countryId, orElse: () => sl.country);
        return SelectedLocation(country: realCountry, state: realState, city: sl.city);
      }).toList();
      notifyListeners();
    } catch (_) {
      // ignore errors
    }
  }
  
  /// Refresh history (public metod)
  Future<void> refreshHistory() async {
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
  
  Future<void> toggleExpansion() async {
    if (_currentStep == LocationBarStep.collapsed) {
      _currentStep = LocationBarStep.selectingCity;
      _isLoading = true;
      notifyListeners();
      try {
        // Load cities, raw history, states, and countries in parallel
        final citiesFuture = _locationService.getCities();
        final rawHistFuture = _locationService.loadLocationHistory();
        final statesFuture = _locationService.getStates();
        final countriesFuture = _locationService.getCountries();
        final rawCities = await citiesFuture;
        final rawHist = await rawHistFuture;
        final states = await statesFuture;
        final countries = await countriesFuture;
        _cities = rawCities;
        // Build normalized index once for fast contains checks
        _cityIdToNormalizedName.clear();
        for (final city in _cities) {
          _cityIdToNormalizedName[city.id] = _normalize(city.name);
        }
        // Enrich history entries
        _history = rawHist.map((sl) {
          final realState = states.firstWhere((s) => s.id == sl.state.id, orElse: () => sl.state);
          final realCountry = countries.firstWhere((c) => c.id == realState.countryId, orElse: () => sl.country);
          return SelectedLocation(country: realCountry, state: realState, city: sl.city);
        }).toList();
      } catch (e) {
        collapse();
        return;
      }
      _isLoading = false;
      notifyListeners();
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
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      _runSearch();
    });
    notifyListeners();
  }

  void _runSearch() {
    _filteredCities.clear();
    if (_searchQuery.isEmpty) {
      notifyListeners();
      return;
    }
    final String normQuery = _normalize(_searchQuery);
    // Limit results to reduce build cost
    const int maxResults = 50;
    int added = 0;
    for (final city in _cities) {
      final normalized = _cityIdToNormalizedName[city.id] ?? _normalize(city.name);
      if (normalized.contains(normQuery)) {
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
        createdAt: '',
        updatedAt: '',
      );
      final dummyCountry = Country(
        id: 0,
        code: '',
        name: '',
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
      _history.removeWhere((sl) => sl.city.id == location.city.id);
      notifyListeners();
    } catch (e) {
      // ignore errors
    }
  }
} 