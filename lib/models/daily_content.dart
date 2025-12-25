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

class DailyContent {
  final int id;
  final Map<String, LocalizedQuote> locales; // e.g. "tr", "ar", "en"

  const DailyContent({required this.id, required this.locales});

  factory DailyContent.fromFirestore(Map<String, dynamic> data) {
    final Map<String, LocalizedQuote> locs = {};
    for (final key in ['tr', 'ar', 'en']) {
      final raw = data[key];
      if (raw is Map<String, dynamic>) {
        locs[key] = LocalizedQuote.fromMap(raw);
      }
    }
    return DailyContent(
      id: (data['id'] ?? 0) is int ? data['id'] as int : int.tryParse('${data['id']}') ?? 0,
      locales: locs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        for (final entry in locales.entries) entry.key: entry.value.toMap(),
      };
}


