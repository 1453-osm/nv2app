import 'package:flutter/widgets.dart';

/// Uygulama genelinde breakpoint tanımları
enum Breakpoint { xs, sm, md, lg, xl }

/// Cihaz tipi
enum DeviceType { phone, tablet, desktop }

/// Font boyutu seviyeleri
enum FontSize { xs, sm, md, lg, xl, display, countdownNumber, countdownUnit }

/// Spacing seviyeleri
enum SpaceSize { xxs, xs, sm, md, lg, xl, xxl }

/// Icon boyutu seviyeleri
enum IconSizeLevel { xs, sm, md, lg, xl, xxl }

/// Tüm responsive değerler için merkezi token sınıfı
class ResponsiveTokens {
  ResponsiveTokens._();

  // =============================================
  // FONT BOYUTLARI
  // =============================================

  /// Çok küçük metinler (caption, hint)
  static const Map<Breakpoint, double> fontXs = {
    Breakpoint.xs: 10.0,
    Breakpoint.sm: 11.0,
    Breakpoint.md: 12.0,
    Breakpoint.lg: 13.0,
    Breakpoint.xl: 14.0,
  };

  /// Küçük metinler (body small)
  static const Map<Breakpoint, double> fontSm = {
    Breakpoint.xs: 12.0,
    Breakpoint.sm: 13.0,
    Breakpoint.md: 14.0,
    Breakpoint.lg: 15.0,
    Breakpoint.xl: 16.0,
  };

  /// Normal metinler (body)
  static const Map<Breakpoint, double> fontMd = {
    Breakpoint.xs: 14.0,
    Breakpoint.sm: 15.0,
    Breakpoint.md: 16.0,
    Breakpoint.lg: 17.0,
    Breakpoint.xl: 18.0,
  };

  /// Büyük metinler (subtitle, title)
  static const Map<Breakpoint, double> fontLg = {
    Breakpoint.xs: 16.0,
    Breakpoint.sm: 17.0,
    Breakpoint.md: 18.0,
    Breakpoint.lg: 20.0,
    Breakpoint.xl: 22.0,
  };

  /// Çok büyük metinler (headline)
  static const Map<Breakpoint, double> fontXl = {
    Breakpoint.xs: 20.0,
    Breakpoint.sm: 22.0,
    Breakpoint.md: 24.0,
    Breakpoint.lg: 28.0,
    Breakpoint.xl: 32.0,
  };

  /// Display boyutu (büyük başlıklar)
  static const Map<Breakpoint, double> fontDisplay = {
    Breakpoint.xs: 32.0,
    Breakpoint.sm: 36.0,
    Breakpoint.md: 40.0,
    Breakpoint.lg: 44.0,
    Breakpoint.xl: 48.0,
  };

  /// Geri sayım rakamları (çok büyük)
  static const Map<Breakpoint, double> fontCountdownNumber = {
    Breakpoint.xs: 54.0,
    Breakpoint.sm: 62.0,
    Breakpoint.md: 72.0,
    Breakpoint.lg: 82.0,
    Breakpoint.xl: 92.0,
  };

  /// Geri sayım birimleri (saat, dakika)
  static const Map<Breakpoint, double> fontCountdownUnit = {
    Breakpoint.xs: 34.0,
    Breakpoint.sm: 38.0,
    Breakpoint.md: 44.0,
    Breakpoint.lg: 48.0,
    Breakpoint.xl: 54.0,
  };

  // =============================================
  // SPACING (Padding/Margin)
  // =============================================

  /// Çok çok küçük boşluk (2-3px)
  static const Map<Breakpoint, double> spaceXxs = {
    Breakpoint.xs: 2.0,
    Breakpoint.sm: 2.0,
    Breakpoint.md: 3.0,
    Breakpoint.lg: 3.0,
    Breakpoint.xl: 4.0,
  };

  /// Çok küçük boşluk (4-8px)
  static const Map<Breakpoint, double> spaceXs = {
    Breakpoint.xs: 4.0,
    Breakpoint.sm: 5.0,
    Breakpoint.md: 6.0,
    Breakpoint.lg: 7.0,
    Breakpoint.xl: 8.0,
  };

  /// Küçük boşluk (8-16px)
  static const Map<Breakpoint, double> spaceSm = {
    Breakpoint.xs: 8.0,
    Breakpoint.sm: 10.0,
    Breakpoint.md: 12.0,
    Breakpoint.lg: 14.0,
    Breakpoint.xl: 16.0,
  };

  /// Normal boşluk (12-20px)
  static const Map<Breakpoint, double> spaceMd = {
    Breakpoint.xs: 12.0,
    Breakpoint.sm: 14.0,
    Breakpoint.md: 16.0,
    Breakpoint.lg: 18.0,
    Breakpoint.xl: 20.0,
  };

  /// Büyük boşluk (16-28px)
  static const Map<Breakpoint, double> spaceLg = {
    Breakpoint.xs: 16.0,
    Breakpoint.sm: 18.0,
    Breakpoint.md: 20.0,
    Breakpoint.lg: 24.0,
    Breakpoint.xl: 28.0,
  };

  /// Çok büyük boşluk (20-40px)
  static const Map<Breakpoint, double> spaceXl = {
    Breakpoint.xs: 20.0,
    Breakpoint.sm: 24.0,
    Breakpoint.md: 28.0,
    Breakpoint.lg: 32.0,
    Breakpoint.xl: 40.0,
  };

  /// Çok çok büyük boşluk (32-56px)
  static const Map<Breakpoint, double> spaceXxl = {
    Breakpoint.xs: 32.0,
    Breakpoint.sm: 38.0,
    Breakpoint.md: 44.0,
    Breakpoint.lg: 50.0,
    Breakpoint.xl: 56.0,
  };

  // =============================================
  // ICON BOYUTLARI
  // =============================================

  /// Çok küçük icon (12-16px)
  static const Map<Breakpoint, double> iconXs = {
    Breakpoint.xs: 12.0,
    Breakpoint.sm: 13.0,
    Breakpoint.md: 14.0,
    Breakpoint.lg: 15.0,
    Breakpoint.xl: 16.0,
  };

  /// Küçük icon (16-24px)
  static const Map<Breakpoint, double> iconSm = {
    Breakpoint.xs: 16.0,
    Breakpoint.sm: 18.0,
    Breakpoint.md: 20.0,
    Breakpoint.lg: 22.0,
    Breakpoint.xl: 24.0,
  };

  /// Normal icon (20-28px)
  static const Map<Breakpoint, double> iconMd = {
    Breakpoint.xs: 20.0,
    Breakpoint.sm: 22.0,
    Breakpoint.md: 24.0,
    Breakpoint.lg: 26.0,
    Breakpoint.xl: 28.0,
  };

  /// Büyük icon (24-40px)
  static const Map<Breakpoint, double> iconLg = {
    Breakpoint.xs: 24.0,
    Breakpoint.sm: 28.0,
    Breakpoint.md: 32.0,
    Breakpoint.lg: 36.0,
    Breakpoint.xl: 40.0,
  };

  /// Çok büyük icon (40-72px)
  static const Map<Breakpoint, double> iconXl = {
    Breakpoint.xs: 40.0,
    Breakpoint.sm: 48.0,
    Breakpoint.md: 56.0,
    Breakpoint.lg: 64.0,
    Breakpoint.xl: 72.0,
  };

  /// Devasa icon (80-120px) - Pusula vb.
  static const Map<Breakpoint, double> iconXxl = {
    Breakpoint.xs: 80.0,
    Breakpoint.sm: 90.0,
    Breakpoint.md: 100.0,
    Breakpoint.lg: 110.0,
    Breakpoint.xl: 120.0,
  };

  // =============================================
  // COMPONENT BOYUTLARI
  // =============================================

  /// Buton yüksekliği
  static const Map<Breakpoint, double> buttonHeight = {
    Breakpoint.xs: 36.0,
    Breakpoint.sm: 40.0,
    Breakpoint.md: 44.0,
    Breakpoint.lg: 48.0,
    Breakpoint.xl: 52.0,
  };

  /// Border radius
  static const Map<Breakpoint, double> borderRadius = {
    Breakpoint.xs: 12.0,
    Breakpoint.sm: 14.0,
    Breakpoint.md: 16.0,
    Breakpoint.lg: 18.0,
    Breakpoint.xl: 20.0,
  };
}

/// Breakpoint-Only Responsive Yardımcıları
class Responsive {
  Responsive._();

  // Cihaz tipi eşik değerleri
  static const double _desktopMinWidth = 1200.0;

  /// Cihaz tipini belirle (En güvenilir yöntem: en kısa kenar)
  static DeviceType deviceType(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    if (shortestSide >= _desktopMinWidth) return DeviceType.desktop;
    if (shortestSide >= 600.0) return DeviceType.tablet;
    return DeviceType.phone;
  }

  /// Tablet mi?
  static bool isTablet(BuildContext context) {
    return deviceType(context) == DeviceType.tablet;
  }

  /// Desktop mi?
  static bool isDesktop(BuildContext context) {
    return deviceType(context) == DeviceType.desktop;
  }

  /// Telefon mu?
  static bool isPhone(BuildContext context) {
    return deviceType(context) == DeviceType.phone;
  }

  /// Ekran özelliklerine göre breakpoint döndürür
  static Breakpoint breakpointOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final shortestSide = size.shortestSide;
    final isPhone = shortestSide < 600.0;

    // Telefonlar için her zaman phone-scale breakpoint'ler kullan
    if (isPhone) {
      if (shortestSide < 360) return Breakpoint.xs;
      if (shortestSide < 480) return Breakpoint.sm;
      return Breakpoint.md;
    }

    // Tablet ve Desktop için genişlik bazlı breakpoint'ler
    if (width < 840) return Breakpoint.lg;
    return Breakpoint.xl;
  }

  /// Token map'inden breakpoint'e uygun değeri döndürür
  static T token<T>(BuildContext context, Map<Breakpoint, T> tokens) {
    final bp = breakpointOf(context);
    return tokens[bp] ?? tokens.values.first;
  }

  /// Breakpoint'e göre değer seçimi
  static T value<T>(
    BuildContext context, {
    required T xs,
    T? sm,
    T? md,
    T? lg,
    T? xl,
  }) {
    final bp = breakpointOf(context);
    switch (bp) {
      case Breakpoint.xs:
        return xs;
      case Breakpoint.sm:
        return sm ?? xs;
      case Breakpoint.md:
        return md ?? sm ?? xs;
      case Breakpoint.lg:
        return lg ?? md ?? sm ?? xs;
      case Breakpoint.xl:
        return xl ?? lg ?? md ?? sm ?? xs;
    }
  }

  // =============================================
  // TOKEN KISA YOLLARI
  // =============================================

  /// Font boyutu - token bazlı
  static double fontSize(BuildContext context, FontSize size) {
    final tokens = switch (size) {
      FontSize.xs => ResponsiveTokens.fontXs,
      FontSize.sm => ResponsiveTokens.fontSm,
      FontSize.md => ResponsiveTokens.fontMd,
      FontSize.lg => ResponsiveTokens.fontLg,
      FontSize.xl => ResponsiveTokens.fontXl,
      FontSize.display => ResponsiveTokens.fontDisplay,
      FontSize.countdownNumber => ResponsiveTokens.fontCountdownNumber,
      FontSize.countdownUnit => ResponsiveTokens.fontCountdownUnit,
    };
    return token(context, tokens);
  }

  /// Spacing - token bazlı
  static double space(BuildContext context, SpaceSize size) {
    final tokens = switch (size) {
      SpaceSize.xxs => ResponsiveTokens.spaceXxs,
      SpaceSize.xs => ResponsiveTokens.spaceXs,
      SpaceSize.sm => ResponsiveTokens.spaceSm,
      SpaceSize.md => ResponsiveTokens.spaceMd,
      SpaceSize.lg => ResponsiveTokens.spaceLg,
      SpaceSize.xl => ResponsiveTokens.spaceXl,
      SpaceSize.xxl => ResponsiveTokens.spaceXxl,
    };
    return token(context, tokens);
  }

  /// Icon boyutu - token bazlı
  static double iconSize(BuildContext context, IconSizeLevel size) {
    final tokens = switch (size) {
      IconSizeLevel.xs => ResponsiveTokens.iconXs,
      IconSizeLevel.sm => ResponsiveTokens.iconSm,
      IconSizeLevel.md => ResponsiveTokens.iconMd,
      IconSizeLevel.lg => ResponsiveTokens.iconLg,
      IconSizeLevel.xl => ResponsiveTokens.iconXl,
      IconSizeLevel.xxl => ResponsiveTokens.iconXxl,
    };
    return token(context, tokens);
  }

  /// Buton yüksekliği - token bazlı
  static double buttonHeight(BuildContext context) {
    return token(context, ResponsiveTokens.buttonHeight);
  }

  /// Border radius - token bazlı
  static double borderRadius(BuildContext context) {
    return token(context, ResponsiveTokens.borderRadius);
  }

  // =============================================
  // CİHAZ TİPİ VE YARDIMCI METODLAR
  // =============================================

  /// Landscape (yatay) mı?
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Portrait (dikey) mi?
  static bool isPortrait(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.portrait;
  }

  /// Günlük içerik barı için önerilen yükseklik oranı (maks)
  static double dailyContentHeightRatio(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.xs:
        return 0.26;
      case Breakpoint.sm:
        return 0.30;
      case Breakpoint.md:
        return 0.33;
      case Breakpoint.lg:
        return 0.36;
      case Breakpoint.xl:
        return 0.38;
    }
  }

  /// Ekran genişliğinin yüzdesi
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.sizeOf(context).width * (percent / 100);
  }

  /// Ekran yüksekliğinin yüzdesi
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.sizeOf(context).height * (percent / 100);
  }

  /// Grid column sayısı (responsive)
  static int gridColumns(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.xs:
        return 1;
      case Breakpoint.sm:
        return 2;
      case Breakpoint.md:
        return 2;
      case Breakpoint.lg:
        return 3;
      case Breakpoint.xl:
        return 4;
    }
  }

  /// Safe area padding'i dikkate alan padding
  static EdgeInsets safeAreaPadding(BuildContext context, EdgeInsets base) {
    final safePadding = MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      left: base.left + safePadding.left,
      top: base.top + safePadding.top,
      right: base.right + safePadding.right,
      bottom: base.bottom + safePadding.bottom,
    );
  }
}

/// BuildContext extension - Kolay erişim için
extension ContextScreenX on BuildContext {
  // =============================================
  // EKRAN BOYUTLARI
  // =============================================

  /// Ekran boyutu
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Ekran genişliği
  double get screenWidth => screenSize.width;

  /// Ekran yüksekliği
  double get screenHeight => screenSize.height;

  // =============================================
  // BREAKPOINT VE CİHAZ TİPİ
  // =============================================

  /// Mevcut breakpoint
  Breakpoint get breakpoint => Responsive.breakpointOf(this);

  /// Mevcut cihaz tipi
  DeviceType get deviceType => Responsive.deviceType(this);

  /// Tablet mi?
  bool get isTablet => Responsive.isTablet(this);

  /// Desktop mi?
  bool get isDesktop => Responsive.isDesktop(this);

  /// Telefon mu?
  bool get isPhone => Responsive.isPhone(this);

  /// Landscape mi?
  bool get isLandscape => Responsive.isLandscape(this);

  /// Portrait mi?
  bool get isPortrait => Responsive.isPortrait(this);

  // =============================================
  // YENİ TOKEN-BASED API
  // =============================================

  /// Font boyutu - token bazlı
  double font(FontSize size) => Responsive.fontSize(this, size);

  /// Spacing (padding/margin) - token bazlı
  double space(SpaceSize size) => Responsive.space(this, size);

  /// Icon boyutu - token bazlı
  double icon(IconSizeLevel size) => Responsive.iconSize(this, size);

  // =============================================
  // YÜZDE BAZLI BOYUTLANDIRMA
  // =============================================

  /// Ekran genişliğinin yüzdesi
  double widthPercent(double percent) => Responsive.widthPercent(this, percent);

  /// Ekran yüksekliğinin yüzdesi
  double heightPercent(double percent) =>
      Responsive.heightPercent(this, percent);

  // =============================================
  // DİĞER YARDIMCILAR
  // =============================================

  /// Grid column sayısı
  int get gridColumns => Responsive.gridColumns(this);

  /// Safe area padding
  EdgeInsets safeAreaPadding(EdgeInsets base) =>
      Responsive.safeAreaPadding(this, base);
}
