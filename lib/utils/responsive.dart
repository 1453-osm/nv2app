import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Uygulama genelinde profesyonel responsive davranış için kırılım noktaları
enum Breakpoint { xs, sm, md, lg, xl }

/// Responsive yardımcıları: ölçekleme, breakpoint seçimi, rem vb.
class Responsive {
  // iPhone 12/13 benzeri referans genişlik (uygulama tasarımının temeli)
  static const double _referenceWidth = 390.0;
  static const double _referenceHeight = 844.0;

  /// Ekran genişliğine göre breakpoint döndürür
  static Breakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return Breakpoint.xs;
    if (width < 480) return Breakpoint.sm;
    if (width < 600) return Breakpoint.md;
    if (width < 840) return Breakpoint.lg;
    return Breakpoint.xl;
  }

  /// Genişlik ve yükseklikten dengeli bir ölçek faktörü hesaplar.
  /// Aşırı büyümeyi/ küçülmeyi engellemek için makul sınırlar uygular.
  static double scale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthScale = size.width / _referenceWidth;
    final heightScale = size.height / _referenceHeight;
    final balanced = math.sqrt(widthScale * heightScale);
    return balanced.clamp(0.85, 1.25);
  }

  /// Ölçekli boyut (rem benzeri)
  static double rem(BuildContext context, double base) => base * scale(context);

  /// Breakpoint'e göre değer seçimi
  static T value<T>(BuildContext context, {
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
}

extension ContextScreenX on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  Breakpoint get breakpoint => Responsive.breakpointOf(this);
  double rem(double base) => Responsive.rem(this, base);
}


