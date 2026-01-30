import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../viewmodels/location_bar_viewmodel.dart';
import '../models/location_model.dart';
import '../models/prayer_times_model.dart';
import '../utils/constants.dart';
import '../utils/prayer_name_helper.dart';
import '../utils/arabic_numbers_helper.dart';
import '../utils/error_messages.dart';
import 'dart:ui';
import 'daily_content_bar.dart';
import '../utils/responsive.dart';
import '../models/religious_day.dart';
import '../services/prayer_times_service.dart';

// Ay kısaltmaları - context gerektirir
String _getMonthAbbreviation(BuildContext context, int month) {
  final localizations = AppLocalizations.of(context)!;
  final months = [
    '',
    localizations.january,
    localizations.february,
    localizations.march,
    localizations.april,
    localizations.may,
    localizations.june,
    localizations.july,
    localizations.august,
    localizations.september,
    localizations.october,
    localizations.november,
    localizations.december,
  ];
  return months[month];
}

DateTime? _parsePrayerDate(PrayerTime prayer) {
  if (prayer.gregorianDateShortIso8601.isNotEmpty) {
    final parsed = DateTime.tryParse(prayer.gregorianDateShortIso8601);
    if (parsed != null) return parsed;
  }
  final parts = prayer.gregorianDateShort.split('.');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}

Widget _buildVerticalDivider(BuildContext context, Color baseColor) {
  return Container(
    width: 1,
    height: context.space(SpaceSize.lg),
    margin: EdgeInsets.symmetric(horizontal: context.space(SpaceSize.xxs)),
    decoration: BoxDecoration(
      color: baseColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(0.5),
    ),
  );
}

// Responsive değerleri hesaplayan yardımcı sınıf - Token bazlı
class _ResponsiveValues {
  final double titleFontSize;
  final double numberFontSize;
  final double unitFontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double spacingHeight;

  const _ResponsiveValues({
    required this.titleFontSize,
    required this.numberFontSize,
    required this.unitFontSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.spacingHeight,
  });

  /// Token bazlı factory - breakpoint'e göre sabit değerler
  factory _ResponsiveValues.fromContext(BuildContext context) {
    final isLandscape = context.isLandscape;
    final isPhone = context.isPhone;
    final screenHeight = context.screenHeight;

    // Yatay modda (özellikle telefonlarda) alan aşırı kısıtlıdır (genelde 320-400px arası)
    final bool isCompact = isLandscape && isPhone;

    // Katsayılar (Landscape phone için küçültme ama okunaklılık korunsun)
    final double fontFactor = isCompact ? 0.65 : 1.0;
    final double spacingFactor = isCompact ? 0.5 : 1.0;

    return _ResponsiveValues(
      titleFontSize: (context.font(FontSize.lg) * fontFactor).clamp(10.0, 18.0),
      numberFontSize: isCompact
          ? (screenHeight * 0.26)
              .clamp(35.0, 75.0) // %24 -> %26 ve clamp sınırları artırıldı
          : context.font(FontSize.countdownNumber),
      unitFontSize: isCompact
          ? (screenHeight * 0.17)
              .clamp(18.0, 32.0) // %15 -> %17 ve clamp sınırları artırıldı
          : context.font(FontSize.countdownUnit),
      horizontalPadding: context.space(SpaceSize.lg),
      verticalPadding: context.space(SpaceSize.xxs) * spacingFactor,
      spacingHeight: context.space(SpaceSize.sm) * spacingFactor,
    );
  }
}

// Shimmer efekti için üst seviye sınıflar
class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;

  const _ShimmerEffect({required this.child, required this.isActive});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.shimmer,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.easeInOut,
    ));

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ShimmerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final double animValue = _animation.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.4),
                Colors.white.withValues(alpha: 0.8),
                Colors.transparent,
              ],
              stops: [
                (animValue - 0.4).clamp(0.0, 1.0),
                (animValue - 0.2).clamp(0.0, 1.0),
                animValue.clamp(0.0, 1.0),
                (animValue + 0.2).clamp(0.0, 1.0),
                (animValue + 0.4).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

// Animasyonlu blur modal widget'ı
class _AnimatedBlurModal extends StatefulWidget {
  final Widget child;
  final ValueNotifier<double>?
      extentNotifier; // Modal yüksekliğini takip etmek için

  const _AnimatedBlurModal({
    required this.child,
    this.extentNotifier,
  });

  @override
  State<_AnimatedBlurModal> createState() => _AnimatedBlurModalState();
}

class _AnimatedBlurModalState extends State<_AnimatedBlurModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isClosing = false;
  late final ValueNotifier<double> _fallbackExtentNotifier;

  bool get isClosing => _isClosing;

  @override
  void initState() {
    super.initState();
    _fallbackExtentNotifier = ValueNotifier<double>(1.0);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    )..forward();

    // Açılış için optimize edilmiş blur animasyonu (daha yumuşak)
    _blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Açılış için optimize edilmiş opacity animasyonu
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Açılış için optimize edilmiş slide animasyonu (daha dinamik)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _handleBackPress() {
    if (_isClosing) return;
    _isClosing = true;
    // Kapanış için daha hızlı ve keskin animasyon
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _closeModal() {
    if (_isClosing) return;
    _isClosing = true;
    // Kapanış animasyonu için optimize edilmiş curve
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void closeModal() {
    _closeModal();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          widget.extentNotifier ?? _fallbackExtentNotifier,
        ]),
        builder: (context, child) {
          // Modal yüksekliğine göre blur hesapla (0.0 = kapalı, 1.0 = tam açık)
          final extent =
              (widget.extentNotifier ?? _fallbackExtentNotifier).value;
          // Blur modal açıldığında olmalı, kapandığında kapanmalı
          // extent: 0.0 (kapalı) -> blur: 0, extent: 1.0 (açık) -> blur: maksimum
          // Kapanış animasyonu sırasında da blur'un kapanması için _blurAnimation ile çarpıyoruz
          final blurMultiplier = _blurAnimation.value * extent.clamp(0.0, 1.0);

          return Stack(
            children: [
              // Tam ekran overlay: blur + renkli katman, modal yüksekliğine göre değişir
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeModal,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: ModalConstants.blurSigma * blurMultiplier,
                      sigmaY: ModalConstants.blurSigma * blurMultiplier,
                    ),
                    child: Opacity(
                      opacity: _opacityAnimation.value * extent.clamp(0.0, 1.0),
                      child: Container(
                        color: ModalConstants.getOverlayColor(context),
                      ),
                    ),
                  ),
                ),
              ),

              // Modal içeriği: sadece slide + fade
              SlideTransition(
                position: _slideAnimation,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Animasyonlu modal içeriği
class _AnimatedModalContent extends StatefulWidget {
  final ScrollController scrollController;
  final List<PrayerTime> monthlyTimes;
  final DateTime today;
  final ValueNotifier<double>? extentNotifier;

  const _AnimatedModalContent({
    required this.scrollController,
    required this.monthlyTimes,
    required this.today,
    this.extentNotifier,
  });

  @override
  _AnimatedModalContentState createState() => _AnimatedModalContentState();
}

class _ParsedPrayerRow {
  final PrayerTime prayer;
  final DateTime? date;
  final String dayStr;
  final String monthStr;
  final bool isToday;

  const _ParsedPrayerRow({
    required this.prayer,
    required this.date,
    required this.dayStr,
    required this.monthStr,
    required this.isToday,
  });
}

class _AnimatedModalContentState extends State<_AnimatedModalContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late List<_ParsedPrayerRow> _rows;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    )..forward();
    // _rows will be built in build method when context is available

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedModalContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // _rows will be rebuilt in build method when context is available
  }

  List<_ParsedPrayerRow> _buildParsedRows(
      List<PrayerTime> items, DateTime today) {
    if (!mounted) return [];
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    return items.map((prayer) {
      final date = _parsePrayerDate(prayer);
      final isToday = date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final rawDayStr = date != null
          ? '${date.day}'
          : prayer.gregorianDateShort.split('.').first;
      final dayStr = isArabic ? localizeNumerals(rawDayStr, 'ar') : rawDayStr;
      final monthStr = date != null && mounted
          ? _getMonthAbbreviation(context, date.month)
          : '';

      return _ParsedPrayerRow(
        prayer: prayer,
        date: date,
        dayStr: dayStr,
        monthStr: monthStr,
        isToday: isToday,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Build rows when context is available
    _rows = _buildParsedRows(widget.monthlyTimes, widget.today);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onTap: () {}, // Modal içeriğine tıklayınca kapanmasın
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(GlassBarConstants.borderRadius)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassBarConstants.blurmSigma,
                    sigmaY: GlassBarConstants.blurmSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: GlassBarConstants.getBackgroundColor(context),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(GlassBarConstants.borderRadius)),
                      border: Border.all(
                          color: GlassBarConstants.getBorderColor(context),
                          width: GlassBarConstants.borderWidth),
                    ),
                    child: CustomScrollView(
                      controller: widget.scrollController,
                      slivers: [
                        // Üst handle + Başlık - Sürüklenebilir alan
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.only(top: 12, bottom: 16),
                            child: Column(
                              children: [
                                // Handle - sürüklenebilir alan için görsel ipucu
                                Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: GlassBarConstants.getBorderColor(
                                        context),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Başlık - bu alan da sürüklenebilir (DraggableScrollableSheet sayesinde)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .monthlyPrayerTimes,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: GlassBarConstants.getTextColor(
                                              context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tablo başlık satırı
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: GlassBarConstants.getTextColor(context)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      AppLocalizations.of(context)!.date,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                GlassBarConstants.getTextColor(
                                                    context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        AppLocalizations.of(context)!.imsak,
                                        AppLocalizations.of(context)!.gunes,
                                        AppLocalizations.of(context)!.ogle,
                                        AppLocalizations.of(context)!.ikindi,
                                        AppLocalizations.of(context)!.aksam,
                                        AppLocalizations.of(context)!.yatsi,
                                      ]
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final index = entry.key;
                                            final name = entry.value;
                                            return [
                                              if (index > 0)
                                                _buildVerticalDivider(
                                                    context,
                                                    GlassBarConstants
                                                        .getTextColor(context)),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: GlassBarConstants
                                                            .getTextColor(
                                                                context),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 11,
                                                      ),
                                                ),
                                              ),
                                            ];
                                          })
                                          .expand((list) => list)
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Liste
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final row = _rows[index];
                                final prayer = row.prayer;
                                final isToday = row.isToday;
                                final dayStr = row.dayStr;
                                final monthStr = row.monthStr;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? GlassBarConstants.getTextColor(
                                                context)
                                            .withValues(alpha: 0.12)
                                        : index.isEven
                                            ? GlassBarConstants.getTextColor(
                                                    context)
                                                .withValues(alpha: 0.03)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isToday
                                        ? Border.all(
                                            color:
                                                GlassBarConstants.getTextColor(
                                                        context)
                                                    .withValues(alpha: 0.25),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Tarih kısmı
                                      SizedBox(
                                        width: 40,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              dayStr,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: GlassBarConstants
                                                        .getTextColor(context),
                                                    fontWeight: isToday
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                            if (monthStr.isNotEmpty)
                                              Text(
                                                monthStr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                              .getTextColor(
                                                                  context)
                                                          .withValues(
                                                              alpha: 0.7),
                                                      fontSize: 9,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Namaz vakitleri
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                prayer.fajr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                            _buildVerticalDivider(
                                                context,
                                                GlassBarConstants.getTextColor(
                                                    context)),
                                            Expanded(
                                              child: Text(
                                                prayer.sunrise,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                            _buildVerticalDivider(
                                                context,
                                                GlassBarConstants.getTextColor(
                                                    context)),
                                            Expanded(
                                              child: Text(
                                                prayer.dhuhr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                            _buildVerticalDivider(
                                                context,
                                                GlassBarConstants.getTextColor(
                                                    context)),
                                            Expanded(
                                              child: Text(
                                                prayer.asr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                            _buildVerticalDivider(
                                                context,
                                                GlassBarConstants.getTextColor(
                                                    context)),
                                            Expanded(
                                              child: Text(
                                                prayer.maghrib,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                            _buildVerticalDivider(
                                                context,
                                                GlassBarConstants.getTextColor(
                                                    context)),
                                            Expanded(
                                              child: Text(
                                                prayer.isha,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: GlassBarConstants
                                                          .getTextColor(
                                                              context),
                                                      fontWeight: isToday
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: _rows.length,
                            ),
                          ),
                        ),

                        // Alt boşluk
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dini günler modal içeriği (aylık modal estetiğiyle uyumlu)
class _ReligiousDaysContent extends StatefulWidget {
  final ScrollController scrollController;
  final List<DetectedReligiousDay> items;
  final DateTime today;

  const _ReligiousDaysContent({
    required this.scrollController,
    required this.items,
    required this.today,
  });

  @override
  State<_ReligiousDaysContent> createState() => _ReligiousDaysContentState();
}

class _ReligiousDaysContentState extends State<_ReligiousDaysContent> {
  late Map<int, List<DetectedReligiousDay>> _yearItems;
  late PageController _pageController;
  late List<ScrollController> _scrollControllers;
  int _currentPage = 1; // 0: prev, 1: current, 2: next

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _scrollControllers = List.generate(3, (_) => ScrollController());
    _prepareItems();

    // Modal açılınca tüm yıllar için veri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentYear = widget.today.year;
        final vm = context.read<PrayerTimesViewModel>();
        final years = [currentYear - 1, currentYear, currentYear + 1];
        vm.loadReligiousDaysForYears(years);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ReligiousDaysContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.items, oldWidget.items) ||
        widget.today != oldWidget.today) {
      _currentPage = 1;
      _prepareItems();
    }
  }

  void _prepareItems() {
    final sorted = widget.items.toList()
      ..sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    final currentYear = widget.today.year;
    _yearItems = {
      currentYear - 1:
          sorted.where((item) => item.year == currentYear - 1).toList(),
      currentYear: sorted.where((item) => item.year == currentYear).toList(),
      currentYear + 1:
          sorted.where((item) => item.year == currentYear + 1).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final baseYear = widget.today.year;
    final years = [baseYear - 1, baseYear, baseYear + 1];

    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(GlassBarConstants.borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassBarConstants.blurmSigma,
            sigmaY: GlassBarConstants.blurmSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(GlassBarConstants.borderRadius)),
              border: Border.all(
                  color: GlassBarConstants.getBorderColor(context),
                  width: GlassBarConstants.borderWidth),
            ),
            child: Column(
              children: [
                // Sabit Başlık Alanı - Sayfa geçişlerinden etkilenmez
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: GlassBarConstants.getBorderColor(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Başlık
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          AppLocalizations.of(context)!.religiousDays,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: GlassBarConstants.getTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Yıl Seçiciler
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(years.length, (i) {
                          final isSelected = i == _currentPage;
                          final year = years[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isSelected ? 1.0 : 0.45,
                              child: Text(
                                '$year',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: GlassBarConstants.getTextColor(
                                          context),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Kaydırılabilir İçerik (PageView + Slivers)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 3,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      // Sayfa değiştiğinde ilgili yılın verilerini yükle
                      final year = baseYear + (index - 1);
                      final vm = context.read<PrayerTimesViewModel>();
                      // Eğer bu yılın verisi yoksa yükle
                      final yearItems = _yearItems[year] ?? [];
                      if (yearItems.isEmpty) {
                        vm.loadReligiousDaysForYears([year]);
                      }
                    },
                    itemBuilder: (context, index) {
                      final year = baseYear + (index - 1);
                      final items =
                          _yearItems[year] ?? const <DetectedReligiousDay>[];
                      final isCurrentPage = index == _currentPage;
                      final ScrollController controller = isCurrentPage
                          ? widget.scrollController
                          : _scrollControllers[index];

                      return CustomScrollView(
                        key: ValueKey('religious-days-$year'),
                        controller: controller,
                        slivers: [
                          if (items.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .noReligiousDaysThisYear,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: GlassBarConstants.getTextColor(
                                                  context)
                                              .withValues(alpha: 0.8),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, idx) {
                                    final item = items[idx];
                                    final isToday = item.gregorianDate.year ==
                                            widget.today.year &&
                                        item.gregorianDate.month ==
                                            widget.today.month &&
                                        item.gregorianDate.day ==
                                            widget.today.day;
                                    final localeTag =
                                        _preferredLocaleTag(context);
                                    final localizedTitle =
                                        item.getLocalizedName(localeTag);
                                    final localizedHijriDate =
                                        item.getLocalizedHijriDate(localeTag);
                                    return Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? GlassBarConstants
                                                        .getTextColor(context)
                                                    .withValues(alpha: 0.12)
                                                : idx.isEven
                                                    ? GlassBarConstants
                                                            .getTextColor(
                                                                context)
                                                        .withValues(alpha: 0.03)
                                                    : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: isToday
                                                ? Border.all(
                                                    color: GlassBarConstants
                                                            .getTextColor(
                                                                context)
                                                        .withValues(
                                                            alpha: 0.25),
                                                    width: 1,
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 70,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final locale =
                                                            Localizations
                                                                .localeOf(
                                                                    context);
                                                        final isArabic = locale
                                                                .languageCode ==
                                                            'ar';
                                                        final rawDayStr = item
                                                            .gregorianDateShort
                                                            .split('.')
                                                            .first;
                                                        final dayStr = isArabic
                                                            ? localizeNumerals(
                                                                rawDayStr, 'ar')
                                                            : rawDayStr;
                                                        return Text(
                                                          dayStr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    color: GlassBarConstants
                                                                        .getTextColor(
                                                                            context),
                                                                    fontWeight: isToday
                                                                        ? FontWeight
                                                                            .w600
                                                                        : FontWeight
                                                                            .w500,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                        );
                                                      },
                                                    ),
                                                    Text(
                                                      _monthAbbrev(
                                                          context,
                                                          item.gregorianDate
                                                              .month),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: GlassBarConstants
                                                                    .getTextColor(
                                                                        context)
                                                                .withValues(
                                                                    alpha: 0.7),
                                                            fontSize: 9,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      localizedTitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: GlassBarConstants
                                                                .getTextColor(
                                                                    context),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      localizedHijriDate,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: GlassBarConstants
                                                                    .getTextColor(
                                                                        context)
                                                                .withValues(
                                                                    alpha:
                                                                        0.75),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (idx < items.length - 1)
                                          const SizedBox(height: 2),
                                      ],
                                    );
                                  },
                                  childCount: items.length,
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthAbbrev(BuildContext context, int month) {
    return _getMonthAbbreviation(context, month);
  }

  String _preferredLocaleTag(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode.toLowerCase();
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return languageCode;
    }
    return '$languageCode-${countryCode.toLowerCase()}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class PrayerTimesSection extends StatefulWidget {
  final SelectedLocation location;
  const PrayerTimesSection({super.key, required this.location});

  @override
  State<PrayerTimesSection> createState() => _PrayerTimesSectionState();
}

class _PrayerTimesSectionState extends State<PrayerTimesSection> {
  final ValueNotifier<double> _expandAnimationNotifier =
      ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _expandAnimationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PrayerTimesViewModel,
        (bool, bool, PrayerTime?, ErrorCode?, String?, bool, bool)>(
      selector: (context, vm) => (
        vm.showSkeleton,
        vm.isLoading,
        vm.todayPrayerTimes,
        vm.errorCode,
        vm.errorMessage,
        vm.isKerahatTime(),
        vm.getReligiousDayAlert(context) != null,
      ),
      builder: (context, data, _) {
        final (
          showSkeleton,
          isLoading,
          prayerTimesData,
          errorCode,
          errorMessage,
          isKerahatNow,
          hasReligiousAlertNow
        ) = data;
        final vm = context.read<PrayerTimesViewModel>();

        if (showSkeleton || (isLoading && prayerTimesData == null)) {
          return _buildSkeletonLoading(context);
        }
        if (errorCode != null || errorMessage != null) {
          return _buildErrorInStack(context, vm, widget.location);
        }

        final rawPrayerTimes = vm.getFormattedTodayPrayerTimes();
        // Namaz vakitleri isimlerini çevir (key'i sakla çünkü ikonlar için gerekli)
        final localizedPrayerTimes =
            rawPrayerTimes.map((key, value) => MapEntry(
                  PrayerNameHelper.getLocalizedPrayerName(context, key),
                  value,
                ));
        // Orijinal key'leri sakla (ikonlar için)
        final prayerKeyMap = <String, String>{};
        rawPrayerTimes.forEach((key, value) {
          final localizedName =
              PrayerNameHelper.getLocalizedPrayerName(context, key);
          prayerKeyMap[localizedName] = key;
        });
        final todayDate = vm.getTodayDate();
        final hijriDate = vm.getHijriDate();
        final screenHeight = MediaQuery.of(context).size.height;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => context.read<LocationBarViewModel>().collapse(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: isLandscape ? screenHeight * 0.01 : screenHeight * 0.08,
              left: 0,
              right: 0,
              bottom: 0,
              child: Builder(
                builder: (context) {
                  final safePadding = MediaQuery.of(context).padding;
                  // Yatay modda simetrik padding için sol ve sağın maksimumunu al
                  final horizontalSafePadding = isLandscape && context.isPhone
                      ? (safePadding.left > safePadding.right
                              ? safePadding.left
                              : safePadding.right) +
                          8.0
                      : 0.0;

                  return Padding(
                    // Ekran genelindeki safe area ve buton boşluklarını yönet
                    padding: EdgeInsets.only(
                      top: isLandscape
                          ? (context.isPhone
                              ? context.space(SpaceSize.xxl) * 1.3
                              : context.space(SpaceSize.xxl) * 1.5)
                          : 4.0, // Dikey modda Positioned.top zaten pay bırakıyor
                      bottom: safePadding.bottom,
                      left: horizontalSafePadding,
                      right: horizontalSafePadding,
                    ),
                    child: isLandscape
                    ? (context.isPhone
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Sol Sütun: Geri Sayım, Tarih ve Vakitler
                              Expanded(
                                flex: 6,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    // Üst: Geri Sayım ve uyarılar
                                    Flexible(
                                      flex: 6,
                                      child: ClipRect(
                                        child: _buildCountdownCard(context),
                                      ),
                                    ),

                                    // Orta: Tarih (sabit, esnemez)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2.0),
                                      child: _buildDateCard(context, todayDate,
                                          hijriDate, widget.location),
                                    ),

                                    // Alt: Vakitler (Yatay ikonlu düzen)
                                    Flexible(
                                      flex: 4,
                                      child: ClipRect(
                                        child: _buildTodayPrayerTimesCard(
                                            context,
                                            localizedPrayerTimes,
                                            _expandAnimationNotifier,
                                            prayerKeyMap),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Orta Boşluk
                              SizedBox(width: context.space(SpaceSize.sm)),
                              // Sağ Sütun: Günlük İçerik Barı
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: context.space(SpaceSize.xs)),
                                  child: DailyContentBar(
                                      expandAnimationNotifier:
                                          _expandAnimationNotifier),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Sol Sütun: Countdown, Tarih ve İçerik Barı
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Geri sayım ve uyarılar
                                    _buildCountdownCard(context),
                                    // Tarih
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: _buildDateCard(context, todayDate,
                                          hijriDate, widget.location),
                                    ),
                                    const SizedBox(height: 8),
                                    // İçerik barı arta kalan alanı kullansın
                                    Expanded(
                                      child: DailyContentBar(
                                          expandAnimationNotifier:
                                              _expandAnimationNotifier),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: context.space(SpaceSize.md)),
                              // Sağ Sütun: Vakit Kartları (Dikey Liste)
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: _buildTodayPrayerTimesCard(
                                      context,
                                      localizedPrayerTimes,
                                      _expandAnimationNotifier,
                                      prayerKeyMap),
                                ),
                              ),
                            ],
                          ))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return ValueListenableBuilder<double>(
                            valueListenable: _expandAnimationNotifier,
                            builder: (context, expandValue, child) {
                              final double t = expandValue.clamp(0.0, 1.0);

                              // 1. Bar Kapalı Yüksekliği
                              final double collapsedBarHeight =
                                  Responsive.value<double>(context,
                                      xs: 55.0,
                                      sm: 59.0,
                                      md: 62.0,
                                      lg: 68.0,
                                      xl: 75.0);

                              // 2. Vakit Kartlarının Yatay Moddaki Yüksekliği
                              final double horizontalPrayerHeight =
                                  Responsive.value<double>(context,
                                      xs: 81.0,
                                      sm: 86.0,
                                      md: 90.0,
                                      lg: 100.0,
                                      xl: 110.0);

                              // 3. Üst Bölüm Rezerve Alanı (Geri sayım + Uyarılar + Tarih)
                              final double baseTopReserved =
                                  Responsive.value<double>(context,
                                      xs: 180.0,
                                      sm: 210.0,
                                      md: 240.0,
                                      lg: 270.0,
                                      xl: 300.0);

                              // Uyarıların (Kerahat/Dini Gün) varlığını Selector verilerinden al
                              final bool hasAnyAlert =
                                  isKerahatNow || hasReligiousAlertNow;

                              // Uyarılar varken rezerve edilen alanı dinamik olarak artır
                              final double alertSpace = hasAnyAlert
                                  ? Responsive.value<double>(context,
                                      xs: 35, sm: 40, md: 45, lg: 50, xl: 55)
                                  : 0.0;

                              final double totalTopReserved =
                                  baseTopReserved + alertSpace;

                              // 4. Vakit Kartları İçin Gereken Minimum Alan
                              // Kullanıcının tercih ettiği şekilde sadece horizontalPrayerHeight
                              final double minPrayerArea =
                                  horizontalPrayerHeight;

                              // Bar'ın hedef expand yüksekliği: Toplam - Üst - Vakitler
                              final double maxBarHeight =
                                  (constraints.maxHeight -
                                          totalTopReserved -
                                          minPrayerArea)
                                      .clamp(collapsedBarHeight + 100.0,
                                          constraints.maxHeight * 0.80);

                              final double currentBarHeight = lerpDouble(
                                  collapsedBarHeight, maxBarHeight, t)!;

                              // Simetrik boşluk değerleri
                              final double sectionSpacing =
                                  context.space(SpaceSize.sm);
                              final double horizontalPadding =
                                  context.space(SpaceSize.lg);

                              return Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Üst Bölüm: Stabil Geri Sayım ve Tarih
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(height: sectionSpacing * 0.3),
                                      _buildCountdownCard(context),
                                      // Uyarı badge'leri varken boşluğu artır
                                      SizedBox(
                                          height: hasAnyAlert
                                              ? sectionSpacing * 0.8
                                              : sectionSpacing * 1.4),
                                      _buildDateCard(context, todayDate,
                                          hijriDate, widget.location),
                                    ],
                                  ),

                                  // Orta Bölüm: Arta Kalan Tüm Alanı Kullanan Vakit Kartları
                                  // Bar genişledikçe bu alan otomatik olarak daralacak.
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          top: sectionSpacing * 0.8),
                                      child: _buildTodayPrayerTimesCard(
                                          context,
                                          localizedPrayerTimes,
                                          _expandAnimationNotifier,
                                          prayerKeyMap),
                                    ),
                                  ),

                                  // Alt Bölüm: Günlük İçerik Barı
                                  // SizedBox kullanarak Expanded alanı üzerinden tam kontrol sağlıyoruz.
                                  SizedBox(
                                    height: currentBarHeight,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: horizontalPadding),
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: DailyContentBar(
                                            expandAnimationNotifier:
                                                _expandAnimationNotifier),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCountdownCard(BuildContext context) {
    return Selector<PrayerTimesViewModel,
        (CountdownFormat, Duration?, String?)>(
      selector: (_, vm) => (
        vm.countdownFormat,
        vm.timeUntilNextPrayer,
        vm.nextPrayerName,
      ),
      builder: (context, data, _) {
        final (countdownFormat, timeUntilNextPrayer, nextPrayerName) = data;
        final vm = context.read<PrayerTimesViewModel>();
        final localizations = AppLocalizations.of(context)!;

        final countdown = vm.getFormattedCountdown(
          hourText: localizations.hour,
          minuteText: localizations.minute,
          minuteShortText: localizations.minuteShort,
          secondText: localizations.second,
        );
        final isHms = vm.isHmsFormat;
        final isKerahat = vm.isKerahatTime();
        final religiousAlert = vm.getReligiousDayAlert(context);

        if (countdown.isEmpty || nextPrayerName == null) {
          return const SizedBox.shrink();
        }

        final responsiveValues = _ResponsiveValues.fromContext(context);
        final bool hasAnyAlert = isKerahat || religiousAlert != null;

        final isLandscapePhone = context.isLandscape && context.isPhone;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isLandscapePhone
                ? responsiveValues.horizontalPadding * 0.5
                : responsiveValues.horizontalPadding,
            vertical: isLandscapePhone
                ? 0.0
                : (context.isLandscape
                    ? responsiveValues.verticalPadding * 0.4
                    : responsiveValues.verticalPadding),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Üst Metin: "Sıradaki Vakit: İmsak"
              Text(
                nextPrayerName.isNotEmpty
                    ? AppLocalizations.of(context)!.nextPrayerTime(
                        PrayerNameHelper.getLocalizedPrayerName(
                            context, nextPrayerName))
                    : AppLocalizations.of(context)!.calculatingTime,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: GlassBarConstants.getTextColor(context)
                          .withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: responsiveValues.titleFontSize,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsiveValues.spacingHeight),
              // Geri sayım (tıklanabilir)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await vm.toggleCountdownFormat();
                },
                child: isHms
                    ? Text(
                        countdown,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: GlassBarConstants.getTextColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: responsiveValues.numberFontSize,
                              letterSpacing: 1.0,
                            ),
                        textAlign: TextAlign.center,
                      )
                    : Text.rich(
                        TextSpan(
                          children:
                              countdown.split(' ').expand<InlineSpan>((part) {
                            final locale = Localizations.localeOf(context);
                            final isArabic = locale.languageCode == 'ar';
                            final numberPattern = isArabic
                                ? RegExp(r'[0-9٠-٩]+')
                                : RegExp(r'\d+');
                            final nonNumberPattern = isArabic
                                ? RegExp(r'[^0-9٠-٩]+')
                                : RegExp(r'\D+');

                            final number =
                                part.replaceAll(nonNumberPattern, '');
                            final unit =
                                part.replaceAll(numberPattern, '') + ' ';
                            return [
                              TextSpan(
                                text: number,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: GlassBarConstants.getTextColor(
                                          context),
                                      fontWeight: FontWeight.w800,
                                      fontSize: responsiveValues.numberFontSize,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              TextSpan(
                                text: unit,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: GlassBarConstants.getTextColor(
                                          context),
                                      fontWeight: FontWeight.w500,
                                      fontSize: responsiveValues.unitFontSize,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ];
                          }).toList(),
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),

              // Uyarılar - Alt bölümde doğal akışta yer alır
              if (hasAnyAlert) ...[
                SizedBox(
                    height: isLandscapePhone
                        ? 2.0
                        : responsiveValues.spacingHeight),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (religiousAlert != null)
                        _buildReligiousDayWarning(
                            context, religiousAlert, responsiveValues),
                      if (religiousAlert != null && isKerahat)
                        const SizedBox(width: 4),
                      if (isKerahat)
                        _buildKerahatWarning(context, responsiveValues),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Dini gün uyarı widget'ı
  Widget _buildReligiousDayWarning(BuildContext context, String message,
      _ResponsiveValues responsiveValues) {
    final isLandscapePhone = context.isLandscape && context.isPhone;
    return ClipRRect(
      borderRadius: BorderRadius.circular(isLandscapePhone ? 8 : 12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscapePhone ? 6 : 10,
          vertical: isLandscapePhone ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(isLandscapePhone ? 8 : 12),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
            width: isLandscapePhone ? 1.0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Altın sarısı uyarı noktası (animasyonlu)
            const _ReligiousDayDot(),
            SizedBox(width: isLandscapePhone ? 4 : 6),
            // Uyarı metni
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GlassBarConstants.getTextColor(context)
                        .withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: isLandscapePhone
                        ? 9.0
                        : (responsiveValues.titleFontSize * 0.72)
                            .clamp(11.0, 15.0),
                    letterSpacing: 0.2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Kerahat vakti uyarı widget'ı
  Widget _buildKerahatWarning(
      BuildContext context, _ResponsiveValues responsiveValues) {
    final isLandscapePhone = context.isLandscape && context.isPhone;
    return ClipRRect(
      borderRadius: BorderRadius.circular(isLandscapePhone ? 8 : 12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscapePhone ? 6 : 10,
          vertical: isLandscapePhone ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(isLandscapePhone ? 8 : 12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: isLandscapePhone ? 1.0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kırmızı uyarı noktası (animasyonlu)
            _KerahatDot(),
            SizedBox(width: isLandscapePhone ? 4 : 6),
            // Uyarı metni
            Text(
              AppLocalizations.of(context)!.kerahatTime,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GlassBarConstants.getTextColor(context)
                        .withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: isLandscapePhone
                        ? 9.0
                        : (responsiveValues.titleFontSize * 0.72)
                            .clamp(11.0, 15.0),
                    letterSpacing: 0.2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dini gün altın nokta animasyonu
class _ReligiousDayDot extends StatefulWidget {
  const _ReligiousDayDot();

  @override
  State<_ReligiousDayDot> createState() => _ReligiousDayDotState();
}

class _ReligiousDayDotState extends State<_ReligiousDayDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.6 * _animation.value),
                blurRadius: 10 * _animation.value,
                spreadRadius: 3 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Kerahat vakti kırmızı nokta animasyonu
class _KerahatDot extends StatefulWidget {
  const _KerahatDot();

  @override
  State<_KerahatDot> createState() => _KerahatDotState();
}

class _KerahatDotState extends State<_KerahatDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.6 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Toplevel yardımcı metodlar
Widget _buildDateCard(BuildContext context, String todayDate, String hijriDate,
    SelectedLocation location) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _showReligiousDaysModal(context, location),
    onLongPress: () => _showKerahatDebugDialog(context, location),
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          if (hijriDate.isNotEmpty) ...[
            Text(
              hijriDate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GlassBarConstants.getTextColor(context)
                        .withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 2),
          ],
          if (todayDate.isNotEmpty)
            Text(
              todayDate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GlassBarConstants.getTextColor(context)
                        .withValues(alpha: 0.85),
                  ),
            ),
        ],
      ),
    ),
  );
}

/// Kerahat vakti debug bilgisi gösterir
void _showKerahatDebugDialog(BuildContext context, SelectedLocation location) {
  final vm = context.read<PrayerTimesViewModel>();
  final info = vm.getKerahatInfo();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kerahat Vakti Bilgisi'),
      content: SingleChildScrollView(
        child: Text(
          info,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    ),
  );
}

Widget _buildTodayPrayerTimesCard(
    BuildContext context,
    Map<String, String> prayerTimes,
    ValueListenable<double> expandAnimationNotifier,
    Map<String, String> prayerKeyMap) {
  final vm = context.read<PrayerTimesViewModel>();
  final currentPrayerKey = vm.getCurrentPrayerName();
  final nextPrayerKey = vm.nextPrayerName;
  // Key'leri çevrilmiş isimlere dönüştür
  final currentPrayer = currentPrayerKey != null
      ? PrayerNameHelper.getLocalizedPrayerName(context, currentPrayerKey)
      : null;
  final nextPrayer = nextPrayerKey != null
      ? PrayerNameHelper.getLocalizedPrayerName(context, nextPrayerKey)
      : null;

  return ValueListenableBuilder<double>(
    valueListenable: expandAnimationNotifier,
    builder: (context, expandValue, child) {
      // Yatay modda (landscape) tablet ve telefonlar için farklı strateji:
      // Tablet: Vakitler sağda dikey liste kalsın (effectiveExpandValue = 0.0)
      // Telefon: Alan çok dar olduğu için vakitler altta yatay (icons) kalsın (effectiveExpandValue = 1.0)
      final bool isLandscapePhone = context.isLandscape && context.isPhone;
      final double effectiveExpandValue =
          isLandscapePhone ? 1.0 : (context.isLandscape ? 0.0 : expandValue);

      // Token bazlı değerler - bar kapalıyken minimal, açıkken daha fazla padding
      // Smooth geçiş için interpolation kullan
      final double minVerticalPadding = Responsive.value<double>(context,
          xs: 4.0, sm: 6.0, md: 8.0, lg: 10.0, xl: 12.0);
      final double maxVerticalPadding = context.space(SpaceSize.sm);
      final double verticalPadding = minVerticalPadding +
          (maxVerticalPadding - minVerticalPadding) * effectiveExpandValue;
      final double horizontalPadding = context.space(SpaceSize.lg);

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _showMonthlyPrayerTimesModal(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: horizontalPadding,
          ),
          child: _buildUnifiedPrayerTimesLayout(
            context,
            prayerTimes,
            currentPrayer,
            nextPrayer,
            effectiveExpandValue,
            prayerKeyMap: prayerKeyMap,
          ),
        ),
      );
    },
  );
}

Widget _buildUnifiedPrayerTimesLayout(
  BuildContext context,
  Map<String, String> prayerTimes,
  String? currentPrayer,
  String? nextPrayer,
  double expandValue, {
  required Map<String, String> prayerKeyMap,
}) {
  final entries = prayerTimes.entries.toList(growable: false);
  final itemCount = entries.length;
  final screenSize = MediaQuery.sizeOf(context);
  final double animationValue = expandValue.clamp(0.0, 1.0);

  return LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      final bool hasBoundedHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
      final textTheme = Theme.of(context).textTheme;
      final Color textColor = GlassBarConstants.getTextColor(context);
      final Color activeBackgroundColor =
          GlassBarConstants.getBackgroundColor(context);
      final Color activeBorderColor = GlassBarConstants.getBorderColor(context);

      // Breakpoint bazlı değerler (dikey yerleşim)
      final bool isLandscapePhone = context.isLandscape && context.isPhone;
      final double compactFactor = isLandscapePhone ? 0.82 : 1.0;

      final double verticalItemHeight = Responsive.value<double>(
            context,
            xs: 51.0,
            sm: 54.0,
            md: 57.0,
            lg: 63.0,
            xl: 69.0,
          ) *
          compactFactor;
      final double verticalGap = context.space(SpaceSize.sm) * compactFactor;

      // Tercih edilen dikey yükseklik: ekranın bir bölümü + içerik minimumu
      final double preferredCollapsedHeight = screenSize.height *
          Responsive.value<double>(context,
              xs: 0.53, sm: 0.55, md: 0.57, lg: 0.59, xl: 0.61);

      // Dikey düzenin sığması için minimum yükseklik (üst + alt + aralar eşit)
      final double baseCollapsedHeight = verticalGap /* üst */
          +
          itemCount * verticalItemHeight +
          (itemCount - 1) * verticalGap +
          verticalGap /* alt */;

      // Mevcut yükseklik: sınırlıysa constraint, değilse tercih edilen değer
      // (küçük ekranlarda boşlukların büyümemesi için base ile max yapılmadı)
      final double collapseHeightBudget =
          hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : preferredCollapsedHeight;

      // Mevcut yükseklik min. ihtiyacın altındaysa elemanları sıkıştır
      final double compressionFactor =
          collapseHeightBudget < baseCollapsedHeight
              ? (collapseHeightBudget / baseCollapsedHeight)
              : 1.0;

      final double adjustedItemHeight = verticalItemHeight * compressionFactor;
      final double adjustedGap = verticalGap * compressionFactor;

      // Sıkıştırılmış temel yükseklik
      final double compressedBaseHeight = adjustedGap /* üst */
          +
          itemCount * adjustedItemHeight +
          (itemCount - 1) * adjustedGap +
          adjustedGap /* alt */;

      // Artan boşluk: Öğeler ve boşluklar arasında dengeli paylaştır
      final double extraSpace = (collapseHeightBudget - compressedBaseHeight)
          .clamp(0, double.infinity);

      // Boşluğun bir kısmını (%40) öğe yüksekliğine ekle (maksimum %20 büyüme sınırı ile)
      final double itemHeightBoost =
          (extraSpace * 0.4 / itemCount).clamp(0.0, verticalItemHeight * 0.2);
      final double finalItemHeight = adjustedItemHeight + itemHeightBoost;

      // Kalan boşluğu gap'lere yay
      final double remainingExtraSpace =
          extraSpace - (itemHeightBoost * itemCount);
      final int innerGapCount = itemCount > 1 ? itemCount - 1 : 0;
      final double innerGapBoost =
          innerGapCount > 0 ? remainingExtraSpace / innerGapCount : 0.0;

      final double collapsedTopOffset = adjustedGap; // üst boşluk sabit
      final double collapsedItemSpacing =
          adjustedGap + innerGapBoost; // aralar dinamik
      final double collapsedContainerHeight = adjustedGap /* üst */
          +
          itemCount * finalItemHeight +
          innerGapCount * collapsedItemSpacing +
          adjustedGap; /* alt */

      // Yatay düzen parametreleri
      final double horizontalItemWidth = availableWidth / itemCount;
      final double horizontalItemHeight = Responsive.value<double>(
        context,
        xs: 81.0,
        sm: 86.0,
        md: 90.0,
        lg: 100.0,
        xl: 110.0,
      );

      // Expanded içinde kullanıldığında (hasBoundedHeight && constraints.maxHeight.isFinite)
      // constraint'lerin maxHeight'ını kullanarak responsive dinamik boyutlandırma yap
      final bool isInExpanded =
          hasBoundedHeight && constraints.maxHeight.isFinite;

      // Container yüksekliği: Expanded içindeyse dinamik yükseklik, değilse hesaplanan yükseklik
      // Dikey (eşit dağılım) <-> yatay arasında interpolasyon
      final double baseContainerHeight = lerpDouble(
        collapsedContainerHeight,
        horizontalItemHeight,
        animationValue,
      )!;

      // Expanded içinde kullanıldığında dinamik yükseklik, değilse hesaplanan yükseklik
      final double containerHeight =
          isInExpanded ? collapseHeightBudget : baseContainerHeight;

      final double finalHeight = containerHeight;

      return RepaintBoundary(
        child: SizedBox(
          height: finalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(itemCount, (index) {
              final prayerEntry = entries[index];
              final originalPrayerKey =
                  prayerKeyMap[prayerEntry.key] ?? prayerEntry.key;
              return _buildAnimatedPrayerTimeItem(
                context,
                prayerEntry.key,
                prayerEntry.value,
                originalPrayerKey: originalPrayerKey,
                index: index,
                itemCount: itemCount,
                availableWidth: availableWidth,
                horizontalItemWidth: horizontalItemWidth,
                verticalItemHeight: finalItemHeight,
                verticalTopOffset: collapsedTopOffset,
                verticalItemSpacing: collapsedItemSpacing,
                horizontalItemHeight: horizontalItemHeight,
                animationValue: animationValue,
                isActive: prayerEntry.key == currentPrayer,
                isNext: prayerEntry.key == nextPrayer,
                textTheme: textTheme,
                textColor: textColor,
                activeBackgroundColor: activeBackgroundColor,
                activeBorderColor: activeBorderColor,
              );
            }),
          ),
        ),
      );
    },
  );
}

Widget _buildAnimatedPrayerTimeItem(
  BuildContext context,
  String prayerName,
  String prayerTime, {
  required String originalPrayerKey,
  required int index,
  required int itemCount,
  required double availableWidth,
  required double horizontalItemWidth,
  required double verticalItemHeight,
  required double verticalTopOffset,
  required double verticalItemSpacing,
  required double horizontalItemHeight,
  required double animationValue,
  required bool isActive,
  required bool isNext,
  required TextTheme textTheme,
  required Color textColor,
  required Color activeBackgroundColor,
  required Color activeBorderColor,
}) {
  final double t = animationValue.clamp(0.0, 1.0);
  // inverseT kaldırıldı, lerpDouble kullanılacak
  // isVertical kontrolü kaldırıldı - tek bir yapı kullanılacak

  // Breakpoint bazlı değerler - dikey layout
  final double verticalHorizontalPadding = context.space(SpaceSize.lg);
  final double verticalVerticalPadding = context.space(SpaceSize.md);
  final double verticalIconSize = context.icon(IconSizeLevel.md);
  final double verticalNameFontSize = context.font(FontSize.md);
  final double verticalTimeFontSize = context.font(FontSize.lg);
  final double verticalBorderRadius = context.space(SpaceSize.lg);

  // Breakpoint bazlı değerler - yatay layout
  final double horizontalIconSize = context.icon(IconSizeLevel.sm);
  final double horizontalNameFontSize = context.font(FontSize.xs);
  final double horizontalTimeFontSize = context.font(FontSize.sm);
  final double horizontalBorderRadius = context.space(SpaceSize.md);

  // Dikey yerleşim: eşit aralıklar
  final verticalTop =
      verticalTopOffset + index * (verticalItemHeight + verticalItemSpacing);
  final verticalLeft = 0.0;

  // Yatay pozisyon: yan yana
  final horizontalTop = 0.0;
  final horizontalLeft = index * horizontalItemWidth;

  // Pozisyon interpolasyonu: expandValue 0.0 = dikey, 1.0 = yatay
  final top = lerpDouble(verticalTop, horizontalTop, t)!;
  final left = lerpDouble(verticalLeft, horizontalLeft, t)!;

  // Genişlik ve yükseklik interpolasyonu
  final width = lerpDouble(availableWidth, horizontalItemWidth, t)!;
  final height = lerpDouble(verticalItemHeight, horizontalItemHeight, t)!;

  // Padding ve Radius interpolasyonu
  final horizontalPadding = lerpDouble(verticalHorizontalPadding, 0.0, t)!;
  final verticalPadding = lerpDouble(verticalVerticalPadding, 0.0, t)!;
  final borderRadius =
      lerpDouble(verticalBorderRadius, horizontalBorderRadius, t)!;

  // Font ve icon boyutu interpolasyonu
  final iconSize = lerpDouble(verticalIconSize, horizontalIconSize, t)!;
  final nameFontSize =
      lerpDouble(verticalNameFontSize, horizontalNameFontSize, t)!;
  final timeFontSize =
      lerpDouble(verticalTimeFontSize, horizontalTimeFontSize, t)!;
  final bool shimmerEnabled = isNext && !isActive;
  final iconData = _getPrayerIcon(originalPrayerKey);

  // Futuristik glassmorphism için renkler - animasyonlu interpolasyon (optimize edildi)
  // Kapalı durum (t=0): dikey stil renkleri
  // Açık durum (t=1): yatay stil renkleri
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;

  if (isActive) {
    // Aktif öğe için sabit renkler (hesaplama yok)
    bgColor = activeBackgroundColor.withValues(alpha: 0.15);
    borderColor = activeBorderColor.withValues(alpha: 0.5);
    borderWidth = 1.5;
  } else {
    // Pasif öğe için animasyonlu renkler
    final double bgAlpha = 0.03 - (0.03 * t); // 0.03 -> 0.0
    final double borderAlpha = 0.1 - (0.1 * t); // 0.1 -> 0.0
    bgColor = textColor.withValues(alpha: bgAlpha);
    borderColor = textColor.withValues(alpha: borderAlpha);
    borderWidth = 0.8 - (0.8 * t); // 0.8 -> 0.0
  }

  return Positioned(
    top: top,
    left: left,
    width: width,
    height: height,
    child: RepaintBoundary(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        // Tek bir Stack yapısı - içindeki öğeler animasyonlu pozisyon değiştiriyor
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // İkon - animasyonlu pozisyon
            Align(
              alignment: Alignment(
                lerpDouble(-1.0, 0.0, t)!, // X: sol -> orta
                lerpDouble(-0.5, -0.78, t)!, // Y: üst -> daha üst
              ),
              child: _ShimmerEffect(
                isActive: shimmerEnabled,
                child: Icon(
                  iconData,
                  color: isActive
                      ? textColor
                      : textColor.withValues(alpha: lerpDouble(0.85, 0.9, t)!),
                  size: iconSize,
                ),
              ),
            ),
            // İsim - animasyonlu pozisyon
            Align(
              alignment: Alignment(
                lerpDouble(-0.7, 0.0, t)!, // X: ikon yanı -> orta
                lerpDouble(0.0, 0.18, t)!, // Y: orta -> biraz alt
              ),
              child: _ShimmerEffect(
                isActive: shimmerEnabled,
                child: Text(
                  PrayerNameHelper.getLocalizedPrayerName(context, prayerName),
                  textAlign: t < 0.5 ? TextAlign.left : TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isActive
                        ? textColor
                        : textColor.withValues(
                            alpha: lerpDouble(0.9, 0.95, t)!),
                    fontWeight: t < 0.5 ? FontWeight.w600 : FontWeight.w500,
                    fontSize: nameFontSize,
                    height: lerpDouble(1.2, 1.05, t)!,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Saat - animasyonlu pozisyon
            Align(
              alignment: Alignment(
                lerpDouble(1.0, 0.0, t)!, // X: sağ -> orta
                lerpDouble(0.0, 0.78, t)!, // Y: orta -> alt
              ),
              child: _ShimmerEffect(
                isActive: shimmerEnabled,
                child: Text(
                  prayerTime,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isActive
                        ? textColor
                        : textColor.withValues(
                            alpha: lerpDouble(0.95, 0.9, t)!),
                    fontWeight: t < 0.5 ? FontWeight.w700 : FontWeight.w600,
                    fontSize: timeFontSize,
                    letterSpacing: lerpDouble(0.5, 0.0, t)!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

IconData _getPrayerIcon(String prayerName) {
  // prayerName çevrilmiş olabilir, key'e dönüştür
  final key = PrayerNameHelper.getPrayerKey(prayerName);
  switch (key) {
    case 'İmsak':
      return Symbols.bedtime_rounded;
    case 'Güneş':
      return Symbols.partly_cloudy_day_rounded;
    case 'Öğle':
      return Symbols.wb_sunny_rounded;
    case 'İkindi':
      return Symbols.sunny_snowing_rounded;
    case 'Akşam':
      return Symbols.nights_stay_rounded;
    case 'Yatsı':
      return Symbols.nightlight_rounded;
    default:
      return Icons.access_time_rounded;
  }
}

Widget _buildErrorInStack(
    BuildContext context, PrayerTimesViewModel vm, SelectedLocation location) {
  final screenHeight = MediaQuery.of(context).size.height;

  return Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => context.read<LocationBarViewModel>().collapse(),
          child: Container(color: Colors.transparent),
        ),
      ),
      // Hata mesajını prayer times pozisyonunda göster
      Positioned(
        top: screenHeight * 0.12,
        left: 24,
        right: 24,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 58,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 16),
              Text(
                vm.getErrorMessage(context) ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  vm.clearError();
                  vm.loadPrayerTimes(location.city.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildSkeletonLoading(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      MediaQuery.of(context).orientation == Orientation.landscape;
  // İçerik başlangıcını gerçek görünüme yakın hizala
  final topPadding = isLandscape ? screenHeight * 0.02 : screenHeight * 0.12;

  return Padding(
    padding: EdgeInsets.only(
      top: topPadding,
      left: 24,
      right: 24,
      bottom: 24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Geri Sayım ve Tarih Alanı (Üst Kısım)
        Center(
          child: Column(
            children: [
              // Başlık
              _ShimmerEffect(
                isActive: true,
                child: Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Büyük Sayaç
              _ShimmerEffect(
                isActive: true,
                child: Container(
                  width: 200,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tarih
              _ShimmerEffect(
                isActive: true,
                child: Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 2. Namaz Vakitleri Kartları (Dikey Liste)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Mevcut alana 6 tane sığdır
              final totalHeight = constraints.maxHeight;
              // Aradaki boşluklar (5 tane boşluk)
              const gap = 12.0;
              // Bir elemanın yüksekliği
              final itemHeight =
                  ((totalHeight - (5 * gap)) / 6).clamp(50.0, 70.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.start, // Üsten başla
                children: List.generate(6, (index) {
                  return Column(
                    children: [
                      _ShimmerEffect(
                        isActive: true,
                        child: Container(
                          height: itemHeight,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      if (index < 5) const SizedBox(height: gap),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ],
    ),
  );
}

// Modal pencere: 30 günlük namaz vakitlerini gösterir
Future<void> _showMonthlyPrayerTimesModal(BuildContext context) async {
  final vm = context.read<PrayerTimesViewModel>();
  final allTimes = vm.prayerTimesResponse?.prayerTimes ?? [];
  final today = DateTime.now();
  final startDate = today.subtract(const Duration(days: 3));
  final endDate = today.add(const Duration(days: 26));

  // Aralık ayında ve endDate gelecek yıla geçiyorsa, gelecek yılın verilerini de yükle
  List<PrayerTime> combinedTimes = List.from(allTimes);
  if (today.month == 12 && endDate.year > today.year) {
    final nextYear = today.year + 1;
    final cityId = vm.selectedCityId;
    if (cityId != null) {
      try {
        final prayerTimesService = PrayerTimesService();
        final nextYearResponse =
            await prayerTimesService.getPrayerTimes(cityId, nextYear);
        combinedTimes.addAll(nextYearResponse.prayerTimes);
      } catch (e) {
        // Gelecek yıl verisi yüklenemezse sessizce devam et
      }
    }
  }

  // Tarih sırasına göre sırala (iki farklı yıldan gelen veriler birleştirildiğinde önemli)
  combinedTimes.sort((a, b) {
    final dateA = _parsePrayerDate(a);
    final dateB = _parsePrayerDate(b);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateA.compareTo(dateB);
  });

  final monthlyTimes = combinedTimes
      .where((prayer) {
        final prayerDate = _parsePrayerDate(prayer);
        if (prayerDate == null) return false;
        return (prayerDate.isAtSameMomentAs(startDate) ||
                prayerDate.isAfter(startDate)) &&
            (prayerDate.isAtSameMomentAs(endDate) ||
                prayerDate.isBefore(endDate));
      })
      .take(30)
      .toList();

  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    settings: const RouteSettings(name: '/monthly_prayer_times'),
    transitionDuration: const Duration(milliseconds: 0),
    reverseTransitionDuration: const Duration(milliseconds: 0),
    pageBuilder: (context, animation, secondaryAnimation) {
      final extentNotifier = ValueNotifier<double>(0.6);
      double lastExtent = 0.6;

      return _AnimatedBlurModal(
        extentNotifier: extentNotifier,
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            // Extent değerini güncelle (blur animasyonu için)
            extentNotifier.value = notification.extent;

            // Tam açık konumdan aşağı yumuşak çekişlerde de kapanmayı kolaylaştır
            final modalState = notification.context
                .findAncestorStateOfType<_AnimatedBlurModalState>();
            if (modalState != null && !modalState.isClosing) {
              final wasNearFull = lastExtent >= 0.9;
              final draggedDown = notification.extent < lastExtent;
              final leftFullZone =
                  notification.extent <= 0.88; // hiz ihtiyacini dusur
              if (wasNearFull && draggedDown && leftFullZone) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!modalState.isClosing) modalState.closeModal();
                });
              }
            }

            // Modal tamamen kapanması için threshold: 0.05'in altında kapat
            if (notification.extent <= 0.05) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Drag ile kapatırken modal state'i doğrudan notification context'inden bul
                final modalState = notification.context
                    .findAncestorStateOfType<_AnimatedBlurModalState>();
                if (modalState != null && !modalState.isClosing) {
                  modalState.closeModal();
                }
              });
            }

            lastExtent = notification.extent;
            return true;
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.0, // Tamamen kapanabilir
            maxChildSize: 0.92, // Daha yüksek maksimum boyut
            snap: false, // Snap kapalı: bırakıldığı konumda kalsın
            builder: (context, scrollController) {
              return _AnimatedModalContent(
                scrollController: scrollController,
                monthlyTimes: monthlyTimes,
                today: today,
                extentNotifier: extentNotifier,
              );
            },
          ),
        ),
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  ));
}

// Modal pencere: Dini günleri listeler (tasarım: aylık modal ile benzer)
void _showReligiousDaysModal(BuildContext context, SelectedLocation location) {
  final vm = context.read<PrayerTimesViewModel>();
  // Modal açılmadan önce yeniden hesapla (metin-eşleme değişiklikleri için güvenli taraf)
  vm.recomputeReligiousDays();
  final items = vm.detectedReligiousDays;
  final today = DateTime.now();

  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    settings: const RouteSettings(name: '/religious_days'),
    transitionDuration: const Duration(milliseconds: 0),
    reverseTransitionDuration: const Duration(milliseconds: 0),
    pageBuilder: (context, animation, secondaryAnimation) {
      final extentNotifier = ValueNotifier<double>(0.6);
      double lastExtent = 0.6;

      return _AnimatedBlurModal(
        extentNotifier: extentNotifier,
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            // Extent değerini güncelle (blur animasyonu için)
            extentNotifier.value = notification.extent;

            // Tam açık konumdan aşağı yumuşak çekişlerde de kapanmayı kolaylaştır
            final modalState = notification.context
                .findAncestorStateOfType<_AnimatedBlurModalState>();
            if (modalState != null && !modalState.isClosing) {
              final wasNearFull = lastExtent >= 0.9;
              final draggedDown = notification.extent < lastExtent;
              final leftFullZone =
                  notification.extent <= 0.7; // hiz ihtiyacini dusur
              if (wasNearFull && draggedDown && leftFullZone) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!modalState.isClosing) modalState.closeModal();
                });
              }
            }

            // Modal tamamen kapanması için threshold: 0.05'in altında kapat
            if (notification.extent <= 0.05) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Drag ile kapatırken modal state'i doğrudan notification context'inden bul
                final modalState = notification.context
                    .findAncestorStateOfType<_AnimatedBlurModalState>();
                if (modalState != null && !modalState.isClosing) {
                  modalState.closeModal();
                }
              });
            }

            lastExtent = notification.extent;
            return true;
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.0, // Tamamen kapanabilir
            maxChildSize: 0.92, // Daha yüksek maksimum boyut
            snap: false, // Snap kapalı: bırakıldığı konumda kalsın
            builder: (context, scrollController) {
              return _ReligiousDaysContent(
                scrollController: scrollController,
                items: items,
                today: today,
              );
            },
          ),
        ),
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  ));
}
