import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/app_keys.dart';
import '../utils/app_logger.dart';

/// Tek bir bildirim ayarını temsil eder.
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
    String? title,
    bool? enabled,
    int? minutes,
    bool? pickerVisible,
    String? sound,
    bool? soundPickerVisible,
  }) {
    return NotificationSetting(
      id: id,
      title: title ?? this.title,
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

  @override
  String toString() => 'NotificationSetting(id: $id, enabled: $enabled, minutes: $minutes)';
}

/// Bildirim ayarlarını yöneten singleton servis.
///
/// Bu servis şunları yönetir:
/// - Namaz vakti bildirimleri (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı)
/// - Cuma bildirimi
/// - Dua bildirimi
/// - Her bildirim için dakika ve ses ayarları
class NotificationSettingsService extends ChangeNotifier {
  static final NotificationSettingsService _instance = NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  List<NotificationSetting> _settings = [];
  bool _isLoaded = false;
  SharedPreferences? _prefsCache;

  List<NotificationSetting> get settings => List.unmodifiable(_settings);
  bool get isLoaded => _isLoaded;

  /// Varsayılan bildirim ayarları
  static const List<NotificationSetting> _defaultSettings = [
    NotificationSetting(id: AppKeys.notifIdImsak, title: 'İmsak', minutes: 5),
    NotificationSetting(id: AppKeys.notifIdGunes, title: 'Güneş', minutes: 0),
    NotificationSetting(id: AppKeys.notifIdOgle, title: 'Öğle', minutes: 5),
    NotificationSetting(id: AppKeys.notifIdIkindi, title: 'İkindi', minutes: 5),
    NotificationSetting(id: AppKeys.notifIdAksam, title: 'Akşam', minutes: 5),
    NotificationSetting(id: AppKeys.notifIdYatsi, title: 'Yatsı', minutes: 5),
    NotificationSetting(id: AppKeys.notifIdCuma, title: 'Cuma', minutes: 30),
    NotificationSetting(id: AppKeys.notifIdDua, title: 'Dua Bildirimi', minutes: 0),
  ];

  /// Ayarları yükler (sadece bir kez).
  Future<void> loadSettings() async {
    if (_isLoaded) {
      AppLogger.debug('Settings already loaded', tag: 'NotificationSettings');
      return;
    }

    final stopwatch = AppLogger.startTimer('NotificationSettings.loadSettings');

    // Varsayılan ayarları başlat
    _settings = List.from(_defaultSettings);

    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      final prefs = _prefsCache!;

      final Set<String> availableSoundIds =
          SettingsConstants.soundOptions.map((e) => e.id).toSet();

      final List<NotificationSetting> loadedSettings = [];

      for (final setting in _settings) {
        final loadedSetting = _loadSettingFromPrefs(prefs, setting, availableSoundIds);
        loadedSettings.add(loadedSetting);
      }

      // Ek (çoklu) bildirimleri keşfet ve ekle
      final List<NotificationSetting> extraSettings =
          _loadAdditionalSettingsFromPrefs(prefs, loadedSettings, availableSoundIds);

      _settings = [
        ...loadedSettings,
        ...extraSettings,
      ];

      _isLoaded = true;
      notifyListeners();

      AppLogger.stopTimer(stopwatch, 'NotificationSettings.loadSettings');
      AppLogger.success('Loaded ${_settings.length} notification settings', tag: 'NotificationSettings');
    } catch (e, stackTrace) {
      AppLogger.error('Error loading settings', tag: 'NotificationSettings', error: e, stackTrace: stackTrace);
      _isLoaded = true; // Hata olsa bile varsayılanlarla devam et
    }
  }

  /// Tek bir ayarı SharedPreferences'tan yükler.
  NotificationSetting _loadSettingFromPrefs(
    SharedPreferences prefs,
    NotificationSetting setting,
    Set<String> availableSoundIds,
  ) {
    final String base = '${AppKeys.notificationPrefix}${setting.id}_';
    final bool storedEnabled = prefs.getBool('${base}enabled') ?? setting.enabled;
    final int storedMinutes = prefs.getInt('${base}minutes') ?? setting.minutes;
    final String storedSound = prefs.getString('${base}sound') ?? setting.sound;

    String sound = storedSound;
    if (!availableSoundIds.contains(sound)) {
      sound = 'default';
    }

    final NotificationSetting candidate = setting.copyWith(
      enabled: storedEnabled,
      minutes: storedMinutes,
      sound: sound,
    );

    return _sanitizeSetting(candidate);
  }

  /// Ayarı günceller ve kaydeder.
  Future<void> updateSetting(String id, NotificationSetting newSetting) async {
    final sanitized = _sanitizeSetting(newSetting);
    final index = _settings.indexWhere((setting) => setting.id == id);

    if (index != -1) {
      _settings[index] = sanitized;
    } else {
      // Yeni bildirim ekleniyor
      _settings.add(sanitized);
    }

    notifyListeners();
    await _persistSetting(sanitized);
  }

  /// Picker görünürlüğünü günceller (kaydetmez).
  void updatePickerVisibility(String id, {bool? pickerVisible, bool? soundPickerVisible}) {
    final index = _settings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    _settings[index] = _settings[index].copyWith(
      pickerVisible: pickerVisible,
      soundPickerVisible: soundPickerVisible,
    );
    notifyListeners();
  }

  /// Tüm picker'ları kapatır.
  void closeAllPickers() {
    for (int i = 0; i < _settings.length; i++) {
      _settings[i] = _settings[i].copyWith(
        pickerVisible: false,
        soundPickerVisible: false,
      );
    }
    notifyListeners();
  }

  /// ID'ye göre ayar getirir.
  NotificationSetting? getSetting(String id) {
    try {
      return _settings.firstWhere((setting) => setting.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Ayarı SharedPreferences'a kaydeder.
  Future<void> _persistSetting(NotificationSetting setting) async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      final prefs = _prefsCache!;
      final String base = '${AppKeys.notificationPrefix}${setting.id}_';

      await Future.wait([
        prefs.setBool('${base}enabled', setting.enabled),
        prefs.setInt('${base}minutes', setting.minutes),
        prefs.setString('${base}sound', setting.sound),
      ]);

      await prefs.reload();

      AppLogger.debug('Saved ${setting.id}: enabled=${setting.enabled}, minutes=${setting.minutes}', tag: 'NotificationSettings');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving ${setting.id}', tag: 'NotificationSettings', error: e, stackTrace: stackTrace);
    }
  }

  /// Ayarı geçerli değerlerle düzenler.
  NotificationSetting _sanitizeSetting(NotificationSetting setting) {
    // Cuma için minimum dakikayı 15, diğerleri için normal liste
    List<int> minutesList = setting.id == AppKeys.notifIdCuma
        ? SettingsConstants.notificationMinutes.where((m) => m >= 15).toList()
        : List<int>.from(SettingsConstants.notificationMinutes);

    if (minutesList.isEmpty) {
      minutesList = <int>[setting.id == AppKeys.notifIdCuma ? 15 : setting.minutes];
    } else {
      minutesList.sort();
    }

    int minutes = setting.minutes;
    if (!minutesList.contains(minutes)) {
      minutes = _nearestSupportedMinute(minutes, minutesList);
    }

    if (setting.id == AppKeys.notifIdCuma && minutes < 15) {
      minutes = 15;
    }

    if (minutes != setting.minutes) {
      return setting.copyWith(minutes: minutes);
    }
    return setting;
  }

  /// SharedPreferences'tan ek bildirimleri (imsak_1, imsak_2, vb.) keşfeder.
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
          RegExp('^${RegExp.escape(AppKeys.notificationPrefix)}${RegExp.escape(baseId)}_(\\d+)_enabled\$');

      for (final key in keys) {
        final match = pattern.firstMatch(key);
        if (match == null) continue;

        final String suffix = match.group(1) ?? '';
        if (suffix.isEmpty) continue;

        final String extraId = '${baseId}_$suffix';
        if (processedIds.contains(extraId)) continue;
        processedIds.add(extraId);

        final String prefBase = '${AppKeys.notificationPrefix}${extraId}_';
        final bool storedEnabled = prefs.getBool('${prefBase}enabled') ?? baseSetting.enabled;
        final int storedMinutes = prefs.getInt('${prefBase}minutes') ?? baseSetting.minutes;
        final String storedSound = prefs.getString('${prefBase}sound') ?? baseSetting.sound;

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

        extras.add(_sanitizeSetting(candidate));
      }
    }

    if (extras.isNotEmpty) {
      AppLogger.debug('Loaded ${extras.length} additional settings: ${extras.map((e) => e.id).toList()}', tag: 'NotificationSettings');
    }

    return extras;
  }

  /// Desteklenen değere en yakın dakikayı bulur.
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
