import 'package:flutter/material.dart';

/// Konum entity'leri için ortak özellikler.
/// DRY prensibine uygun olarak tekrarlanan kod kaldırıldı.
mixin LocalizableEntity {
  /// Entity'nin varsayılan adı
  String get name;

  /// Entity'nin Arapça adı (nullable)
  String? get nameAr;

  /// Locale'e göre görünen adı döndürür.
  /// Arapça locale için nameAr kullanılır, yoksa name döner.
  String getDisplayName(Locale locale) {
    if (locale.languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    return name;
  }
}

/// Ülke modeli
class Country with LocalizableEntity {
  final int id;
  final String code;
  @override
  final String name;
  @override
  final String? nameAr;
  final String createdAt;
  final String updatedAt;

  Country({
    required this.id,
    required this.code,
    required this.name,
    this.nameAr,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'name_ar': nameAr,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Country(id: $id, name: $name)';
}

/// Eyalet/İl modeli
class StateProvince with LocalizableEntity {
  final int id;
  final int countryId;
  final String code;
  @override
  final String name;
  @override
  final String? nameAr;
  final String createdAt;
  final String updatedAt;

  StateProvince({
    required this.id,
    required this.countryId,
    required this.code,
    required this.name,
    this.nameAr,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StateProvince.fromJson(Map<String, dynamic> json) {
    return StateProvince(
      id: json['id'] as int? ?? 0,
      countryId: json['country_id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_id': countryId,
      'code': code,
      'name': name,
      'name_ar': nameAr,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateProvince && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StateProvince(id: $id, name: $name)';
}

/// Şehir modeli
class City with LocalizableEntity {
  final int id;
  final int stateId;
  final String code;
  @override
  final String name;
  @override
  final String? nameAr;
  final String createdAt;
  final String updatedAt;

  City({
    required this.id,
    required this.stateId,
    required this.code,
    required this.name,
    this.nameAr,
    required this.createdAt,
    required this.updatedAt,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as int? ?? 0,
      stateId: json['state_id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'code': code,
      'name': name,
      'name_ar': nameAr,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'City(id: $id, name: $name)';
}

/// Seçili konum bilgisi (Ülke + İl + Şehir)
class SelectedLocation {
  final Country country;
  final StateProvince state;
  final City city;

  SelectedLocation({
    required this.country,
    required this.state,
    required this.city,
  });

  /// JSON'a çevirir
  Map<String, dynamic> toJson() {
    return {
      'country': country.toJson(),
      'state': state.toJson(),
      'city': city.toJson(),
    };
  }

  /// JSON'dan oluşturur
  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    return SelectedLocation(
      country: Country.fromJson(json['country'] as Map<String, dynamic>),
      state: StateProvince.fromJson(json['state'] as Map<String, dynamic>),
      city: City.fromJson(json['city'] as Map<String, dynamic>),
    );
  }

  /// Varsayılan dilde tam konum adı
  String get fullLocation => '${city.name}, ${state.name}, ${country.name}';

  /// Locale'e göre tam konum adı
  String getFullLocation(Locale locale) {
    return '${city.getDisplayName(locale)}, ${state.getDisplayName(locale)}, ${country.getDisplayName(locale)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedLocation &&
          runtimeType == other.runtimeType &&
          country == other.country &&
          state == other.state &&
          city == other.city;

  @override
  int get hashCode => Object.hash(country, state, city);

  @override
  String toString() => 'SelectedLocation($fullLocation)';
}
