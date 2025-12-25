// Location model sınıflarını import et
import 'location_model.dart';

class PrayerTimesResponse {
  final int cityId;
  final CityInfo cityInfo;
  final int year;
  final int totalDays;
  final String generatedAt;
  final List<PrayerTime> prayerTimes;

  PrayerTimesResponse({
    required this.cityId,
    required this.cityInfo,
    required this.year,
    required this.totalDays,
    required this.generatedAt,
    required this.prayerTimes,
  });

  factory PrayerTimesResponse.fromJson(Map<String, dynamic> json) {
    return PrayerTimesResponse(
      cityId: json['cityId'] ?? 0,
      cityInfo: CityInfo.fromJson(json['cityInfo'] ?? {}),
      year: json['year'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      generatedAt: json['generatedAt'] ?? '',
      prayerTimes: (json['prayerTimes'] as List<dynamic>?)
          ?.map((e) => PrayerTime.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'cityInfo': cityInfo.toJson(),
      'year': year,
      'totalDays': totalDays,
      'generatedAt': generatedAt,
      'prayerTimes': prayerTimes.map((e) => e.toJson()).toList(),
    };
  }
}

class CityInfo {
  final City city;
  final StateProvince state;
  final Country country;
  final String fullName;

  CityInfo({
    required this.city,
    required this.state,
    required this.country,
    required this.fullName,
  });

  factory CityInfo.fromJson(Map<String, dynamic> json) {
    return CityInfo(
      city: City.fromJson(json['city'] ?? {}),
      state: StateProvince.fromJson(json['state'] ?? {}),
      country: Country.fromJson(json['country'] ?? {}),
      fullName: json['fullName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city.toJson(),
      'state': state.toJson(),
      'country': country.toJson(),
      'fullName': fullName,
    };
  }
}

class PrayerTime {
  final String shapeMoonUrl;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String astronomicalSunset;
  final String astronomicalSunrise;
  final String hijriDateShort;
  final String? hijriDateShortIso8601;
  final String hijriDateLong;
  final String? hijriDateLongIso8601;
  final String qiblaTime;
  final String gregorianDateShort;
  final String gregorianDateShortIso8601;
  final String gregorianDateLong;
  final String gregorianDateLongIso8601;
  final int greenwichMeanTimeZone;

  PrayerTime({
    required this.shapeMoonUrl,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.astronomicalSunset,
    required this.astronomicalSunrise,
    required this.hijriDateShort,
    this.hijriDateShortIso8601,
    required this.hijriDateLong,
    this.hijriDateLongIso8601,
    required this.qiblaTime,
    required this.gregorianDateShort,
    required this.gregorianDateShortIso8601,
    required this.gregorianDateLong,
    required this.gregorianDateLongIso8601,
    required this.greenwichMeanTimeZone,
  });

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      shapeMoonUrl: json['shapeMoonUrl'] ?? '',
      fajr: json['fajr'] ?? '',
      sunrise: json['sunrise'] ?? '',
      dhuhr: json['dhuhr'] ?? '',
      asr: json['asr'] ?? '',
      maghrib: json['maghrib'] ?? '',
      isha: json['isha'] ?? '',
      astronomicalSunset: json['astronomicalSunset'] ?? '',
      astronomicalSunrise: json['astronomicalSunrise'] ?? '',
      hijriDateShort: json['hijriDateShort'] ?? '',
      hijriDateShortIso8601: json['hijriDateShortIso8601'],
      hijriDateLong: json['hijriDateLong'] ?? '',
      hijriDateLongIso8601: json['hijriDateLongIso8601'],
      qiblaTime: json['qiblaTime'] ?? '',
      gregorianDateShort: json['gregorianDateShort'] ?? '',
      gregorianDateShortIso8601: json['gregorianDateShortIso8601'] ?? '',
      gregorianDateLong: json['gregorianDateLong'] ?? '',
      gregorianDateLongIso8601: json['gregorianDateLongIso8601'] ?? '',
      greenwichMeanTimeZone: json['greenwichMeanTimeZone'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shapeMoonUrl': shapeMoonUrl,
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'astronomicalSunset': astronomicalSunset,
      'astronomicalSunrise': astronomicalSunrise,
      'hijriDateShort': hijriDateShort,
      'hijriDateShortIso8601': hijriDateShortIso8601,
      'hijriDateLong': hijriDateLong,
      'hijriDateLongIso8601': hijriDateLongIso8601,
      'qiblaTime': qiblaTime,
      'gregorianDateShort': gregorianDateShort,
      'gregorianDateShortIso8601': gregorianDateShortIso8601,
      'gregorianDateLong': gregorianDateLong,
      'gregorianDateLongIso8601': gregorianDateLongIso8601,
      'greenwichMeanTimeZone': greenwichMeanTimeZone,
    };
  }

  /// Bugünün namaz vakitlerini kontrol eder
  bool get isToday {
    final now = DateTime.now();
    final prayerDate = DateTime.tryParse(gregorianDateShortIso8601);
    if (prayerDate == null) return false;
    
    return now.year == prayerDate.year &&
           now.month == prayerDate.month &&
           now.day == prayerDate.day;
  }
}