import 'package:flutter/foundation.dart';

@immutable
class LocalizedQuote {
  final String text;
  final String source;

  const LocalizedQuote({required this.text, required this.source});

  factory LocalizedQuote.fromMap(Map<String, dynamic> map) {
    return LocalizedQuote(
      text: (map['text'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'source': source,
      };
}

@immutable
class DailyContent {
  final String id;
  final Map<String, LocalizedQuote> locales; // e.g. "tr", "ar", "en"

  const DailyContent({required this.id, required this.locales});

  factory DailyContent.fromFirestore(Map<String, dynamic> data) {
    final locs = <String, LocalizedQuote>{};
    for (final key in ['tr', 'ar', 'en']) {
      final raw = data[key];
      if (raw is Map<String, dynamic>) {
        locs[key] = LocalizedQuote.fromMap(raw);
      }
    }
    return DailyContent(
      id: (data['id'] ?? '').toString(),
      locales: Map.unmodifiable(locs),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        for (final entry in locales.entries) entry.key: entry.value.toMap(),
      };
}
