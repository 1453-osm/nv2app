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
      const NotificationSetting(id: 'dua', title: 'Dua Bildirimi', minutes: 5),
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Kaydedilmiş ayarları yükle
      _settings = _settings.map((setting) {
        final String base = 'nv_notif_${setting.id}_';
        final bool enabled = prefs.getBool('${base}enabled') ?? setting.enabled;
        int minutes = prefs.getInt('${base}minutes') ?? setting.minutes;
        String sound = prefs.getString('${base}sound') ?? setting.sound;
        
        if (kDebugMode) {
          print('NotificationSettingsService: Loading ${setting.id} - enabled: $enabled, minutes: $minutes, sound: $sound');
        }
        
        // Mevcut olmayan ses id'lerini güvenle 'default' ile değiştir
        final Set<String> availableSoundIds =
            SettingsConstants.soundOptions.map((e) => e.id).toSet();
        if (!availableSoundIds.contains(sound)) {
          sound = 'default';
        }
        
        // Dakika değerini desteklenen en yakın değere yuvarla
        if (!SettingsConstants.notificationMinutes.contains(minutes)) {
          minutes = _nearestSupportedMinute(minutes);
        }
        
        return setting.copyWith(
          enabled: enabled,
          minutes: minutes,
          sound: sound,
        );
      }).toList();

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
    final index = _settings.indexWhere((setting) => setting.id == id);
    if (index != -1) {
      _settings[index] = newSetting;
      notifyListeners();
    }

    // Servis henüz yüklenmemiş olsa bile kalıcılığı garanti et
    await _persistSetting(newSetting);
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
      
      if (kDebugMode) {
        print('NotificationSettingsService: Successfully saved ${setting.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationSettingsService: Error saving ${setting.id}: $e');
      }
    }
  }

  int _nearestSupportedMinute(int value) {
    final list = SettingsConstants.notificationMinutes;
    int best = list.first;
    int bestDiff = (value - best).abs();
    for (final m in list) {
      final d = (value - m).abs();
      if (d < bestDiff) {
        best = m;
        bestDiff = d;
      }
    }
    return best;
  }
}
