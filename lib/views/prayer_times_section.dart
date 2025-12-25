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
import 'dart:ui';
import 'daily_content_bar.dart';
import '../utils/responsive.dart';
import '../models/religious_day.dart';

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

Widget _buildVerticalDivider(Color baseColor) {
  return Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: baseColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(0.5),
    ),
  );
}

// Responsive değerleri hesaplayan yardımcı sınıf
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

  factory _ResponsiveValues.fromScreenSize(Size screenSize) {
    final width = screenSize.width;
    final height = screenSize.height;
    final isLandscape = width > height;

    return _ResponsiveValues(
      titleFontSize: (width * 0.045).clamp(16.0, isLandscape ? 20.0 : 22.0),
      numberFontSize: (width * 0.16).clamp(30.0, isLandscape ? 60.0 : 70.0),
      unitFontSize: (width * 0.09).clamp(30.0, isLandscape ? 38.0 : 44.0),
      horizontalPadding: (width * 0.06).clamp(20.0, 32.0),
      verticalPadding: (height * 0.001).clamp(2.0, 8.0),
      spacingHeight: (height * 0.01).clamp(8.0, 16.0),
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

  Future<bool> _onWillPop() async {
    if (_isClosing) return false;
    _isClosing = true;
    // Kapanış için daha hızlı ve keskin animasyon
    await _controller.reverse();
    return true;
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
    return WillPopScope(
      onWillPop: _onWillPop,
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
                      sigmaX: 3.0 * blurMultiplier,
                      sigmaY: 3.0 * blurMultiplier,
                    ),
                    child: Opacity(
                      opacity: _opacityAnimation.value * extent.clamp(0.0, 1.0),
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.08
                              : 0.10,
                        ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: GlassBarConstants.getBorderColor(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 3,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
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
                                                        final locale = Localizations.localeOf(context);
                                                        final isArabic = locale.languageCode == 'ar';
                                                        final rawDayStr = item.gregorianDateShort
                                                            .split('.')
                                                            .first;
                                                        final dayStr = isArabic 
                                                            ? localizeNumerals(rawDayStr, 'ar') 
                                                            : rawDayStr;
                                                        return Text(
                                                          dayStr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: Theme.of(context)
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
                                                                fontSize: 13,
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
                                                      item.hijriDateLong,
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
    return Consumer<PrayerTimesViewModel>(
      builder: (context, vm, child) {
        if (vm.showSkeleton || (vm.isLoading && vm.todayPrayerTimes == null)) {
          return _buildSkeletonLoading(context);
        }
        if (vm.errorCode != null || vm.errorMessage != null) {
          return _buildErrorInStack(context, vm, widget.location);
        }

        final rawPrayerTimes = vm.getFormattedTodayPrayerTimes();
        // Namaz vakitleri isimlerini çevir (key'i sakla çünkü ikonlar için gerekli)
        final todayPrayerTimes = rawPrayerTimes.map((key, value) => MapEntry(
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
              top: screenHeight * 0.10,
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                // Navigation bar için alt boşluk bırak
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom),
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sol sütun: kaydırılabilir içerik (geri sayım, tarih, vakitler)
                          Expanded(
                            flex: 7,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 0),
                                  _buildCountdownCard(context, vm),
                                  SizedBox(
                                      height: Responsive.value<double>(context,
                                          xs: 8,
                                          sm: 12,
                                          md: 16,
                                          lg: 20,
                                          xl: 24)),
                                  _buildDateCard(context, todayDate, hijriDate,
                                      widget.location),
                                  SizedBox(
                                      height: Responsive.value<double>(context,
                                          xs: 2, sm: 4, md: 6, lg: 8, xl: 10)),
                                  _buildTodayPrayerTimesCard(
                                      context,
                                      todayPrayerTimes,
                                      _expandAnimationNotifier,
                                      prayerKeyMap),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sağ sütun: günlük içerik, tüm yükseklikte
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: Responsive.value<double>(context,
                                      xs: 380,
                                      sm: 440,
                                      md: 520,
                                      lg: 580,
                                      xl: 640),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: DailyContentBar(
                                      expandAnimationNotifier:
                                          _expandAnimationNotifier),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 3),
                          _buildCountdownCard(context, vm),
                          SizedBox(
                              height: Responsive.value<double>(context,
                                  xs: 16, sm: 24, md: 35, lg: 40, xl: 44)),
                          _buildDateCard(
                              context, todayDate, hijriDate, widget.location),
                          SizedBox(
                              height: Responsive.value<double>(context,
                                  xs: 4, sm: 6, md: 7, lg: 8, xl: 10)),
                          _buildTodayPrayerTimesCard(context, todayPrayerTimes,
                              _expandAnimationNotifier, prayerKeyMap),
                          ValueListenableBuilder<double>(
                            valueListenable: _expandAnimationNotifier,
                            builder: (context, expandValue, child) {
                              // İçerik barı açıkken (expandValue >= 0.5) daha fazla padding
                              // Dikey düzende daha fazla boşluk bırak
                              final basePadding = 0;
                              final expandedPadding = Responsive.value<double>(
                                  context,
                                  xs: 8,
                                  sm: 10,
                                  md: 12,
                                  lg: 14,
                                  xl: 16);
                              final padding =
                                  (0.0 - expandValue) * basePadding +
                                      expandValue * expandedPadding;
                              return SizedBox(height: padding);
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: DailyContentBar(
                                  expandAnimationNotifier:
                                      _expandAnimationNotifier),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCountdownCard(BuildContext context, PrayerTimesViewModel vm) {
    final localizations = AppLocalizations.of(context)!;
    final countdown = vm.getFormattedCountdown(
      hourText: localizations.hour,
      minuteText: localizations.minute,
      minuteShortText: localizations.minuteShort,
      secondText: localizations.second,
    );
    final nextPrayerName = vm.nextPrayerName;
    final isHms = vm.isHmsFormat;
    final isKerahat = vm.isKerahatTime();

    if (countdown.isEmpty || nextPrayerName == null) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final responsiveValues = _ResponsiveValues.fromScreenSize(size);

    return Transform.translate(
      offset: isKerahat ? const Offset(0, -5) : Offset.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: responsiveValues.horizontalPadding,
          vertical: responsiveValues.verticalPadding,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              children: [
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
                // Geri sayım için sayı kalın, metin ince font ağırlığı (tıklanabilir)
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
                              // Arapça rakamları da içeren regex: 0-9 ve ٠-٩
                              final locale = Localizations.localeOf(context);
                              final isArabic = locale.languageCode == 'ar';
                              final numberPattern = isArabic 
                                  ? RegExp(r'[0-9٠-٩]+')
                                  : RegExp(r'\d+');
                              final nonNumberPattern = isArabic
                                  ? RegExp(r'[^0-9٠-٩]+')
                                  : RegExp(r'\D+');
                              
                              final number = part.replaceAll(nonNumberPattern, '');
                              final unit = part.replaceAll(numberPattern, '') + ' ';
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
                                        fontSize:
                                            responsiveValues.numberFontSize,
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
              ],
            ),
            // Kerahat vakti uyarısı (geri sayımın altında, overlap)
            if (isKerahat)
              Positioned(
                bottom: -(responsiveValues.spacingHeight * 2.5),
                child: _buildKerahatWarning(context, responsiveValues),
              ),
          ],
        ),
      ),
    );
  }

  /// Kerahat vakti uyarı widget'ı
  Widget _buildKerahatWarning(
      BuildContext context, _ResponsiveValues responsiveValues) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kırmızı uyarı noktası (animasyonlu)
            _KerahatDot(),
            const SizedBox(width: 10),
            // Uyarı metni
            Text(
              AppLocalizations.of(context)!.kerahatTime,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GlassBarConstants.getTextColor(context)
                        .withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: (responsiveValues.titleFontSize * 0.75)
                        .clamp(12.0, 16.0),
                    letterSpacing: 0.3,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
      // Sabit referans değerler - ölçeklendirme ile korunur
      const double baseVerticalPadding = 8.0;
      const double baseHorizontalPadding = 18.0;
      final scale = Responsive.scale(context);

      final double verticalPadding =
          expandValue < 0.5 ? 0 : baseVerticalPadding * scale;
      final double horizontalPadding = baseHorizontalPadding * scale;

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
            expandValue,
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
  final scale = Responsive.scale(context);
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

      // Sabit referans değerler - ölçeklendirme ile korunur
      const double baseVerticalItemHeight = 60.0;
      const double baseVerticalGap = 10.0; // üst ve alt sabit, aralar dinamik
      const double baseHorizontalItemHeight = 95.0;

      // Ölçeklendirilmiş değerler (dikey yerleşim)
      final double verticalItemHeight = baseVerticalItemHeight * scale;
      final double verticalGap = baseVerticalGap * scale;

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

      // Artan boşluk: yalnızca öğeler arası boşluklara paylaştır (üst/alt sabit)
      final double extraSpace = (collapseHeightBudget - compressedBaseHeight)
          .clamp(0, double.infinity);
      final int innerGapCount = itemCount > 1 ? itemCount - 1 : 0;
      final double innerGapBoost =
          innerGapCount > 0 ? extraSpace / innerGapCount : 0.0;

      final double collapsedTopOffset = adjustedGap; // üst boşluk sabit
      final double collapsedItemSpacing =
          adjustedGap + innerGapBoost; // aralar dinamik
      final double collapsedContainerHeight = adjustedGap /* üst */
          +
          itemCount * adjustedItemHeight +
          innerGapCount * collapsedItemSpacing +
          adjustedGap; /* alt */

      // Yatay düzen parametreleri
      final double horizontalItemWidth = availableWidth / itemCount;
      final double horizontalItemHeight = baseHorizontalItemHeight * scale;

      // Container yüksekliği: dikey (eşit dağılım) <-> yatay arasında interpolasyon
      final double containerHeight = lerpDouble(
        collapsedContainerHeight,
        horizontalItemHeight,
        animationValue,
      )!;

      return RepaintBoundary(
        child: SizedBox(
          height: containerHeight,
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
                verticalItemHeight: adjustedItemHeight,
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
  final scale = Responsive.scale(context);
  final double t = animationValue.clamp(0.0, 1.0);
  final double inverseT = 1.0 - t;
  final isVertical = inverseT > 0.5;

  // Sabit referans değerler - ölçeklendirme ile korunur
  const double baseVerticalHorizontalPadding = 20.0;
  const double baseVerticalVerticalPadding = 14.0;
  const double baseVerticalIconSize = 24.0;
  const double baseHorizontalIconSize = 20.0;
  const double baseVerticalNameFontSize = 15.5;
  const double baseHorizontalNameFontSize = 11.0;
  const double baseVerticalTimeFontSize = 18.0;
  const double baseHorizontalTimeFontSize = 13.0;
  const double baseVerticalBorderRadius = 20.0;
  const double baseHorizontalBorderRadius = 14.0;
  const double baseVerticalSpacing = 12.0; // İkon ve isim arası

  // Dikey yerleşim: eşit aralıklar + ölçeklendirme
  final verticalTop =
      verticalTopOffset + index * (verticalItemHeight + verticalItemSpacing);
  final verticalLeft = 0.0;

  // Yatay pozisyon: yan yana
  final horizontalTop = 0.0;
  final horizontalLeft = index * horizontalItemWidth;

  // Pozisyon interpolasyonu: expandValue 0.0 = dikey, 1.0 = yatay
  final top = inverseT * verticalTop + t * horizontalTop;
  final left = inverseT * verticalLeft + t * horizontalLeft;

  // Genişlik ve yükseklik interpolasyonu
  final width = inverseT * availableWidth + t * horizontalItemWidth;
  final height = inverseT * verticalItemHeight + t * horizontalItemHeight;

  // Padding interpolasyonu - ölçeklendirilmiş
  final double verticalHorizontalPadding =
      baseVerticalHorizontalPadding * scale;
  final double verticalVerticalPadding = baseVerticalVerticalPadding * scale;
  final double verticalSpacing = baseVerticalSpacing * scale;
  final horizontalPadding = inverseT * verticalHorizontalPadding;
  final verticalPadding = inverseT * verticalVerticalPadding;

  // Font boyutları ve stil interpolasyonu - ölçeklendirilmiş
  final double verticalIconSize = baseVerticalIconSize * scale;
  final double horizontalIconSize = baseHorizontalIconSize * scale;
  final double verticalNameFontSize = baseVerticalNameFontSize * scale;
  final double horizontalNameFontSize = baseHorizontalNameFontSize * scale;
  final double verticalTimeFontSize = baseVerticalTimeFontSize * scale;
  final double horizontalTimeFontSize = baseHorizontalTimeFontSize * scale;

  final iconSize = inverseT * verticalIconSize + t * horizontalIconSize;
  final nameFontSize =
      inverseT * verticalNameFontSize + t * horizontalNameFontSize;
  final timeFontSize =
      inverseT * verticalTimeFontSize + t * horizontalTimeFontSize;
  final nameFontWeight = t < 0.5 ? FontWeight.w600 : FontWeight.w500;
  final timeFontWeight = t < 0.5 ? FontWeight.w700 : FontWeight.w600;

  // Border radius interpolasyonu - ölçeklendirilmiş
  final double verticalBorderRadius = baseVerticalBorderRadius * scale;
  final double horizontalBorderRadius = baseHorizontalBorderRadius * scale;
  final borderRadius =
      inverseT * verticalBorderRadius + t * horizontalBorderRadius;
  final bool shimmerEnabled = isNext && !isActive;
  final iconData = _getPrayerIcon(originalPrayerKey);

  // Futuristik glassmorphism için renkler
  final bgColor = (!isVertical && !isActive)
      ? Colors.transparent
      : isActive
          ? activeBackgroundColor.withValues(alpha: 0.15)
          : textColor.withValues(alpha: 0.03);
  final borderColor = isActive
      ? activeBorderColor.withValues(alpha: 0.5)
      : textColor.withValues(alpha: isVertical ? 0.1 : 0.0);

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
            width: isVertical ? (isActive ? 1.5 : 0.8) : (isActive ? 1.5 : 0.0),
          ),
        ),
        child: isVertical
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sol taraf: İkon + İsim yan yana
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ShimmerEffect(
                          isActive: shimmerEnabled,
                          child: Icon(
                            iconData,
                            color: textColor.withValues(
                                alpha: isActive ? 1.0 : 0.85),
                            size: iconSize,
                          ),
                        ),
                        SizedBox(width: verticalSpacing),
                        Flexible(
                          child: _ShimmerEffect(
                            isActive: shimmerEnabled,
                            child: Text(
                              PrayerNameHelper.getLocalizedPrayerName(
                                  context, prayerName),
                              style: textTheme.bodyMedium?.copyWith(
                                color: textColor.withValues(
                                    alpha: isActive ? 1.0 : 0.9),
                                fontWeight: nameFontWeight,
                                fontSize: nameFontSize,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sağ taraf: Saat
                  _ShimmerEffect(
                    isActive: shimmerEnabled,
                    child: Text(
                      prayerTime,
                      style: textTheme.bodyLarge?.copyWith(
                        color:
                            textColor.withValues(alpha: isActive ? 1.0 : 0.95),
                        fontWeight: timeFontWeight,
                        fontSize: timeFontSize,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: const Alignment(0.0, -0.78),
                    child: _ShimmerEffect(
                      isActive: shimmerEnabled,
                      child: Icon(
                        iconData,
                        color: textColor.withValues(alpha: 0.9),
                        size: iconSize,
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.0, 0.18),
                    child: _ShimmerEffect(
                      isActive: shimmerEnabled,
                      child: Text(
                        PrayerNameHelper.getLocalizedPrayerName(
                            context, prayerName),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: textColor.withValues(alpha: 0.95),
                          fontWeight: nameFontWeight,
                          fontSize: nameFontSize,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.0, 0.78),
                    child: _ShimmerEffect(
                      isActive: shimmerEnabled,
                      child: Text(
                        prayerTime,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: timeFontWeight,
                          fontSize: timeFontSize,
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
  return Stack(
    children: [
      Positioned.fill(
        child: Container(color: Colors.transparent),
      ),
      Positioned(
        top: MediaQuery.of(context).size.height * 0.12,
        left: 24,
        right: 24,
        child: _ShimmerEffect(
          isActive: true,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      Positioned(
        top: MediaQuery.of(context).size.height * 0.25,
        left: 24,
        right: 24,
        child: _ShimmerEffect(
          isActive: true,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      Positioned(
        top: MediaQuery.of(context).size.height * 0.35,
        left: 18,
        right: 18,
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
                6,
                (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ShimmerEffect(
                          isActive: true,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    )),
          ),
        ),
      ),
    ],
  );
}

// Modal pencere: 30 günlük namaz vakitlerini gösterir
void _showMonthlyPrayerTimesModal(BuildContext context) {
  final vm = context.read<PrayerTimesViewModel>();
  final allTimes = vm.prayerTimesResponse?.prayerTimes ?? [];
  final today = DateTime.now();
  final startDate = today.subtract(const Duration(days: 3));
  final endDate = today.add(const Duration(days: 26));
  final monthlyTimes = allTimes
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
