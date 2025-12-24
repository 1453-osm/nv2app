import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_bridge.dart';
import '../utils/constants.dart';

enum ThemeColorMode { static, dynamic, system, black, amoled }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Tema rengi durumu
  ThemeColorMode _themeColorMode = ThemeColorMode.static;
  Color _selectedThemeColor = SettingsConstants.defaultThemeColor.color;
  Color _currentThemeColor = SettingsConstants.defaultThemeColor.color;
  
  // Sistem (Material You) dinamik renk şemaları
  ColorScheme? _systemLightScheme;
  ColorScheme? _systemDarkScheme;
  
  // Namaz vakti takibi
  String? _currentPrayerTime;
  
  // Getters
  ThemeColorMode get themeColorMode => _themeColorMode;
  Color get selectedThemeColor => _selectedThemeColor;
  Color get currentThemeColor => _currentThemeColor;
  String? get currentPrayerTime => _currentPrayerTime;

  /// UI bileşenlerinde görünen vurgu rengi.
  /// AMOLED modda, parlaklıktan bağımsız olarak nötr gri döndür.
  Color uiAccentColorFor(Brightness brightness) {
    if (_themeColorMode == ThemeColorMode.amoled) {
      return const Color(0xFFF4F4F4); // nötr gri
    }
    return _currentThemeColor;
  }

  // Tema rengi modunu değiştir
  Future<void> setThemeColorMode(ThemeColorMode mode) async {
    if (_themeColorMode == mode) return;
    
    _themeColorMode = mode;
    await _saveThemeColorMode(mode);
    
    // Dinamik moda geçildiyse hemen rengi güncelle
    if (mode == ThemeColorMode.dynamic) {
      _updateDynamicThemeColor();
    } else if (mode == ThemeColorMode.system) {
      // Sistem dinamik şemaları hazırsa primary üzerinden currentThemeColor'ı güncelle
      final ColorScheme? anyScheme = _systemLightScheme ?? _systemDarkScheme;
      _currentThemeColor = anyScheme?.primary ?? _selectedThemeColor;
    } else if (mode == ThemeColorMode.black) {
      // Karanlık (siyah seed) modunda sadece seedColor siyah yapılır
      _currentThemeColor = Colors.black;
    } else if (mode == ThemeColorMode.amoled) {
      // AMOLED modunda sadece tema (accent) rengi siyah yapılır
      _currentThemeColor = Colors.black;
    } else {
      // Statik moda geçildiyse seçili rengi kullan
      _currentThemeColor = _selectedThemeColor;
    }
    
    // Widget temasıyla senkronize et ve anında güncelle
    _syncWidgetThemeColors();

    notifyListeners();
  }

  // Seçili tema rengini değiştir (statik mod için)
  Future<void> setSelectedThemeColor(Color color) async {
    if (_selectedThemeColor == color) return;
    
    _selectedThemeColor = color;
    await _saveSelectedThemeColor(color);
    
    // Statik moddaysa hemen rengi güncelle
    if (_themeColorMode == ThemeColorMode.static) {
      _currentThemeColor = color;
      // Widget temasıyla senkronize et ve anında güncelle
      _syncWidgetThemeColors();
      notifyListeners();
    }

    // Diğer modlarda da seçilen rengi native taraf için kaydetmek faydalı
    if (_themeColorMode != ThemeColorMode.static) {
      _syncWidgetThemeColors();
    }
  }

  // Dinamik tema rengini güncelle
  void _updateDynamicThemeColor() {
    if (_themeColorMode != ThemeColorMode.dynamic) return;
    
    final currentPrayer = _getCurrentPrayerTime();
    final newColor = _getPrayerColor(currentPrayer);
    
    if (_currentThemeColor != newColor || _currentPrayerTime != currentPrayer) {
      _currentThemeColor = newColor;
      _currentPrayerTime = currentPrayer;
      // Widget temasıyla senkronize et ve anında güncelle
      _syncWidgetThemeColors();
      notifyListeners();
    }
  }

  // Namaz vakti değişikliğini kontrol et ve gerekirse güncelle
  void checkAndUpdateDynamicColor() {
    if (_themeColorMode == ThemeColorMode.dynamic) {
      _updateDynamicThemeColor();
    }
  }

  // Mevcut namaz vaktini al (tercihen SharedPreferences'taki gerçek vakitlere göre)
  String _getCurrentPrayerTime() {
    final now = DateTime.now();
    
    // Not: SharedPreferences senkron erişim sağlamadığından burada doğrudan
    // okuma yapmıyoruz. Asenkron çözüm için _resolveCurrentPrayerFromPrefsAsync() çağrılıyor.

    // Asenkron olmayan çözüm: SharedPreferences'i üst katmanda zaten düzenli yazıyoruz.
    // Burada senkron hesaplama için, daha önce loadSettings ve sync çağrıları ile
    // kaydettiğimiz değerleri hızlıca çekebilmek adına "trySync" yaklaşımı uyguluyoruz.
    // Bunun için küçük bir yardımcı ile senkron okumayı taklit edeceğiz.
    // Not: Flutter'ın SharedPreferences API'si async init gerektirir;
    // bu nedenle güvenli ve basit yol: önceki kaba saat aralığına fallback yapıp
    // dinamik kontrol timer'ı aracılığıyla kısa aralıklarla tekrar denemek.

    // 1) Kaba fallback (hemen bir renk döndürsün)
    String byHour() {
      final hour = now.hour;
      if (hour >= 5 && hour < 6) return 'İmsak';
      if (hour >= 6 && hour < 12) return 'Güneş';
      if (hour >= 12 && hour < 15) return 'Öğle';
      if (hour >= 15 && hour < 18) return 'İkindi';
      if (hour >= 18 && hour < 20) return 'Akşam';
      return 'Yatsı';
    }

    // 2) Gerçek vakitlere göre hesaplamayı asenkron metotla yap ve sonucu cache'le
    _resolveCurrentPrayerFromPrefsAsync();

    // Geçici olarak saat aralığına göre döndür; birkaç saniye içinde timer ile doğru renk eşitlenecek
    return byHour();
  }

  // SharedPreferences'tan gerçek vakitlere göre güncel namaz vaktini asenkron belirle
  Future<void> _resolveCurrentPrayerFromPrefsAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fajr = prefs.getString('nv_fajr');
      final sunrise = prefs.getString('nv_sunrise');
      final dhuhr = prefs.getString('nv_dhuhr');
      final asr = prefs.getString('nv_asr');
      final maghrib = prefs.getString('nv_maghrib');
      final isha = prefs.getString('nv_isha');
      final tomorrowFajr = prefs.getString('nv_tomorrow_fajr') ?? prefs.getString('nv_fajr_tomorrow');

      if ([fajr, sunrise, dhuhr, asr, maghrib, isha].any((e) => e == null || (e.isEmpty))) {
        return;
      }

      String? parseNameByNow() {
        final now = DateTime.now();
        DateTime? toToday(String? hhmm) {
          if (hhmm == null || hhmm.isEmpty) return null;
          final parts = hhmm.split(':');
          if (parts.length != 2) return null;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null) return null;
          return DateTime(now.year, now.month, now.day, h, m);
        }

        final seq = <MapEntry<String, DateTime?>>[
          MapEntry('İmsak', toToday(fajr)),
          MapEntry('Güneş', toToday(sunrise)),
          MapEntry('Öğle', toToday(dhuhr)),
          MapEntry('İkindi', toToday(asr)),
          MapEntry('Akşam', toToday(maghrib)),
          MapEntry('Yatsı', toToday(isha)),
        ];

        for (int i = 0; i < seq.length; i++) {
          final current = seq[i].value;
          final next = seq[(i + 1) % seq.length].value;
          if (current == null || next == null) continue;
          if (i < seq.length - 1) {
            if (now.isAfter(current) && now.isBefore(next)) {
              return seq[i].key;
            }
          } else {
            // Yatsı -> İmsak
            if (now.isAfter(current)) return seq[i].key;
            if (tomorrowFajr != null) {
              final parts = tomorrowFajr.split(':');
              if (parts.length == 2) {
                final tf = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1])).add(const Duration(days: 1));
                if (now.isBefore(tf)) return seq[i].key; // hala Yatsı aralığı
              }
            }
          }
        }
        return null;
      }

      final resolved = parseNameByNow();
      if (resolved != null) {
        final newColor = _getPrayerColor(resolved);
        if (_currentThemeColor != newColor || _currentPrayerTime != resolved) {
          _currentThemeColor = newColor;
          _currentPrayerTime = resolved;
          _syncWidgetThemeColors();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Dinamik renk (prefs) çözümleme hatası: $e');
    }
  }

  // Namaz vaktine göre renk al
  Color _getPrayerColor(String prayerTime) {
    return SettingsConstants.prayerColors[prayerTime]?.color ?? 
           SettingsConstants.defaultColor.color;
  }

  // Ayarları yükle
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Tema rengi modunu yükle
      final savedMode = prefs.getString('theme_color_mode');
      if (savedMode != null) {
        _themeColorMode = ThemeColorMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => ThemeColorMode.static,
        );
      }
      
      // Seçili tema rengini yükle (eski kayıtlardan gelebilecek tam siyahı filtrele)
      final savedColor = prefs.getInt('selected_theme_color');
      if (savedColor != null) {
        final loaded = Color(savedColor);
        _selectedThemeColor = (loaded.value == const Color(0xFF000000).value)
            ? SettingsConstants.defaultThemeColor.color
            : loaded;
      }
      
      // Mevcut rengi ayarla
      if (_themeColorMode == ThemeColorMode.dynamic) {
        _updateDynamicThemeColor();
      } else if (_themeColorMode == ThemeColorMode.system) {
        final ColorScheme? anyScheme = _systemLightScheme ?? _systemDarkScheme;
        _currentThemeColor = anyScheme?.primary ?? _selectedThemeColor;
      } else if (_themeColorMode == ThemeColorMode.amoled || _themeColorMode == ThemeColorMode.black) {
        _currentThemeColor = Colors.black;
      } else {
        _currentThemeColor = _selectedThemeColor;
      }
      
      // Uygulama açılışında widget temasıyla senkronize ol
      _syncWidgetThemeColors();

      notifyListeners();
    } catch (e) {
      debugPrint('Tema ayarları yükleme hatası: $e');
    }
  }

  // Widget tarafıyla tema renklerini paylaş ve anında güncelleme iste
  void _syncWidgetThemeColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_theme_color', _currentThemeColor.value);
      await prefs.setInt('selected_theme_color', _selectedThemeColor.value);
      // Anında görsel güncelleme
      await WidgetBridgeService.forceUpdateSmallWidget();
    } catch (e) {
      debugPrint('Widget tema senkronizasyon hatası: $e');
    }
  }

  // Tema rengi modunu kaydet
  Future<void> _saveThemeColorMode(ThemeColorMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_color_mode', mode.name);
    } catch (e) {
      debugPrint('Tema rengi modu kaydetme hatası: $e');
    }
  }

  // Seçili tema rengini kaydet
  Future<void> _saveSelectedThemeColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_theme_color', color.value);
    } catch (e) {
      debugPrint('Seçili tema rengi kaydetme hatası: $e');
    }
  }

  // Özel tema renkleri için roller
  static const Color _haremColor = Color(0xFF1E1D1C);
  static const Color _aksaColor = Color(0xFF7B8FA3);

  // Harem ve Aksa için özel renk rollerini uygula
  ColorScheme _applySpecialColorRoles(ColorScheme baseScheme, Brightness brightness) {
    // Eğer seçili tema Harem ise
    if (_selectedThemeColor.value == _haremColor.value) {
      return _applyHaremRoles(baseScheme, brightness);
    }
    
    // Eğer seçili tema Aksa ise
    if (_selectedThemeColor.value == _aksaColor.value) {
      return _applyAksaRoles(baseScheme, brightness);
    }
    
    // Diğer temalar için varsayılan
    return baseScheme;
  }

  // Harem teması için özel roller
  ColorScheme _applyHaremRoles(ColorScheme baseScheme, Brightness brightness) {
      return baseScheme.copyWith(
      primary: const Color(0xFFD4AF37),
      onSurface: const Color(0xFFD3C7A7),
      outlineVariant: const Color.fromARGB(255, 219, 184, 68),
      );
  }

  // Aksa teması için özel roller
  ColorScheme _applyAksaRoles(ColorScheme baseScheme, Brightness brightness) {
    return baseScheme.copyWith(
      primary: const Color(0xFF6F95B8),
      onSurface: const Color(0xFFE7F3FE),
      outline: const Color(0xFFE3C86D),
      outlineVariant: const Color(0xFFE3C86D),
    );
  }

  // Tema verilerini oluştur
  ThemeData buildTheme({required Brightness brightness}) {
    // Temel renk şemasını üret (varsayılan seed tabanlı)
    ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _currentThemeColor,
      brightness: brightness,
    );

    // Harem ve Aksa için özel roller uygula
    scheme = _applySpecialColorRoles(scheme, brightness);

    // Sistem (Material You) modu: varsa platform dinamik şemayı kullan
    if (_themeColorMode == ThemeColorMode.system) {
      final ColorScheme? systemScheme =
          brightness == Brightness.dark ? _systemDarkScheme : _systemLightScheme;
      if (systemScheme != null) {
        scheme = systemScheme;
      }
    }

    // AMOLED + koyu modda, şemayı nötr siyah-beyaz olacak şekilde ayarla
    if (_themeColorMode == ThemeColorMode.amoled && brightness == Brightness.dark) {
      final Color accentForDark = uiAccentColorFor(Brightness.dark);
      // Sabit + koyu moddaki outline ile uyumlu olması için, outline'ı seçili tema renginden türet
      final Color referenceOutline = ColorScheme.fromSeed(
        seedColor: _selectedThemeColor,
        brightness: Brightness.dark,
      ).outline;

      scheme = scheme.copyWith(
        // Saf siyah zeminler
        background: Colors.black,
        surface: Colors.black,
        surfaceVariant: const Color(0xFF0E0E0E),
        // Nötr metinler
        onSurface: accentForDark,
        onBackground: Colors.white,
        onSurfaceVariant: const Color(0xFFE0E0E0),
        // Çerçeve rengi: sabit + koyu moddaki outline ile aynı baz tonu
        outline: referenceOutline,
        // Tint'leri kapat
        surfaceTint: Colors.transparent,
      );
    }

    // Karanlık (siyah seed) renk modunda, yalnızca primary rolünü kırmızıya ayarla
    if (_themeColorMode == ThemeColorMode.black) {
      scheme = scheme.copyWith(primary: const Color(0xFFC2C2C2));
      scheme = scheme.copyWith(onSurface: const Color(0xFFF1F1F1));
      scheme = scheme.copyWith(surface: const Color(0xFF454545));
      scheme = scheme.copyWith(outline: const Color(0x8AFFFFFF));
      scheme = scheme.copyWith(outlineVariant: const Color(0x89D0D0D0));
    }

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppConstants.defaultFontFamily,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: brightness == Brightness.dark ? Colors.white : AppConstants.darkTextColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
      ),
    );
  }

  /// Özel tema renklerinin aktif olup olmadığını kontrol et
  bool get isHaremThemeActive => _selectedThemeColor.value == _haremColor.value;
  bool get isAksaThemeActive => _selectedThemeColor.value == _aksaColor.value;
  
  /// Aktif özel tema adını al
  String? get activeSpecialTheme {
    if (isHaremThemeActive) return 'Harem';
    if (isAksaThemeActive) return 'Aksa';
    return null;
  }

  /// Sistem dinamik renk şemalarını güncelle (Android 12+ Material You)
  void updateSystemDynamicSchemes({ColorScheme? light, ColorScheme? dark}) {
    bool changed = false;
    if (_systemLightScheme != light) {
      _systemLightScheme = light;
      changed = true;
    }
    if (_systemDarkScheme != dark) {
      _systemDarkScheme = dark;
      changed = true;
    }

    if (!changed) return;

    // Mevcut mod sistem ise currentThemeColor'ı güncelle ve widget ile senkronize et
    if (_themeColorMode == ThemeColorMode.system) {
      final ColorScheme? anyScheme = _systemLightScheme ?? _systemDarkScheme;
      if (anyScheme != null) {
        _currentThemeColor = anyScheme.primary;
        _syncWidgetThemeColors();
      }
      notifyListeners();
    }
  }
} 