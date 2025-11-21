import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Location data
  List<Country> _countries = [];
  List<StateProvince> _states = [];
  List<City> _cities = [];
  
  // Selected locations
  Country? _selectedCountry;
  StateProvince? _selectedState;
  City? _selectedCity;
  
  // Search queries
  String _countrySearchQuery = '';
  String _stateSearchQuery = '';
  String _citySearchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<Country> get countries => _countries;
  List<StateProvince> get states => _states;
  List<City> get cities => _cities;
  Country? get selectedCountry => _selectedCountry;
  StateProvince? get selectedState => _selectedState;
  City? get selectedCity => _selectedCity;
  String get countrySearchQuery => _countrySearchQuery;
  String get stateSearchQuery => _stateSearchQuery;
  String get citySearchQuery => _citySearchQuery;

  /// Seçili konumun tam adını döndürür
  String get selectedLocationText {
    if (_selectedCity != null && _selectedState != null && _selectedCountry != null) {
      return '${_selectedCity!.name}, ${_selectedState!.name}, ${_selectedCountry!.name}';
    } else if (_selectedState != null && _selectedCountry != null) {
      return '${_selectedState!.name}, ${_selectedCountry!.name}';
    } else if (_selectedCountry != null) {
      return _selectedCountry!.name;
    }
    return 'Konum seçilmedi';
  }

  /// Konum seçimi tamamlandı mı?
  bool get isLocationSelected => _selectedCity != null && _selectedState != null && _selectedCountry != null;

  /// Seçili konumun tam bilgisini döndürür
  SelectedLocation? get selectedLocation {
    if (_selectedCity != null && _selectedState != null && _selectedCountry != null) {
      return SelectedLocation(
        country: _selectedCountry!,
        state: _selectedState!,
        city: _selectedCity!,
      );
    }
    return null;
  }

  /// Ülke listesini yükler
  Future<void> loadCountries() async {
    _setLoading(true);
    try {
      _countries = await _locationService.getCountries();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Ülke listesi yüklenirken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Eyalet listesini yükler
  Future<void> loadStates(int countryId) async {
    _setLoading(true);
    try {
      _states = await _locationService.getStatesByCountry(countryId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Eyalet listesi yüklenirken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Şehir listesini yükler
  Future<void> loadCities(int stateId) async {
    _setLoading(true);
    try {
      _cities = await _locationService.getCitiesByState(stateId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Şehir listesi yüklenirken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Ülke arama sorgusunu günceller
  void updateCountrySearchQuery(String query) {
    _countrySearchQuery = query;
    notifyListeners();
  }

  /// Eyalet arama sorgusunu günceller
  void updateStateSearchQuery(String query) {
    _stateSearchQuery = query;
    notifyListeners();
  }

  /// Şehir arama sorgusunu günceller
  void updateCitySearchQuery(String query) {
    _citySearchQuery = query;
    notifyListeners();
  }

  /// Ülke seçer
  Future<void> selectCountry(Country country) async {
    _selectedCountry = country;
    _selectedState = null;
    _selectedCity = null;
    _states = [];
    _cities = [];
    _stateSearchQuery = '';
    _citySearchQuery = '';
    
    // Seçilen ülkeye ait eyaletleri yükle
    await loadStates(country.id);
    notifyListeners();
  }

  /// Eyalet seçer
  Future<void> selectState(StateProvince state) async {
    _selectedState = state;
    _selectedCity = null;
    _cities = [];
    _citySearchQuery = '';
    
    // Seçilen eyalete ait şehirleri yükle
    await loadCities(state.id);
    notifyListeners();
  }

  /// Şehir seçer
  void selectCity(City city) {
    _selectedCity = city;
    notifyListeners();
    
    // Konum seçimi tamamlandığında kaydet
    if (isLocationSelected) {
      _saveSelectedLocation();
    }
  }

  /// Tam konum seçer (SelectedLocation nesnesi ile)
  void selectLocation(SelectedLocation location) {
    _selectedCountry = location.country;
    _selectedState = location.state;
    _selectedCity = location.city;
    notifyListeners();
    
    // Konumu kaydet
    _saveSelectedLocation();
  }

  /// Seçili konumu kaydeder
  Future<void> _saveSelectedLocation() async {
    try {
      if (selectedLocation != null) {
        await _locationService.saveSelectedLocation(selectedLocation!);
      }
    } catch (e) {
      _errorMessage = 'Konum kaydedilirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Kaydedilen konumu yükler
  Future<void> loadSavedLocation() async {
    try {
      final savedLocation = await _locationService.loadSavedLocation();
      if (savedLocation != null) {
        _selectedCountry = savedLocation.country;
        _selectedState = savedLocation.state;
        _selectedCity = savedLocation.city;
        
        // Eyalet ve şehir listelerini paralel yükle
        await Future.wait([
          loadStates(savedLocation.country.id),
          loadCities(savedLocation.state.id),
        ]);
        
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Kaydedilen konum yüklenirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Uygulama başlatıldığında çağrılır
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Önce kaydedilen konumu kontrol et
      bool hasSavedLocation = await _locationService.hasSavedLocation();
      
      if (hasSavedLocation) {
        await loadSavedLocation();
      } else {
        // Kaydedilen konum yoksa hiçbir konum seçili olarak gelmesin
        clearSelection();
      }
      
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Konum başlatılırken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Arama yaparak ülke listesini filtreler
  Future<void> searchCountries(String query) async {
    _setLoading(true);
    try {
      _countries = await _locationService.searchCountries(query);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Ülke arama yapılırken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Arama yaparak eyalet listesini filtreler
  Future<void> searchStates(String query, int countryId) async {
    _setLoading(true);
    try {
      _states = await _locationService.searchStates(query, countryId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Eyalet arama yapılırken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Arama yaparak şehir listesini filtreler
  Future<void> searchCities(String query, int stateId) async {
    _setLoading(true);
    try {
      _cities = await _locationService.searchCities(query, stateId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Şehir arama yapılırken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Tüm şehirler içinde arama yapar (ana ekrandaki gibi)
  Future<void> searchAllCities(String query) async {
    try {
      _cities = await _locationService.searchAllCities(query);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Şehir arama yapılırken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Şehir ID'sine göre tam konum bilgilerini alır ve seçer
  Future<void> selectCityById(int cityId) async {
    try {
      final location = await _locationService.getLocationByCityId(cityId);
      if (location != null) {
        _selectedCountry = location.country;
        _selectedState = location.state;
        _selectedCity = location.city;
        
        // Konumu kaydet
        await _saveSelectedLocation();
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Konum seçilirken hata oluştu: $e';
      notifyListeners();
    }
  }

  /// Varsayılan konumu yükler
  Future<void> loadDefaultLocation() async {
    _setLoading(true);
    try {
      final defaultCountry = await _locationService.getDefaultCountry();
      await selectCountry(defaultCountry);
      
      final defaultState = await _locationService.getDefaultState();
      if (_states.any((state) => state.id == defaultState.id)) {
        await selectState(defaultState);
      }
      
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Varsayılan konum yüklenirken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Seçili konumu temizler
  void clearSelection() {
    _selectedCountry = null;
    _selectedState = null;
    _selectedCity = null;
    _states = [];
    _cities = [];
    _countrySearchQuery = '';
    _stateSearchQuery = '';
    _citySearchQuery = '';
    notifyListeners();
  }

  /// Seçili konumu döndürür
  SelectedLocation? getSelectedLocation() {
    if (_selectedCity != null && _selectedState != null && _selectedCountry != null) {
      return SelectedLocation(
        country: _selectedCountry!,
        state: _selectedState!,
        city: _selectedCity!,
      );
    }
    return null;
  }

  /// GPS ile mevcut konumu alır ve seçer
  Future<void> getCurrentLocationFromGPS() async {
    _setLoading(true);
    try {
      // GPS konumunu al
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        _errorMessage = 'GPS konumu alınamadı';
        return;
      }

      // En yakın şehri bul
      SelectedLocation? location = await _locationService.findNearestLocation(position);
      if (location != null) {
        _selectedCountry = location.country;
        _selectedState = location.state;
        _selectedCity = location.city;
        
        // GPS konumu seçildiğinde kaydet
        await _saveSelectedLocation();
        
        _errorMessage = '';
      } else {
        _errorMessage = 'Konumunuz için şehir bulunamadı';
      }
    } catch (e) {
      _errorMessage = 'GPS konumu alınırken hata oluştu: $e';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 