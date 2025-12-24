class DetectedReligiousDay {
  final DateTime gregorianDate;
  final String gregorianDateShort; // e.g. 01.01.2025
  final String hijriDateLong; // e.g. 12 Rebiülevvel 1447
  final String eventName; // e.g. Mevlid Kandili

  DetectedReligiousDay({
    required this.gregorianDate,
    required this.gregorianDateShort,
    required this.hijriDateLong,
    required this.eventName,
  });
}


