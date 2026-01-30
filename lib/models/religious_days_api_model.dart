/// API'den gelen dini günler verisi için model
class ReligiousDaysApiResponse {
  final int year;
  final int totalEvents;
  final String generatedAt;
  final List<ReligiousDayEvent> events;
  final String? source;

  ReligiousDaysApiResponse({
    required this.year,
    required this.totalEvents,
    required this.generatedAt,
    required this.events,
    this.source,
  });

  factory ReligiousDaysApiResponse.fromJson(Map<String, dynamic> json) {
    return ReligiousDaysApiResponse(
      year: json['year'] as int,
      totalEvents: json['totalEvents'] as int,
      generatedAt: json['generatedAt'] as String,
      events: (json['events'] as List)
          .map((e) => ReligiousDayEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      source: json['source'] as String?,
    );
  }
}

/// Tek bir dini gün eventi
class ReligiousDayEvent {
  final String event; // e.g. "REGAİB KANDİLİ"
  final String displayName; // e.g. "REGAİB KANDİLİ"
  final String? arefeType; // "ramazan" veya "kurban"
  final HijriDate hijri;
  final MiladiDate miladi;
  final String weekday; // e.g. "PERŞEMBE"
  final String? source;
  final String? fetchedAt;

  ReligiousDayEvent({
    required this.event,
    required this.displayName,
    this.arefeType,
    required this.hijri,
    required this.miladi,
    required this.weekday,
    this.source,
    this.fetchedAt,
  });

  factory ReligiousDayEvent.fromJson(Map<String, dynamic> json) {
    return ReligiousDayEvent(
      event: json['event'] as String,
      displayName: json['displayName'] as String? ?? json['event'] as String,
      arefeType: json['arefeType'] as String?,
      hijri: HijriDate.fromJson(json['hijri'] as Map<String, dynamic>),
      miladi: MiladiDate.fromJson(json['miladi'] as Map<String, dynamic>),
      weekday: json['weekday'] as String,
      source: json['source'] as String?,
      fetchedAt: json['fetchedAt'] as String?,
    );
  }
}

/// Hicri tarih
class HijriDate {
  final String day; // "01", "02", etc.
  final String month; // "RECEB", "RAMAZAN", etc.
  final String year; // "1446"

  HijriDate({
    required this.day,
    required this.month,
    required this.year,
  });

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      day: json['day'] as String,
      month: json['month'] as String,
      year: json['year'] as String,
    );
  }
}

/// Miladi (Gregoryen) tarih
class MiladiDate {
  final String day; // "01", "02", etc.
  final String month; // "OCAK", "ŞUBAT", etc.
  final String year; // "2025"

  MiladiDate({
    required this.day,
    required this.month,
    required this.year,
  });

  factory MiladiDate.fromJson(Map<String, dynamic> json) {
    return MiladiDate(
      day: json['day'] as String,
      month: json['month'] as String,
      year: json['year'] as String,
    );
  }
}
