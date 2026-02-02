import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_bridge.dart';
import '../utils/constants.dart';
import '../utils/app_keys.dart';
import '../utils/app_logger.dart';

/// Tema rengi modu
enum ThemeColorMode { static, dynamic, custom, black, amoled }

/// Tema yönetimi servisi.
///
/// Bu servis, uygulamanın tema rengini yönetir:
/// - Static: Kullanıcının seçtiği sabit renk
/// - Dynamic: Namaz vaktine göre otomatik değişen renkler
/// - System: Android 12+ Material You dinamik renkleri
/// - Black/AMOLED: Siyah temalar
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Tema rengi durumu
  ThemeColorMode _themeColorMode = ThemeColorMode.static;
  Color _selectedThemeColor = SettingsConstants.defaultThemeColor.color;
  Color _currentThemeColor = SettingsConstants.defaultThemeColor.color;
  Color _customThemeColor = const Color(0xFF6750A4); // Varsayılan mor renk

  // Namaz vakti takibi
  String? _currentPrayerTime;

  // Cached SharedPreferences instance
  SharedPreferences? _prefsCache;

  // Getters
  ThemeColorMode get themeColorMode => _themeColorMode;
  Color get selectedThemeColor => _selectedThemeColor;
  Color get currentThemeColor => _currentThemeColor;
  Color get customThemeColor => _customThemeColor;

  Color get currentSecondaryColor {
    if (_themeColorMode == ThemeColorMode.dynamic && _currentPrayerTime != null) {
      final prayerData = SettingsConstants.prayerColors[_currentPrayerTime];
      if (prayerData != null) {
        return prayerData.secondaryColor;
      }
    }
    return _findThemeData(_currentThemeColor).secondaryColor;
  }

  String? get currentPrayerTime => _currentPrayerTime;

  /// Yardımcı: Renge göre ThemeColorData bul
  ThemeColorData _findThemeData(Color color) {
    try {
      return SettingsConstants.themeColors.firstWhere(
        (e) => e.color == color,
        orElse: () => SettingsConstants.prayerColors.values.firstWhere(
          (e) => e.color == color,
          orElse: () => SettingsConstants.defaultThemeColor,
        ),
      );
    } catch (_) {
      return SettingsConstants.defaultThemeColor;
    }
  }

  /// UI bileşenlerinde görünen vurgu rengi.
  /// AMOLED modda, parlaklıktan bağımsız olarak nötr gri döndür.
  Color uiAccentColorFor(Brightness brightness) {
    if (_themeColorMode == ThemeColorMode.amoled) {
      return const Color(0xFFF4F4F4);
    }
    return _currentThemeColor;
  }

  /// Tema rengi modunu değiştirir ve kaydeder.
  Future<void> setThemeColorMode(ThemeColorMode mode) async {
    if (_themeColorMode == mode) return;

    _themeColorMode = mode;
    await _saveThemeColorMode(mode);

    // Moda göre rengi güncelle
    switch (mode) {
      case ThemeColorMode.dynamic:
        await _updateDynamicThemeColor();
        break;
      case ThemeColorMode.custom:
        _currentThemeColor = _customThemeColor;
        break;
      case ThemeColorMode.black:
      case ThemeColorMode.amoled:
        _currentThemeColor = Colors.black;
        break;
      case ThemeColorMode.static:
        _currentThemeColor = _selectedThemeColor;
        break;
    }

    // Widget temasıyla senkronize et
    await _syncWidgetThemeColors();
    notifyListeners();
  }

  /// Seçili tema rengini değiştirir (statik mod için).
  Future<void> setSelectedThemeColor(Color color) async {
    if (_selectedThemeColor == color) return;

    _selectedThemeColor = color;
    await _saveSelectedThemeColor(color);

    if (_themeColorMode == ThemeColorMode.static) {
      _currentThemeColor = color;
      await _syncWidgetThemeColors();
      notifyListeners();
    } else {
      // Diğer modlarda da seçilen rengi native taraf için kaydet
      await _syncWidgetThemeColors();
    }
  }

  /// Özel tema rengini değiştirir (custom mod için RGB seçici).
  Future<void> setCustomThemeColor(Color color) async {
    if (_customThemeColor == color) return;

    _customThemeColor = color;
    await _saveCustomThemeColor(color);

    if (_themeColorMode == ThemeColorMode.custom) {
      _currentThemeColor = color;
      await _syncWidgetThemeColors();
      notifyListeners();
    }
  }

  /// Dinamik tema rengini namaz vaktine göre günceller.
  Future<void> _updateDynamicThemeColor() async {
    if (_themeColorMode != ThemeColorMode.dynamic) return;

    final currentPrayer = await _getCurrentPrayerTimeAsync();
    final newColor = _getPrayerColor(currentPrayer);

    if (_currentThemeColor != newColor || _currentPrayerTime != currentPrayer) {
      _currentThemeColor = newColor;
      _currentPrayerTime = currentPrayer;
      await _syncWidgetThemeColors();
      notifyListeners();
    }
  }

  /// Namaz vakti değişikliğini kontrol et ve gerekirse güncelle.
  Future<void> checkAndUpdateDynamicColor() async {
    if (_themeColorMode == ThemeColorMode.dynamic) {
      await _updateDynamicThemeColor();
    }
  }

  /// SharedPreferences'tan mevcut namaz vaktini asenkron olarak belirler.
  ///
  /// Algoritma:
  /// 1. Öncelikle cache'lenmiş prefs instance'ı kullan
  /// 2. Kayıtlı namaz vakitlerini oku (HH:mm formatında)
  /// 3. Mevcut saati kontrol ederek hangi vakit aralığında olduğunu bul
  /// 4. Fallback olarak saat aralığına göre hesapla
  Future<String> _getCurrentPrayerTimeAsync() async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      final prefs = _prefsCache!;

      final fajr = prefs.getString(AppKeys.prayerFajr);
      final sunrise = prefs.getString(AppKeys.prayerSunrise);
      final dhuhr = prefs.getString(AppKeys.prayerDhuhr);
      final asr = prefs.getString(AppKeys.prayerAsr);
      final maghrib = prefs.getString(AppKeys.prayerMaghrib);
      final isha = prefs.getString(AppKeys.prayerIsha);

      // Eksik veri varsa fallback
      if ([fajr, sunrise, dhuhr, asr, maghrib, isha].any((e) => e == null || e.isEmpty)) {
        return _getPrayerTimeByHour();
      }

      final resolved = _calculateCurrentPrayer(
        fajr: fajr!,
        sunrise: sunrise!,
        dhuhr: dhuhr!,
        asr: asr!,
        maghrib: maghrib!,
        isha: isha!,
      );

      return resolved ?? _getPrayerTimeByHour();
    } catch (e, stackTrace) {
      AppLogger.error('Dinamik renk hesaplama hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
      return _getPrayerTimeByHour();
    }
  }

  /// Namaz vakitlerinden mevcut vakti hesaplar.
  String? _calculateCurrentPrayer({
    required String fajr,
    required String sunrise,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
  }) {
    final now = DateTime.now();

    DateTime? toToday(String hhmm) {
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(now.year, now.month, now.day, h, m);
    }

    final seq = <MapEntry<String, DateTime?>>[
      MapEntry(AppKeys.prayerNameImsak, toToday(fajr)),
      MapEntry(AppKeys.prayerNameGunes, toToday(sunrise)),
      MapEntry(AppKeys.prayerNameOgle, toToday(dhuhr)),
      MapEntry(AppKeys.prayerNameIkindi, toToday(asr)),
      MapEntry(AppKeys.prayerNameAksam, toToday(maghrib)),
      MapEntry(AppKeys.prayerNameYatsi, toToday(isha)),
    ];

    for (int i = 0; i < seq.length; i++) {
      final current = seq[i].value;
      final next = i < seq.length - 1 ? seq[i + 1].value : null;

      if (current == null) continue;

      if (i < seq.length - 1 && next != null) {
        if (now.isAfter(current) && now.isBefore(next)) {
          return seq[i].key;
        }
      } else {
        // Yatsı sonrası
        if (now.isAfter(current)) {
          return seq[i].key;
        }
      }
    }

    return null;
  }

  /// Saat aralığına göre kaba namaz vakti tahmini (fallback).
  String _getPrayerTimeByHour() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 6) return AppKeys.prayerNameImsak;
    if (hour >= 6 && hour < 12) return AppKeys.prayerNameGunes;
    if (hour >= 12 && hour < 15) return AppKeys.prayerNameOgle;
    if (hour >= 15 && hour < 18) return AppKeys.prayerNameIkindi;
    if (hour >= 18 && hour < 20) return AppKeys.prayerNameAksam;
    return AppKeys.prayerNameYatsi;
  }

  /// Namaz vaktine göre renk döndürür.
  Color _getPrayerColor(String prayerTime) {
    return SettingsConstants.prayerColors[prayerTime]?.color ??
        SettingsConstants.defaultColor.color;
  }

  /// Ayarları SharedPreferences'tan yükler.
  Future<void> loadSettings() async {
    try {
      final stopwatch = AppLogger.startTimer('ThemeService.loadSettings');

      _prefsCache ??= await SharedPreferences.getInstance();
      final prefs = _prefsCache!;

      // Tema rengi modunu yükle
      final savedMode = prefs.getString(AppKeys.themeColorMode);
      if (savedMode != null) {
        _themeColorMode = ThemeColorMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => ThemeColorMode.static,
        );
      }

      // Seçili tema rengini yükle
      final savedColor = prefs.getInt(AppKeys.selectedThemeColor);
      if (savedColor != null) {
        final loaded = Color(savedColor);
        // Tam siyah rengi varsayılana dönüştür (eski kayıtlar)
        _selectedThemeColor = (loaded == const Color(0xFF000000))
            ? SettingsConstants.defaultThemeColor.color
            : loaded;
      }

      // Özel tema rengini yükle
      final savedCustomColor = prefs.getInt(AppKeys.customThemeColor);
      if (savedCustomColor != null) {
        _customThemeColor = Color(savedCustomColor);
      }

      // Mevcut rengi ayarla
      switch (_themeColorMode) {
        case ThemeColorMode.dynamic:
          await _updateDynamicThemeColor();
          break;
        case ThemeColorMode.custom:
          _currentThemeColor = _customThemeColor;
          break;
        case ThemeColorMode.amoled:
        case ThemeColorMode.black:
          _currentThemeColor = Colors.black;
          break;
        case ThemeColorMode.static:
          _currentThemeColor = _selectedThemeColor;
          break;
      }

      // Widget temasıyla senkronize ol
      await _syncWidgetThemeColors();

      AppLogger.stopTimer(stopwatch, 'ThemeService.loadSettings');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Tema ayarları yükleme hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
    }
  }

  /// Widget tarafıyla tema renklerini paylaşır.
  Future<void> _syncWidgetThemeColors() async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      final prefs = _prefsCache!;

      await prefs.setInt(AppKeys.currentThemeColor, _currentThemeColor.toARGB32());
      await prefs.setInt(AppKeys.selectedThemeColor, _selectedThemeColor.toARGB32());

      // Anında görsel güncelleme
      await WidgetBridgeService.forceUpdateSmallWidget();
    } catch (e, stackTrace) {
      AppLogger.error('Widget tema senkronizasyon hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
    }
  }

  /// Tema rengi modunu kaydeder.
  Future<void> _saveThemeColorMode(ThemeColorMode mode) async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setString(AppKeys.themeColorMode, mode.name);
    } catch (e, stackTrace) {
      AppLogger.error('Tema rengi modu kaydetme hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
    }
  }

  /// Seçili tema rengini kaydeder.
  Future<void> _saveSelectedThemeColor(Color color) async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setInt(AppKeys.selectedThemeColor, color.toARGB32());
    } catch (e, stackTrace) {
      AppLogger.error('Seçili tema rengi kaydetme hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
    }
  }

  /// Özel tema rengini kaydeder (RGB seçici için).
  Future<void> _saveCustomThemeColor(Color color) async {
    try {
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setInt(AppKeys.customThemeColor, color.toARGB32());
    } catch (e, stackTrace) {
      AppLogger.error('Özel tema rengi kaydetme hatası', tag: 'ThemeService', error: e, stackTrace: stackTrace);
    }
  }

  // Özel tema renkleri
  static const Color _haremColor = Color(0xFF1E1D1C);
  static const Color _aksaColor = Color(0xFF7B8FA3);

  /// Harem ve Aksa için özel renk rollerini uygular.
  /// Sadece static modda uygulanır, dinamik modda namaz vakti renkleri kullanılır.
  ColorScheme _applySpecialColorRoles(ColorScheme baseScheme, Brightness brightness) {
    // Dinamik modda özel renk rolleri uygulanmamalı
    if (_themeColorMode == ThemeColorMode.dynamic) {
      return baseScheme;
    }

    if (_selectedThemeColor == _haremColor) {
      return _applyHaremRoles(baseScheme, brightness);
    }
    if (_selectedThemeColor == _aksaColor) {
      return _applyAksaRoles(baseScheme, brightness);
    }
    return baseScheme;
  }

  ColorScheme _applyHaremRoles(ColorScheme baseScheme, Brightness brightness) {
    return baseScheme.copyWith(
      primary: const Color(0xFFD4AF37),
      onSurface: const Color(0xFFD3C7A7),
      outlineVariant: const Color.fromARGB(255, 219, 184, 68),
    );
  }

  ColorScheme _applyAksaRoles(ColorScheme baseScheme, Brightness brightness) {
    return baseScheme.copyWith(
      primary: const Color(0xFF6F95B8),
      onSurface: const Color(0xFFE7F3FE),
      outline: const Color(0xFFE3C86D),
      outlineVariant: const Color(0xFFE3C86D),
    );
  }

  /// Nötr renkler (siyah, beyaz, gri) için özel ColorScheme oluşturur.
  ColorScheme _buildNeutralColorScheme(Brightness brightness, Color neutralColor) {
    final hsv = HSVColor.fromColor(neutralColor);
    final isDark = brightness == Brightness.dark;

    // Rengin parlaklık değerine göre kontrast renkler belirle
    final isLightNeutral = hsv.value > 0.5;

    if (isDark) {
      // Karanlık tema için nötr renk şeması
      return ColorScheme.dark(
        primary: neutralColor,
        onPrimary: isLightNeutral ? Colors.black : Colors.white,
        secondary: neutralColor,
        onSecondary: isLightNeutral ? Colors.black : Colors.white,
        surface: const Color(0xFF121212),
        onSurface: neutralColor.computeLuminance() < 0.5
            ? const Color(0xFFE0E0E0)
            : neutralColor,
        surfaceContainerHighest: const Color(0xFF2D2D2D),
        outline: neutralColor.withValues(alpha: 0.5),
        outlineVariant: neutralColor.withValues(alpha: 0.3),
      );
    } else {
      // Aydınlık tema için nötr renk şeması
      return ColorScheme.light(
        primary: neutralColor,
        onPrimary: isLightNeutral ? Colors.black : Colors.white,
        secondary: neutralColor,
        onSecondary: isLightNeutral ? Colors.black : Colors.white,
        surface: const Color(0xFFFFFBFE),
        onSurface: neutralColor.computeLuminance() > 0.5
            ? const Color(0xFF1C1B1F)
            : neutralColor,
        surfaceContainerHighest: const Color(0xFFE6E1E5),
        outline: neutralColor.withValues(alpha: 0.5),
        outlineVariant: neutralColor.withValues(alpha: 0.3),
      );
    }
  }

  /// Tema verilerini oluşturur.
  ThemeData buildTheme({required Brightness brightness}) {
    // Temel renk şemasını üret
    ColorScheme scheme;

    // Custom mod için düşük saturation kontrolü (gri, siyah, beyaz)
    if (_themeColorMode == ThemeColorMode.custom) {
      final hsv = HSVColor.fromColor(_currentThemeColor);
      final isLowSaturation = hsv.saturation < 0.15;
      final isVeryDark = hsv.value < 0.1;
      final isVeryLight = hsv.value > 0.95 && hsv.saturation < 0.1;

      if (isLowSaturation || isVeryDark || isVeryLight) {
        // Nötr renkler için özel ColorScheme oluştur
        scheme = _buildNeutralColorScheme(brightness, _currentThemeColor);
      } else {
        scheme = ColorScheme.fromSeed(
          seedColor: _currentThemeColor,
          brightness: brightness,
        );
      }
    } else {
      scheme = ColorScheme.fromSeed(
        seedColor: _currentThemeColor,
        brightness: brightness,
      );
    }

    // Özel roller uygula (sadece static modda)
    scheme = _applySpecialColorRoles(scheme, brightness);

    // AMOLED + koyu mod
    if (_themeColorMode == ThemeColorMode.amoled && brightness == Brightness.dark) {
      final Color accentForDark = uiAccentColorFor(Brightness.dark);
      final Color referenceOutline = ColorScheme.fromSeed(
        seedColor: _selectedThemeColor,
        brightness: Brightness.dark,
      ).outline;

      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF0E0E0E),
        onSurface: accentForDark,
        onSurfaceVariant: const Color(0xFFE0E0E0),
        outline: referenceOutline,
        surfaceTint: Colors.transparent,
      );
    }

    // Karanlık (siyah seed) renk modu
    if (_themeColorMode == ThemeColorMode.black) {
      scheme = scheme.copyWith(
        primary: const Color(0xFFC2C2C2),
        onSurface: const Color(0xFFF1F1F1),
        surface: const Color(0xFF454545),
        outline: const Color(0x8AFFFFFF),
        outlineVariant: const Color(0x89D0D0D0),
      );
    }

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
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

  /// Özel tema renklerinin aktif olup olmadığını kontrol eder.
  bool get isHaremThemeActive => _selectedThemeColor == _haremColor;
  bool get isAksaThemeActive => _selectedThemeColor == _aksaColor;

  /// Aktif özel tema adını döndürür.
  String? get activeSpecialTheme {
    if (isHaremThemeActive) return 'Harem';
    if (isAksaThemeActive) return 'Aksa';
    return null;
  }

  /// Sistem dinamik renk şemalarını günceller.
  /// @deprecated Bu metod artık kullanılmıyor, custom mod RGB seçici kullanır.
  void updateSystemDynamicSchemes({ColorScheme? light, ColorScheme? dark}) {
    // Geriye uyumluluk için bırakıldı, artık işlev görmüyor
  }
}
