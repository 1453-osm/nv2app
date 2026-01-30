import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Tema modu seçenekleri
enum AppThemeMode { system, light, dark }

/// Uygulama genelinde kullanılan animasyon sabitleri
class AnimationConstants {
  // Temel animasyon süreleri
  static const Duration instant = Duration.zero;
  static const Duration veryFast = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration normal = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration verySlow = Duration(milliseconds: 800);
  static const Duration extraSlow = Duration(milliseconds: 1200);
  static const Duration shimmer = Duration(milliseconds: 1500);

  // Özel animasyon süreleri
  static const Duration pickerMomentum = Duration(milliseconds: 800);
  static const Duration expandContraction = Duration(milliseconds: 350);
  static const Duration minimumLoadingDuration = Duration(milliseconds: 2500);

  // Timer süreleri
  static const Duration countdownInterval = Duration(seconds: 1);
  static const Duration themeUpdateInterval = Duration(seconds: 30);

  // Temel animasyon eğrileri
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  // Kompozit animasyon konfigürasyonları
  static const AnimationConfig slideTransition = AnimationConfig(
    duration: slow,
    curve: easeInOutCubic,
  );

  static const AnimationConfig fadeTransition = AnimationConfig(
    duration: fast,
    curve: easeInOut,
  );

  static const AnimationConfig scaleTransition = AnimationConfig(
    duration: medium,
    curve: fastOutSlowIn,
  );

  static const AnimationConfig expansionTransition = AnimationConfig(
    duration: normal,
    curve: easeInOut,
  );

  static const AnimationConfig quickTransition = AnimationConfig(
    duration: fast,
    curve: easeInOut,
  );

  static const AnimationConfig smoothTransition = AnimationConfig(
    duration: medium,
    curve: easeInOutCubic,
  );

  static const AnimationConfig pickerTransition = AnimationConfig(
    duration: medium,
    curve: easeInOut,
  );

  static const AnimationConfig valueChangeTransition = AnimationConfig(
    duration: fast,
    curve: elasticOut,
  );

  static const AnimationConfig momentumTransition = AnimationConfig(
    duration: pickerMomentum,
    curve: decelerate,
  );

  static const AnimationConfig containerTransition = AnimationConfig(
    duration: expandContraction,
    curve: easeOutQuart,
  );
}

/// Animasyon konfigürasyon sınıfı
class AnimationConfig {
  final Duration duration;
  final Curve curve;

  const AnimationConfig({
    required this.duration,
    required this.curve,
  });
}

/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  // Renkler
  static const Color primaryColor = Color(0xFF588065);
  static const Color darkTextColor = Color(0xFF1A1A1A);

  // Boyutlar
  static const double defaultPadding = 16.0;
  static const double cardPadding = 20.0;
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 16.0;

  // Animasyon süreleri (deprecated - AnimationConstants kullanın)
  @Deprecated('Use AnimationConstants.normal instead')
  static const Duration animationDuration = Duration(milliseconds: 400);
  @Deprecated('Use AnimationConstants.fast instead')
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  @Deprecated('Use AnimationConstants.slow instead')
  static const Duration longAnimationDuration = Duration(milliseconds: 600);

  // Opasiteler
  static const double backgroundOpacity = 0.1;
  static const double glassOpacity = 0.15;
  static const double borderOpacity = 0.3;

  // Fontlar
  static const String defaultFontFamily = 'Inter';

  // Mesajlar
  static const String appTitle = 'Namaz Vakitleri';
  static const String locationNotSelected = 'Konum seçilmedi';
  static const String loading = 'Yükleniyor...';
  static const String error = 'Hata Oluştu';
  static const String retry = 'Tekrar Dene';

  // Overlay opasiteleri için varsayılan değerler (null olursa çarpma işlemlerinde '* on null' hatası oluşur)
  static const double overlayOpacityDark = 0.08;

  static const double overlayOpacityLight = 0.10;
}

/// Modal ve dialog'lar için sabitler
class ModalConstants {
  // Blur değerleri
  static const double blurSigma = 3.0;

  // Arka plan opaklıkları - AppConstants'teki overlayOpacity değerlerini kullanır
  static double getOverlayOpacity(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppConstants.overlayOpacityDark
        : AppConstants.overlayOpacityLight;
  }

  // Arka plan rengi
  static Color getOverlayColor(BuildContext context) {
    return Colors.black.withValues(
      alpha: getOverlayOpacity(context),
    );
  }
}

/// Drawer'lar için sabitler
class DrawerConstants {
  // Drawer overlay blur (drawer açıkken arka plan blur'u)
  static const double overlayBlurSigma = 3.0;

  // Drawer scrim rengi (drawer arka planı)
  static const Color scrimColor = Colors.transparent;
}

/// Glassmorphism bar tasarımı için sabitler
class GlassBarConstants {
  // Boyutlar
  static const double borderRadius = 24.0;
  static const double borderWidth = 1.5;
  static const double blurSigma = 10.0;
  static const double blurmSigma = 7.5;

  // Genişlik değerleri
  static const double minCollapsedWidth = 50.0;
  static const double maxCollapsedWidth = 250.0;
  static const double expandedWidth = 250.0;

  // Yükseklik değerleri
  static const double collapsedHeaderHeight = 35.0;
  static const double expandedHeaderHeight = 65.0;
  static const double maxContentHeight = 300.0;
  static const double searchBarHeight = 64.0;

  // Padding ve margin değerleri
  static const double headerPadding = 16.0;
  static const double contentPadding = 16.0;
  static const double itemPadding = 12.0;
  static const double iconPadding = 4.0;

  // İkon boyutları
  static const double collapsedIconSize = 0.0;
  static const double expandedIconSize = 28.0;

  // Font boyutları
  static const double collapsedFontSize = 13.0;
  static const double expandedFontSize = 18.0;
  static const double itemFontSize = 16.0;

  // Opasiteler
  static const double backgroundOpacity = 0.1;
  static const double borderOpacity = 0.3;
  static const double splashOpacity = 0.1;
  static const double highlightOpacity = 0.05;
  static const double hintOpacity = 0.6;

  // Dinamik tema renkleri - Eski sabit renkler yerine
  static Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Theme.of(context).colorScheme.onSurface : Colors.white;
  }

  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.1);
  }

  static Color getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);
  }

  // Animasyon eğrileri (deprecated - AnimationConstants kullanın)
  @Deprecated('Use AnimationConstants.easeInOut instead')
  static const Curve expansionCurve = Curves.easeInOut;
  @Deprecated('Use AnimationConstants.easeInOutCubic instead')
  static const Curve transitionCurve = Curves.easeInOutCubic;

  // Animasyon süreleri (deprecated - AnimationConstants kullanın)
  @Deprecated('Use AnimationConstants.normal instead')
  static const Duration expansionDuration = Duration(milliseconds: 400);
  @Deprecated('Use AnimationConstants.medium instead')
  static const Duration transitionDuration = Duration(milliseconds: 300);
  @Deprecated('Use AnimationConstants.fast instead')
  static const Duration fastTransition = Duration(milliseconds: 200);

  // ========== RESPONSIVE HELPERS ==========
  //
  // Responsive değerler için Responsive sınıfını doğrudan kullanın:
  // - Responsive.fontSize(context, FontSize.md)
  // - Responsive.space(context, SpaceSize.md)
  // - Responsive.iconSize(context, IconSizeLevel.md)
  // - Responsive.borderRadius(context)
  //
  // Veya BuildContext extension'larını kullanın:
  // - context.font(FontSize.md)
  // - context.space(SpaceSize.md)
  // - context.icon(IconSizeLevel.md)
}

/// Ayarlar menüsü için sabitler
class SettingsConstants {
  // Tema renkleri
  static const List<ThemeColorData> themeColors = [
    ThemeColorData(
        color: Color(0xFF588065),
        name: 'Ravza',
        localizationKey: 'themeColorRavza'),
    ThemeColorData(
        color: Color(0xFF1E1D1C),
        name: 'Harem',
        localizationKey: 'themeColorHarem',
        hasSpecialRoles: true),
    ThemeColorData(
        color: Color(0xFF7B8FA3),
        name: 'Aksa',
        localizationKey: 'themeColorAksa',
        hasSpecialRoles: true),
  ];

  // Dinamik namaz renkleri
  static const Map<String, ThemeColorData> prayerColors = {
    'İmsak': ThemeColorData(
      color: Color(0xFF121838),
      name: 'İmsak',
      localizationKey: 'themeColorImsak',
      secondaryColor: Color(0xFF865B5B),
    ),
    'Güneş': ThemeColorData(
      color: Color(0xFF865B5B),
      name: 'Güneş',
      localizationKey: 'themeColorGunes',
      secondaryColor: Color(0xFFD1AA48),
    ),
    'Öğle': ThemeColorData(
      color: Color(0xFFD1AA48),
      name: 'Öğle',
      localizationKey: 'themeColorOgle',
      secondaryColor: Color(0xFFD2954F),
    ),
    'İkindi': ThemeColorData(
      color: Color(0xFFD2954F),
      name: 'İkindi',
      localizationKey: 'themeColorIkindi',
      secondaryColor: Color(0xFF865B5B),
    ),
    'Akşam': ThemeColorData(
      color: Color(0xFF865B5B),
      name: 'Akşam',
      localizationKey: 'themeColorAksam',
      secondaryColor: Color(0xFF212556),
    ),
    'Yatsı': ThemeColorData(
      color: Color(0xFF212556),
      name: 'Yatsı',
      localizationKey: 'themeColorYatsi',
      secondaryColor: Color(0xFF121838),
    ),
  };

  // Varsayılan tema rengi
  static const ThemeColorData defaultThemeColor =
      ThemeColorData(color: Color(0xFF588066), name: 'Yeşil');

  // Dinamik mod için varsayılan renk
  static const ThemeColorData defaultColor =
      ThemeColorData(color: Color(0xFF588066), name: 'Yeşil');

  // Bildirim dakika seçenekleri
  static const List<int> notificationMinutes = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
    65,
    70,
    75,
    80,
    85,
    90
  ];

  // Ses seçenekleri
  static const List<SoundOptionData> soundOptions = [
    SoundOptionData(
        id: 'default', name: 'Varsayılan', icon: Symbols.notifications),
    SoundOptionData(id: 'adhanarabic', name: 'Arap Ezan', icon: Symbols.mosque),
    SoundOptionData(id: 'adhan', name: 'Ezan', icon: Symbols.mosque),
    SoundOptionData(id: 'sela', name: 'Sela', icon: Symbols.mosque),
    SoundOptionData(
        id: 'hard', name: 'Sert Ton', icon: Symbols.volume_up_rounded),
    SoundOptionData(
        id: 'soft', name: 'Yumuşak Ton', icon: Symbols.volume_down_rounded),
    SoundOptionData(id: 'bird', name: 'Kuşlar', icon: Symbols.raven_rounded),
    SoundOptionData(id: 'alarm', name: 'Alarm', icon: Symbols.alarm_rounded),
    SoundOptionData(id: 'silent', name: 'Sessiz', icon: Symbols.volume_off),
  ];

  // Picker ayarları
  static const double pickerLineSpacing = 16.0;
  static const int pickerVisibleLines = 25;
  static const double pickerMaxTextWidth = 120.0;
  static const double pickerMinContainerWidth = 80.0;
  static const double pickerMaxContainerWidth = 200.0;

  // Animasyon süreleri (deprecated - AnimationConstants kullanın)
  @Deprecated('Use AnimationConstants.medium instead')
  static const Duration pickerAnimationDuration = Duration(milliseconds: 300);
  @Deprecated('Use AnimationConstants.pickerMomentum instead')
  static const Duration pickerMomentumDuration = Duration(milliseconds: 800);
  @Deprecated('Use AnimationConstants.fast instead')
  static const Duration valueChangeAnimationDuration =
      Duration(milliseconds: 200);
}

/// Tema rengi veri sınıfı
class ThemeColorData {
  final Color color;
  final Color secondaryColor;
  final String
      name; // Geriye uyumluluk için - deprecated, localizationKey kullanın
  final String? localizationKey; // Lokalizasyon anahtarı
  final bool hasSpecialRoles;

  const ThemeColorData({
    required this.color,
    this.secondaryColor = Colors.transparent,
    required this.name,
    this.localizationKey,
    this.hasSpecialRoles = false,
  });
}

/// Ses seçeneği veri sınıfı
class SoundOptionData {
  final String id;
  final String name;
  final IconData icon;

  const SoundOptionData({
    required this.id,
    required this.name,
    required this.icon,
  });
}

/// Tema ile ilgili sabitler
class ThemeConstants {
  // Artık dinamik tema için ThemeService kullanılıyor
  // Bu metodlar geriye uyumluluk için bırakıldı
  @Deprecated('Use ThemeService.buildTheme() instead')
  static ThemeData buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: AppConstants.defaultFontFamily,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppConstants.darkTextColor,
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

  @Deprecated(
      'Use ThemeService.buildTheme(brightness: Brightness.dark) instead')
  static ThemeData buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: AppConstants.defaultFontFamily,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
}
