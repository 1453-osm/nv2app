import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_model.dart';

class LocationService {
  static const String _countriesPath = 'assets/locations/countries.json';
  static const String _statesPath = 'assets/locations/states.json';
  static const String _citiesPath = 'assets/locations/cities.json';
  
  // SharedPreferences anahtarları
  static const String _selectedCountryKey = 'selected_country';
  static const String _selectedStateKey = 'selected_state';
  static const String _selectedCityKey = 'selected_city';
  static const String _historyKey = 'location_history';

  List<Country>? _countries;
  List<StateProvince>? _states;
  List<City>? _cities;

  /// Ülke listesini yükler
  Future<List<Country>> getCountries() async {
    if (_countries != null) return _countries!;

    try {
      final String response = await rootBundle.loadString(_countriesPath);
      final List<dynamic> jsonData = json.decode(response);
      _countries = jsonData.map((json) => Country.fromJson(json)).toList();
      return _countries!;
    } catch (e) {
      throw Exception('Ülke verileri yüklenirken hata oluştu: $e');
    }
  }

  /// Eyalet/İl listesini yükler
  Future<List<StateProvince>> getStates() async {
    if (_states != null) return _states!;

    try {
      final String response = await rootBundle.loadString(_statesPath);
      final List<dynamic> jsonData = json.decode(response);
      _states = jsonData.map((json) => StateProvince.fromJson(json)).toList();
      return _states!;
    } catch (e) {
      throw Exception('Eyalet verileri yüklenirken hata oluştu: $e');
    }
  }

  /// Şehir listesini yükler
  Future<List<City>> getCities() async {
    if (_cities != null) return _cities!;

    try {
      final String response = await rootBundle.loadString(_citiesPath);
      final List<dynamic> jsonData = json.decode(response);
      _cities = jsonData.map((json) => City.fromJson(json)).toList();
      return _cities!;
    } catch (e) {
      throw Exception('Şehir verileri yüklenirken hata oluştu: $e');
    }
  }

  /// Belirli bir ülkeye ait eyaletleri getirir
  Future<List<StateProvince>> getStatesByCountry(int countryId) async {
    final states = await getStates();
    return states.where((state) => state.countryId == countryId).toList();
  }

  /// Belirli bir eyalete ait şehirleri getirir
  Future<List<City>> getCitiesByState(int stateId) async {
    final cities = await getCities();
    return cities.where((city) => city.stateId == stateId).toList();
  }

  /// Arama yaparak ülke listesini filtreler
  Future<List<Country>> searchCountries(String query) async {
    final countries = await getCountries();
    if (query.isEmpty) return countries;
    
    return countries
        .where((country) =>
            country.name.toLowerCase().contains(query.toLowerCase()) ||
            country.code.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Arama yaparak eyalet listesini filtreler
  Future<List<StateProvince>> searchStates(String query, int countryId) async {
    final states = await getStatesByCountry(countryId);
    if (query.isEmpty) return states;
    
    return states
        .where((state) =>
            state.name.toLowerCase().contains(query.toLowerCase()) ||
            state.code.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Arama yaparak şehir listesini filtreler
  Future<List<City>> searchCities(String query, int stateId) async {
    final cities = await getCitiesByState(stateId);
    if (query.isEmpty) return cities;
    
    return cities
        .where((city) =>
            city.name.toLowerCase().contains(query.toLowerCase()) ||
            city.code.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Tüm şehirler içinde arama yapar (ana ekrandaki gibi)
  Future<List<City>> searchAllCities(String query) async {
    final cities = await getCities();
    if (query.isEmpty) return [];
    
    return cities
        .where((city) =>
            city.name.toLowerCase().contains(query.toLowerCase()) ||
            city.code.toLowerCase().contains(query.toLowerCase()))
        .take(20) // İlk 20 sonucu göster
        .toList();
  }

  /// Şehir ID'sine göre tam konum bilgilerini getirir
  Future<SelectedLocation?> getLocationByCityId(int cityId) async {
    try {
      final cities = await getCities();
      final city = cities.firstWhere((c) => c.id == cityId);
      
      final states = await getStates();
      final state = states.firstWhere((s) => s.id == city.stateId);
      
      final countries = await getCountries();
      final country = countries.firstWhere((c) => c.id == state.countryId);
      
      return SelectedLocation(
        country: country,
        state: state,
        city: city,
      );
    } catch (e) {
      return null;
    }
  }

  /// Varsayılan olarak Türkiye'yi döndürür
  Future<Country> getDefaultCountry() async {
    final countries = await getCountries();
    return countries.firstWhere(
      (country) => country.code == 'TÜRKİYE',
      orElse: () => countries.first,
    );
  }

  /// Varsayılan olarak İstanbul'u döndürür
  Future<StateProvince> getDefaultState() async {
    final states = await getStates();
    return states.firstWhere(
      (state) => state.code == 'ISTANBUL',
      orElse: () => states.first,
    );
  }

  /// GPS konum iznini kontrol eder
  Future<bool> checkLocationPermission() async {
    final permission = await Permission.location.status;
    if (permission.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return permission.isGranted;
  }

  /// Mevcut GPS konumunu alır
  Future<Position?> getCurrentLocation() async {
    try {
      // İzin kontrolü
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        throw Exception('Konum izni reddedildi');
      }

      // Konum servisinin aktif olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı');
      }

      // Mevcut konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 30),
      );

      return position;
    } catch (e) {
      throw Exception('GPS konumu alınamadı: $e');
    }
  }

  String _normalize(String s) {
    return s.toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll(RegExp(r'i\u0307'), 'i');
  }

  /// GPS koordinatlarına en yakın şehri bulur
  Future<SelectedLocation?> findNearestLocation(Position position) async {
    try {
      // Reverse geocoding ile en yakın konumu al
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;

      // Ülke bul
      final countries = await getCountries();
      final defaultCountry = await getDefaultCountry();
      final placeCountry = place.country ?? '';
      final matchedCountry = countries.firstWhere(
        (c) => _normalize(c.name) == _normalize(placeCountry),
        orElse: () => defaultCountry,
      );

      // Eyalet bul
      final states = await getStatesByCountry(matchedCountry.id);
      final placeState = place.administrativeArea ?? '';
      final matchedState = states.firstWhere(
        (s) => _normalize(s.name) == _normalize(placeState),
        orElse: () {
          return states.firstWhere(
            (s) => _normalize(placeState).contains(_normalize(s.name)) || _normalize(s.name).contains(_normalize(placeState)),
            orElse: () => states.first,
          );
        },
      );

      // Şehir bul
      final cities = await getCitiesByState(matchedState.id);
      final placeCity = place.locality ?? '';
      final placeSub = place.subAdministrativeArea ?? '';
      final matchedCity = cities.firstWhere(
        (c) => _normalize(c.name) == _normalize(placeCity),
        orElse: () {
          return cities.firstWhere(
            (c) => _normalize(c.name) == _normalize(placeSub),
            orElse: () => cities.firstWhere(
              (c) => _normalize(c.name).contains(_normalize(placeCity)) || _normalize(placeCity).contains(_normalize(c.name)),
              orElse: () => cities.first,
            ),
          );
        },
      );

      return SelectedLocation(
        country: matchedCountry,
        state: matchedState,
        city: matchedCity,
      );
    } catch (e) {
      throw Exception('En yakın konum bulunamadı: $e');
    }
  }

  /// Seçili konumu kaydeder
  Future<void> saveSelectedLocation(SelectedLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ülke bilgisini kaydet
      await prefs.setString(_selectedCountryKey, json.encode(location.country.toJson()));
      
      // Eyalet bilgisini kaydet
      await prefs.setString(_selectedStateKey, json.encode(location.state.toJson()));
      
      // Şehir bilgisini kaydet
      await prefs.setString(_selectedCityKey, json.encode(location.city.toJson()));
      // History listesine ekle
      await addLocationToHistory(location);
    } catch (e) {
      throw Exception('Konum kaydedilirken hata oluştu: $e');
    }
  }

  /// Kaydedilen konumu yükler
  Future<SelectedLocation?> loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Kaydedilen verileri kontrol et
      final countryJson = prefs.getString(_selectedCountryKey);
      final stateJson = prefs.getString(_selectedStateKey);
      final cityJson = prefs.getString(_selectedCityKey);
      
      if (countryJson == null || stateJson == null || cityJson == null) {
        return null;
      }
      
      // JSON'dan nesnelere dönüştür
      final country = Country.fromJson(json.decode(countryJson));
      final state = StateProvince.fromJson(json.decode(stateJson));
      final city = City.fromJson(json.decode(cityJson));
      
      return SelectedLocation(
        country: country,
        state: state,
        city: city,
      );
    } catch (e) {
      // Hata durumunda kaydedilen verileri temizle
      await clearSavedLocation();
      return null;
    }
  }

  /// Load the history of selected locations
  Future<List<SelectedLocation>> loadLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_historyKey);
    if (jsonList == null) return [];
    return jsonList.map((item) {
      final map = json.decode(item) as Map<String, dynamic>;
      return SelectedLocation.fromJson(map);
    }).toList();
  }

  /// Adds a selected location to history, deduplicating entries
  Future<void> addLocationToHistory(SelectedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_historyKey) ?? [];
    // Remove any existing entry for the same city
    list.removeWhere((element) {
      try {
        final map = json.decode(element) as Map<String, dynamic>;
        final city = City.fromJson(map['city'] as Map<String, dynamic>);
        return city.id == location.city.id;
      } catch (_) {
        return false;
      }
    });
    // Insert new entry at the front
    list.insert(0, json.encode(location.toJson()));
    await prefs.setStringList(_historyKey, list);
  }

  /// Removes a selected location from history
  Future<void> removeLocationFromHistory(SelectedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_historyKey) ?? [];
    // Remove any existing entry for the same city
    list.removeWhere((element) {
      try {
        final map = json.decode(element) as Map<String, dynamic>;
        final city = City.fromJson(map['city'] as Map<String, dynamic>);
        return city.id == location.city.id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_historyKey, list);
  }

  /// Kaydedilen konumu temizler
  Future<void> clearSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedCountryKey);
      await prefs.remove(_selectedStateKey);
      await prefs.remove(_selectedCityKey);
    } catch (e) {
      throw Exception('Kaydedilen konum temizlenirken hata oluştu: $e');
    }
  }

  /// Kaydedilen konum var mı kontrol eder
  Future<bool> hasSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedCountryKey) != null &&
             prefs.getString(_selectedStateKey) != null &&
             prefs.getString(_selectedCityKey) != null;
    } catch (e) {
      return false;
    }
  }
} 