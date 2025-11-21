import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class NotificationSetting {
  final String id;
  final String title;
  final bool enabled;
  final int minutes;
  final bool pickerVisible;
  final String sound;
  final bool soundPickerVisible;

  const NotificationSetting({
    required this.id,
    required this.title,
    this.enabled = true,
    this.minutes = 5,
    this.pickerVisible = false,
    this.sound = 'default',
    this.soundPickerVisible = false,
  });

  NotificationSetting copyWith({
    bool? enabled,
    int? minutes,
    bool? pickerVisible,
    String? sound,
    bool? soundPickerVisible,
  }) {
    return NotificationSetting(
      id: id,
      title: title,
      enabled: enabled ?? this.enabled,
      minutes: minutes ?? this.minutes,
      pickerVisible: pickerVisible ?? this.pickerVisible,
      sound: sound ?? this.sound,
      soundPickerVisible: soundPickerVisible ?? this.soundPickerVisible,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSetting &&
        other.id == id &&
        other.enabled == enabled &&
        other.minutes == minutes &&
        other.pickerVisible == pickerVisible &&
        other.sound == sound &&
        other.soundPickerVisible == soundPickerVisible;
  }
  
  @override
  int get hashCode {
    return Object.hash(id, enabled, minutes, pickerVisible, sound, soundPickerVisible);
  }
}

/// Bildirim ayarlarını yöneten singleton service
class NotificationSettingsService extends ChangeNotifier {
  static final NotificationSettingsService _instance = NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  List<NotificationSetting> _settings = [];
  bool _isLoaded = false;

  List<NotificationSetting> get settings => List.unmodifiable(_settings);
  bool get isLoaded => _isLoaded;

  /// Ayarları yükle (sadece bir kez)
  Future<void> loadSettings() async {
    if (_isLoaded) {
      if (kDebugMode) {
        print('NotificationSettingsService: Settings already loaded');
      }
      return;
    }

    if (kDebugMode) {
      print('NotificationSettingsService: Loading settings...');
    }

    // Varsayılan ayarları oluştur
    _settings = [
      const NotificationSetting(id: 'imsak', title: 'İmsak', minutes: 5),
      const NotificationSetting(id: 'gunes', title: 'Güneş', minutes: 0),
      const NotificationSetting(id: 'ogle', title: 'Öğle', minutes: 5),
      const NotificationSetting(id: 'ikindi', title: 'İkindi', minutes: 5),
      const NotificationSetting(id: 'aksam', title: 'Akşam', minutes: 5),
      const NotificationSetting(id: 'yatsi', title: 'Yatsı', minutes: 5),
      const NotificationSetting(id: 'cuma', title: 'Cuma', minutes: 30),
      const NotificationSetting(id: 'dua', title: 'Dua Bildirimi', minutes: 0),
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Kaydedilmiş ayarları yükle
      final Set<String> availableSoundIds =
          SettingsConstants.soundOptions.map((e) => e.id).toSet();

      final List<NotificationSetting> loadedSettings = [];

      for (final setting in _settings) {
        final String base = 'nv_notif_${setting.id}_';
        final bool storedEnabled = prefs.getBool('${base}enabled') ?? setting.enabled;
        final int storedMinutes = prefs.getInt('${base}minutes') ?? setting.minutes;
        final String storedSound = prefs.getString('${base}sound') ?? setting.sound;

        if (kDebugMode) {
          print('NotificationSettingsService: Loading ${setting.id} - enabled: $storedEnabled, minutes: $storedMinutes, sound: $storedSound');
        }

        String sound = storedSound;
        if (!availableSoundIds.contains(sound)) {
          sound = 'default';
        }

        final NotificationSetting candidate = setting.copyWith(
          enabled: storedEnabled,
          minutes: storedMinutes,
          sound: sound,
        );

        final NotificationSetting sanitized = _sanitizeSetting(candidate);
        loadedSettings.add(sanitized);

        if (sanitized.enabled != storedEnabled ||
            sanitized.minutes != storedMinutes ||
            sanitized.sound != storedSound) {
          if (kDebugMode) {
            print('NotificationSettingsService: Adjusted ${setting.id} -> enabled: ${sanitized.enabled}, minutes: ${sanitized.minutes}, sound: ${sanitized.sound}');
          }
          await _persistSetting(sanitized);
        }
      }

      // Ek (çoklu) bildirimleri SharedPreferences anahtarlarından keşfet ve ekle
      final List<NotificationSetting> extraSettings =
          _loadAdditionalSettingsFromPrefs(prefs, loadedSettings, availableSoundIds);

      _settings = [
        ...loadedSettings,
        ...extraSettings,
      ];

      _isLoaded = true;
      notifyListeners();
      
      if (kDebugMode) {
        print('NotificationSettingsService: Settings loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationSettingsService: Error loading settings: $e');
      }
    }
  }

  /// Ayarı güncelle ve kaydet
  Future<void> updateSetting(String id, NotificationSetting newSetting) async {
    final sanitized = _sanitizeSetting(newSetting);
    final index = _settings.indexWhere((setting) => setting.id == id);
    if (index != -1) {
      _settings[index] = sanitized;
    } else {
      // Daha önce olmayan (ör. imsak_1) yeni bir bildirim ekleniyorsa listeye ekle
      _settings.add(sanitized);
    }
    notifyListeners();

    // Servis henüz yüklenmemiş olsa bile kalıcılığı garanti et
    await _persistSetting(sanitized);
  }

  /// Picker görünürlüğünü güncelle (kaydetme)
  void updatePickerVisibility(String id, {bool? pickerVisible, bool? soundPickerVisible}) {
    final index = _settings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    _settings[index] = _settings[index].copyWith(
      pickerVisible: pickerVisible,
      soundPickerVisible: soundPickerVisible,
    );
    notifyListeners();
  }

  /// Tüm picker'ları kapat
  void closeAllPickers() {
    for (int i = 0; i < _settings.length; i++) {
      _settings[i] = _settings[i].copyWith(
        pickerVisible: false,
        soundPickerVisible: false,
      );
    }
    notifyListeners();
  }

  /// ID'ye göre ayar getir
  NotificationSetting? getSetting(String id) {
    try {
      return _settings.firstWhere((setting) => setting.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Ayarı SharedPreferences'a kaydet
  Future<void> _persistSetting(NotificationSetting setting) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String base = 'nv_notif_${setting.id}_';
      
      if (kDebugMode) {
        print('NotificationSettingsService: Saving ${setting.id} - enabled: ${setting.enabled}, minutes: ${setting.minutes}, sound: ${setting.sound}');
      }
      
      await prefs.setBool('${base}enabled', setting.enabled);
      await prefs.setInt('${base}minutes', setting.minutes);
      await prefs.setString('${base}sound', setting.sound);
      
      // Kaydetme işleminin tamamlandığından emin olmak için reload et
      await prefs.reload();
      
      if (kDebugMode) {
        print('NotificationSettingsService: Successfully saved ${setting.id}');
        // Doğrulama: Kaydedilen değeri oku ve kontrol et
        final savedMinutes = prefs.getInt('${base}minutes');
        print('NotificationSettingsService: Verification - saved minutes value: $savedMinutes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationSettingsService: Error saving ${setting.id}: $e');
      }
    }
  }

  NotificationSetting _sanitizeSetting(NotificationSetting setting) {
    // Cuma için minimum dakikayı baz alan liste, diğerleri için ortak liste
    List<int> minutesList = setting.id == 'cuma'
        ? SettingsConstants.notificationMinutes.where((m) => m >= 15).toList()
        : List<int>.from(SettingsConstants.notificationMinutes);

    if (minutesList.isEmpty) {
      minutesList = <int>[setting.id == 'cuma' ? 15 : setting.minutes];
    } else {
      minutesList.sort();
    }

    int minutes = setting.minutes;
    if (!minutesList.contains(minutes)) {
      minutes = _nearestSupportedMinute(minutes, minutesList);
    }

    if (setting.id == 'cuma' && minutes < 15) {
      minutes = 15;
    }

    if (minutes != setting.minutes) {
      return setting.copyWith(minutes: minutes);
    }
    return setting;
  }

  /// SharedPreferences içindeki nv_notif_* anahtarlarından, varsayılan listede olmayan
  /// ek bildirimleri (ör. imsak_1, imsak_2) keşfeder.
  List<NotificationSetting> _loadAdditionalSettingsFromPrefs(
    SharedPreferences prefs,
    List<NotificationSetting> baseSettings,
    Set<String> availableSoundIds,
  ) {
    final List<NotificationSetting> extras = [];
    final Set<String> processedIds = {};
    final Map<String, NotificationSetting> baseById = {
      for (final s in baseSettings) s.id: s,
    };

    final keys = prefs.getKeys();

    for (final baseEntry in baseById.entries) {
      final String baseId = baseEntry.key;
      final NotificationSetting baseSetting = baseEntry.value;
      final RegExp pattern =
          RegExp('^nv_notif_${RegExp.escape(baseId)}_(\\d+)_enabled\$');

      for (final key in keys) {
        final match = pattern.firstMatch(key);
        if (match == null) continue;

        final String suffix = match.group(1) ?? '';
        if (suffix.isEmpty) continue;

        final String extraId = '${baseId}_$suffix';
        if (processedIds.contains(extraId)) continue;
        processedIds.add(extraId);

        final String prefBase = 'nv_notif_${extraId}_';
        final bool storedEnabled =
            prefs.getBool('${prefBase}enabled') ?? baseSetting.enabled;
        final int storedMinutes =
            prefs.getInt('${prefBase}minutes') ?? baseSetting.minutes;
        final String storedSound =
            prefs.getString('${prefBase}sound') ?? baseSetting.sound;

        String sound = storedSound;
        if (!availableSoundIds.contains(sound)) {
          sound = 'default';
        }

        final NotificationSetting candidate = NotificationSetting(
          id: extraId,
          title: baseSetting.title,
          enabled: storedEnabled,
          minutes: storedMinutes,
          pickerVisible: false,
          sound: sound,
          soundPickerVisible: false,
        );

        final NotificationSetting sanitized = _sanitizeSetting(candidate);
        extras.add(sanitized);
      }
    }

    if (kDebugMode && extras.isNotEmpty) {
      print(
        'NotificationSettingsService: Loaded additional settings from prefs: '
        '${extras.map((e) => e.id).toList()}',
      );
    }

    return extras;
  }

  int _nearestSupportedMinute(int value, List<int> list) {
    if (list.isEmpty) return value;
    int best = list.first;
    int bestDiff = (value - best).abs();
    for (final m in list) {
      final d = (value - m).abs();
      if (d < bestDiff || (d == bestDiff && m < best)) {
        best = m;
        bestDiff = d;
      }
    }
    return best;
  }
}
