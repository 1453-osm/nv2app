import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nv2/models/location_model.dart';

void main() {
  group('Country', () {
    test('fromJson creates Country correctly', () {
      final json = {
        'id': 1,
        'code': 'TR',
        'name': 'Türkiye',
        'name_ar': 'تركيا',
        'created_at': '2024-01-01',
        'updated_at': '2024-01-01',
      };

      final country = Country.fromJson(json);

      expect(country.id, 1);
      expect(country.code, 'TR');
      expect(country.name, 'Türkiye');
      expect(country.nameAr, 'تركيا');
    });

    test('toJson serializes correctly', () {
      final country = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        nameAr: 'تركيا',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      final json = country.toJson();

      expect(json['id'], 1);
      expect(json['code'], 'TR');
      expect(json['name'], 'Türkiye');
      expect(json['name_ar'], 'تركيا');
    });

    test('getDisplayName returns Turkish name for tr locale', () {
      final country = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        nameAr: 'تركيا',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(country.getDisplayName(const Locale('tr')), 'Türkiye');
    });

    test('getDisplayName returns Arabic name for ar locale', () {
      final country = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        nameAr: 'تركيا',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(country.getDisplayName(const Locale('ar')), 'تركيا');
    });

    test('getDisplayName falls back to name when nameAr is null', () {
      final country = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        nameAr: null,
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(country.getDisplayName(const Locale('ar')), 'Türkiye');
    });

    test('equality works correctly', () {
      final country1 = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      final country2 = Country(
        id: 1,
        code: 'TR',
        name: 'Turkey',
        createdAt: '2024-01-02',
        updatedAt: '2024-01-02',
      );

      expect(country1, equals(country2)); // Same ID means equal
    });
  });

  group('SelectedLocation', () {
    late Country country;
    late StateProvince state;
    late City city;

    setUp(() {
      country = Country(
        id: 1,
        code: 'TR',
        name: 'Türkiye',
        nameAr: 'تركيا',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      state = StateProvince(
        id: 1,
        countryId: 1,
        code: 'IST',
        name: 'İstanbul',
        nameAr: 'إسطنبول',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      city = City(
        id: 1,
        stateId: 1,
        code: 'KDK',
        name: 'Kadıköy',
        nameAr: 'قاضيكوي',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );
    });

    test('fullLocation returns correct format', () {
      final location = SelectedLocation(
        country: country,
        state: state,
        city: city,
      );

      expect(location.fullLocation, 'Kadıköy, İstanbul, Türkiye');
    });

    test('getFullLocation returns localized names', () {
      final location = SelectedLocation(
        country: country,
        state: state,
        city: city,
      );

      expect(location.getFullLocation(const Locale('ar')), 'قاضيكوي, إسطنبول, تركيا');
    });

    test('toJson and fromJson work correctly', () {
      final location = SelectedLocation(
        country: country,
        state: state,
        city: city,
      );

      final json = location.toJson();
      final restored = SelectedLocation.fromJson(json);

      expect(restored.country.id, location.country.id);
      expect(restored.state.id, location.state.id);
      expect(restored.city.id, location.city.id);
    });
  });
}
