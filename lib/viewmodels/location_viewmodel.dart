import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../utils/error_messages.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  // State variables
  bool _isLoading = false;
  bool _isInitialized = false;
  String _errorMessage = '';
  ErrorCode? _errorCode;

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
  bool get isInitialized => _isInitialized;
  String get errorMessage => _errorMessage;
  ErrorCode? get errorCode => _errorCode;
  List<Country> get countries => _countries;
  List<StateProvince> get states => _states;
  List<City> get cities => _cities;
  Country? get selectedCountry => _selectedCountry;
  StateProvince? get selectedState => _selectedState;
  City? get selectedCity => _selectedCity;
  String get countrySearchQuery => _countrySearchQuery;
  String get stateSearchQuery => _stateSearchQuery;
  String get citySearchQuery => _citySearchQuery;

  /// UI katmanında hata mesajını oluşturur
  String getErrorMessage(BuildContext context) {
    if (_errorCode != null) {
      return ErrorMessages.fromErrorCode(context, _errorCode!);
    }
    // _errorMessage içinde exception string'leri varsa, sadece çeviri dosyalarındaki mesajı kullan
    // Exception detaylarını gizlemek için mesajı parse et
    if (_errorMessage.isNotEmpty) {
      // ErrorMessages metodlarından gelen mesajları kontrol et ve context ile çevir
      // Exception string'lerini temizle ve sadece genel hata mesajını göster
      final errorLower = _errorMessage.toLowerCase();

      // Hangi hata tipi olduğunu tespit et ve çevir (exception detaylarını gizle)
      // Mesajın başlangıcını kontrol et (daha güvenilir)
      if (errorLower.startsWith('ülke listesi') ||
          errorLower.contains('ülke listesi yüklenirken')) {
        return ErrorMessages.countryListLoadError(context, '');
      } else if (errorLower.startsWith('eyalet listesi') ||
          errorLower.contains('eyalet listesi yüklenirken')) {
        return ErrorMessages.stateListLoadError(context, '');
      } else if (errorLower.startsWith('şehir listesi') ||
          errorLower.contains('şehir listesi yüklenirken')) {
        return ErrorMessages.cityListLoadError(context, '');
      } else if (errorLower.startsWith('konum kaydedilirken') ||
          errorLower.contains('konum kaydedilirken hata')) {
        return ErrorMessages.locationSaveError(context, '');
      } else if (errorLower.startsWith('kaydedilen konum') ||
          errorLower.contains('kaydedilen konum yüklenirken')) {
        return ErrorMessages.savedLocationLoadError(context, '');
      } else if (errorLower.startsWith('konum başlatılırken') ||
          errorLower.contains('konum başlatılırken hata')) {
        return ErrorMessages.locationInitError(context, '');
      } else if (errorLower.startsWith('ülke arama') ||
          errorLower.contains('ülke arama yapılırken')) {
        return ErrorMessages.countrySearchError(context, '');
      } else if (errorLower.startsWith('eyalet arama') ||
          errorLower.contains('eyalet arama yapılırken')) {
        return ErrorMessages.stateSearchError(context, '');
      } else if (errorLower.startsWith('şehir arama') ||
          errorLower.contains('şehir arama yapılırken')) {
        return ErrorMessages.citySearchError(context, '');
      } else if (errorLower.startsWith('konum seçilirken') ||
          errorLower.contains('konum seçilirken hata')) {
        return ErrorMessages.locationSelectError(context, '');
      } else if (errorLower.startsWith('varsayılan konum') ||
          errorLower.contains('varsayılan konum yüklenirken')) {
        return ErrorMessages.defaultLocationLoadError(context, '');
      } else if (errorLower.startsWith('gps konumu alınırken') ||
          errorLower.contains('gps konumu alınırken hata')) {
        return ErrorMessages.gpsLocationFetchError(context, '');
      } else if (errorLower.startsWith('gps konumu alınamadı') ||
          errorLower.contains('gps konumu alınamadı')) {
        return ErrorMessages.gpsLocationNotAvailable(context);
      } else if (errorLower.startsWith('şehir bulunamadı') ||
          errorLower.contains('şehir bulunamadı')) {
        return ErrorMessages.cityNotFoundForLocation(context);
      }
      // Bilinmeyen hata için: exception detaylarını temizle ve açıklayıcı mesaj göster
      // Exception string'lerini temizle (Exception:, Error:, at, etc.)
      String cleanMessage = _errorMessage;

      // Exception detaylarını temizle
      final exceptionPatterns = [
        RegExp(r'Exception:\s*', caseSensitive: false),
        RegExp(r'Error:\s*', caseSensitive: false),
        RegExp(r'\s+at\s+[^\n]+', caseSensitive: false),
        RegExp(r'#\d+\s+[^\n]+', caseSensitive: false),
        RegExp(r'package:[^\n]+', caseSensitive: false),
        RegExp(r'dart:[^\n]+', caseSensitive: false),
      ];

      for (var pattern in exceptionPatterns) {
        cleanMessage = cleanMessage.replaceAll(pattern, '');
      }

      // Çok uzun mesajları kısalt
      if (cleanMessage.length > 200) {
        cleanMessage = '${cleanMessage.substring(0, 200)}...';
      }

      // Temizlenmiş mesaj boş değilse göster, değilse genel mesaj
      if (cleanMessage.trim().isNotEmpty) {
        return cleanMessage.trim();
      }

      return ErrorMessages.unknownError(context);
    }
    return '';
  }

  /// Seçili konumun tam adını döndürür (varsayılan dil için)
  String get selectedLocationText {
    if (_selectedCity != null &&
        _selectedState != null &&
        _selectedCountry != null) {
      return '${_selectedCity!.name}, ${_selectedState!.name}, ${_selectedCountry!.name}';
    } else if (_selectedState != null && _selectedCountry != null) {
      return '${_selectedState!.name}, ${_selectedCountry!.name}';
    } else if (_selectedCountry != null) {
      return _selectedCountry!.name;
    }
    // Bu metin fallback olarak kullanılıyor
    // UI katmanında AppLocalizations.of(context)!.locationNotSelected kullanılmalı
    return 'Location not selected'; // Fallback - UI katmanında AppLocalizations kullanılmalı
  }

  /// Locale'e göre seçili konumun tam adını döndürür
  String getSelectedLocationText(Locale locale) {
    if (_selectedCity != null &&
        _selectedState != null &&
        _selectedCountry != null) {
      return '${_selectedCity!.getDisplayName(locale)}, ${_selectedState!.getDisplayName(locale)}, ${_selectedCountry!.getDisplayName(locale)}';
    } else if (_selectedState != null && _selectedCountry != null) {
      return '${_selectedState!.getDisplayName(locale)}, ${_selectedCountry!.getDisplayName(locale)}';
    } else if (_selectedCountry != null) {
      return _selectedCountry!.getDisplayName(locale);
    }
    // Bu metin fallback olarak kullanılıyor
    // UI katmanında AppLocalizations.of(context)!.locationNotSelected kullanılmalı
    return 'Location not selected'; // Fallback - UI katmanında AppLocalizations kullanılmalı
  }

  /// Konum seçimi tamamlandı mı?
  bool get isLocationSelected =>
      _selectedCity != null &&
      _selectedState != null &&
      _selectedCountry != null;

  /// Seçili konumun tam bilgisini döndürür
  SelectedLocation? get selectedLocation {
    if (_selectedCity != null &&
        _selectedState != null &&
        _selectedCountry != null) {
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
    if (_isLoading) return;
    _setLoading(true);
    try {
      _countries = await _locationService.getCountries();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = ErrorMessages.countryListLoadError(null, e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Eyalet listesini yükler
  Future<void> loadStates(int countryId) async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      _states = await _locationService.getStatesByCountry(countryId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = ErrorMessages.stateListLoadError(null, e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Şehir listesini yükler
  Future<void> loadCities(int stateId) async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      _cities = await _locationService.getCitiesByState(stateId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = ErrorMessages.cityListLoadError(null, e.toString());
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
      _errorMessage = ErrorMessages.locationSaveError(null, e.toString());
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
      _errorMessage = ErrorMessages.savedLocationLoadError(null, e.toString());
      notifyListeners();
    }
  }

  /// Konum yüklü değilse ve kaydedilmiş konum varsa yüklemeyi dener
  /// Uygulama resume olduğunda kullanılabilir
  Future<void> ensureLocationLoaded() async {
    // Eğer konum zaten yüklüyse, bir şey yapma
    if (isLocationSelected) {
      return;
    }

    // Eğer zaten yükleniyorsa, bekle
    if (_isLoading) {
      return;
    }

    try {
      // Kaydedilmiş konum var mı kontrol et
      bool hasSavedLocation = await _locationService.hasSavedLocation();
      if (hasSavedLocation) {
        await loadSavedLocation();
      }
    } catch (e) {
      // Sessizce devam et - hata durumunda kullanıcı manuel olarak seçebilir
      debugPrint('Konum yükleme hatası (ensureLocationLoaded): $e');
    }
  }

  /// Uygulama başlatıldığında çağrılır
  Future<void> initialize() async {
    // Eğer zaten başlatıldıysa, tekrar başlatma
    if (_isInitialized) {
      return;
    }

    if (_isLoading) return;
    _setLoading(true);

    try {
      // Kaydedilen konumu kontrol et
      bool hasSavedLocation = false;
      try {
        hasSavedLocation = await _locationService.hasSavedLocation().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('LocationService.hasSavedLocation timeout');
            }
            return false;
          },
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LocationService.hasSavedLocation error: $e');
        }
        hasSavedLocation = false;
      }

      if (hasSavedLocation) {
        // Kaydedilen konumu yükle
        try {
          await loadSavedLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) {
                debugPrint('LocationViewModel.loadSavedLocation timeout');
              }
              // Timeout durumunda seçimi temizle
              clearSelection();
            },
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('LocationViewModel.loadSavedLocation error: $e');
          }
          clearSelection();
        }
      } else {
        // Kaydedilen konum yoksa seçimi temizle
        clearSelection();
      }

      _errorMessage = '';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationViewModel initialize error: $e');
      }
      _errorMessage = ErrorMessages.locationInitError(null, e.toString());
    } finally {
      // Her durumda başlatıldı olarak işaretle, UI takılı kalmasın
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Arama yaparak ülke listesini filtreler
  Future<void> searchCountries(String query) async {
    _setLoading(true);
    try {
      _countries = await _locationService.searchCountries(query);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = ErrorMessages.countrySearchError(null, e.toString());
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
      _errorMessage = ErrorMessages.stateSearchError(null, e.toString());
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
      _errorMessage = ErrorMessages.citySearchError(null, e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Tüm şehirler içinde arama yapar (ana ekrandaki gibi)
  Future<void> searchAllCities(String query) async {
    try {
      _citySearchQuery = query;
      _cities = await _locationService.searchAllCities(query);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorMessages.citySearchError(null, e.toString());
      notifyListeners();
    }
  }

  /// Şehir arama sonuçlarını temizler
  void clearCitySearchResults() {
    _cities = [];
    _citySearchQuery = '';
    notifyListeners();
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
      _errorMessage = ErrorMessages.locationSelectError(null, e.toString());
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
      _errorMessage =
          ErrorMessages.defaultLocationLoadError(null, e.toString());
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
    return selectedLocation;
  }

  /// GPS ile mevcut konumu alır ve seçer
  Future<void> getCurrentLocationFromGPS() async {
    _setLoading(true);
    try {
      // GPS konumunu al
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        _errorMessage = ErrorMessages.gpsLocationNotAvailable(null);
        return;
      }

      // En yakın şehri bul
      SelectedLocation? location =
          await _locationService.findNearestLocation(position);
      if (location != null) {
        _selectedCountry = location.country;
        _selectedState = location.state;
        _selectedCity = location.city;

        // GPS konumu seçildiğinde kaydet
        await _saveSelectedLocation();

        _errorMessage = '';
      } else {
        _errorMessage = ErrorMessages.cityNotFoundForLocation(null);
      }
    } catch (e) {
      _errorMessage = ErrorMessages.gpsLocationFetchError(null, e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
