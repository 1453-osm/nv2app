class Country {
  final int id;
  final String code;
  final String name;
  final String createdAt;
  final String updatedAt;

  Country({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class StateProvince {
  final int id;
  final int countryId;
  final String code;
  final String name;
  final String createdAt;
  final String updatedAt;

  StateProvince({
    required this.id,
    required this.countryId,
    required this.code,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StateProvince.fromJson(Map<String, dynamic> json) {
    return StateProvince(
      id: json['id'],
      countryId: json['country_id'],
      code: json['code'],
      name: json['name'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_id': countryId,
      'code': code,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class City {
  final int id;
  final int stateId;
  final String code;
  final String name;
  final String createdAt;
  final String updatedAt;

  City({
    required this.id,
    required this.stateId,
    required this.code,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      stateId: json['state_id'],
      code: json['code'],
      name: json['name'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'code': code,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SelectedLocation {
  final Country country;
  final StateProvince state;
  final City city;

  SelectedLocation({
    required this.country,
    required this.state,
    required this.city,
  });

  /// Converts this object to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'country': country.toJson(),
      'state': state.toJson(),
      'city': city.toJson(),
    };
  }

  /// Creates a SelectedLocation from a JSON map.
  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    return SelectedLocation(
      country: Country.fromJson(json['country'] as Map<String, dynamic>),
      state: StateProvince.fromJson(json['state'] as Map<String, dynamic>),
      city: City.fromJson(json['city'] as Map<String, dynamic>),
    );
  }

  String get fullLocation => '${city.name}, ${state.name}, ${country.name}';
} 