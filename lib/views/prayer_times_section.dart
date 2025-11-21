import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../viewmodels/location_bar_viewmodel.dart';
import '../models/location_model.dart';
import '../models/prayer_times_model.dart';
import '../utils/constants.dart';
import 'dart:ui';
import 'daily_content_bar.dart';
import '../utils/responsive.dart';
import '../models/religious_day.dart';

// Ay kısaltmaları cache'i
const List<String> _months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

String _getMonthAbbreviation(int month) => _months[month];

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

class _ShimmerEffectState extends State<_ShimmerEffect> with SingleTickerProviderStateMixin {
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
  final ValueNotifier<double>? extentNotifier; // Modal yüksekliğini takip etmek için

  const _AnimatedBlurModal({
    required this.child,
    this.extentNotifier,
  });

  @override
  State<_AnimatedBlurModal> createState() => _AnimatedBlurModalState();
}

class _AnimatedBlurModalState extends State<_AnimatedBlurModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isClosing = false;
  
  bool get isClosing => _isClosing;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
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
    // Extent'i sıfırla ki blur animasyonu düzgün çalışsın
    widget.extentNotifier?.value = 0.0;
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
          widget.extentNotifier ?? ValueNotifier<double>(1.0),
        ]),
        builder: (context, child) {
          // Modal yüksekliğine göre blur hesapla (0.0 = kapalı, 1.0 = tam açık)
          final extent = widget.extentNotifier?.value ?? 1.0;
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
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.10,
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

class _AnimatedModalContentState extends State<_AnimatedModalContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
      vsync: this,
    )..forward();

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
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(GlassBarConstants.borderRadius)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassBarConstants.blurmSigma,
                    sigmaY: GlassBarConstants.blurmSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: GlassBarConstants.getBackgroundColor(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(GlassBarConstants.borderRadius)),
                      border: Border.all(color: GlassBarConstants.getBorderColor(context), width: GlassBarConstants.borderWidth),
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
                                    color: GlassBarConstants.getBorderColor(context),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Başlık - bu alan da sürüklenebilir (DraggableScrollableSheet sayesinde)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    'Aylık Namaz Vakitleri',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: GlassBarConstants.getTextColor(context),
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
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      'Tarih',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: GlassBarConstants.getTextColor(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']
                                          .asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final name = entry.value;
                                            return [
                                              if (index > 0) Container(
                                                width: 1,
                                                height: 20,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(
                                                  color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(0.5),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: GlassBarConstants.getTextColor(context),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ];
                                          }).expand((list) => list).toList(),
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
                                final prayer = widget.monthlyTimes[index];
                                DateTime? date;
                                if (prayer.gregorianDateShortIso8601.isNotEmpty) {
                                  date = DateTime.tryParse(prayer.gregorianDateShortIso8601);
                                }
                                if (date == null) {
                                  final parts = prayer.gregorianDateShort.split('.');
                                  if (parts.length == 3) {
                                    date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                                  }
                                }
                                
                                final isToday = date != null && 
                                  date.year == widget.today.year && 
                                  date.month == widget.today.month && 
                                  date.day == widget.today.day;
                                
                                final dayStr = date != null ? '${date.day}' : prayer.gregorianDateShort.split('.')[0];
                                final monthStr = date != null ? _getMonthAbbreviation(date.month) : '';
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? GlassBarConstants.getTextColor(context).withValues(alpha: 0.12)
                                        : index.isEven
                                            ? GlassBarConstants.getTextColor(context).withValues(alpha: 0.03)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isToday 
                                        ? Border.all(
                                            color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.25),
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
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: GlassBarConstants.getTextColor(context),
                                                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (monthStr.isNotEmpty)
                                              Text(
                                                monthStr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.7),
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
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(0.5),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                prayer.sunrise,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(0.5),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                prayer.dhuhr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(0.5),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                prayer.asr,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(0.5),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                prayer.maghrib,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(0.5),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                prayer.isha,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
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
                              childCount: widget.monthlyTimes.length,
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
  @override
  Widget build(BuildContext context) {
    // Tüm öğeleri tarihe göre sırala
    final items = widget.items.toList()
      ..sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));

    // Sadece bu yılın verilerini göster
    final currentYear = DateTime.now().year;
    final currentYearItems = items.where((item) => item.year == currentYear).toList();

    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GlassBarConstants.borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassBarConstants.blurSigma,
            sigmaY: GlassBarConstants.blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(GlassBarConstants.borderRadius)),
              border: Border.all(color: GlassBarConstants.getBorderColor(context), width: GlassBarConstants.borderWidth),
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
                            color: GlassBarConstants.getBorderColor(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Başlık - bu alan da sürüklenebilir (DraggableScrollableSheet sayesinde)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Dini Gün ve Geceler',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: GlassBarConstants.getTextColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // İçerik
                if (currentYearItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tespit edilen dini gün bulunamadı.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.8),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = currentYearItems[index];
                          final isToday = item.gregorianDate.year == widget.today.year &&
                              item.gregorianDate.month == widget.today.month &&
                              item.gregorianDate.day == widget.today.day;
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? GlassBarConstants.getTextColor(context).withValues(alpha: 0.12)
                                      : index.isEven
                                          ? GlassBarConstants.getTextColor(context).withValues(alpha: 0.03)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isToday
                                      ? Border.all(
                                          color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.25),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.gregorianDateShort.split('.').first,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                          ),
                                          Text(
                                            _monthAbbrev(item.gregorianDate.month),
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.7),
                                                  fontSize: 9,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.eventName,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.hijriDateLong,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.75),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index < currentYearItems.length - 1) const SizedBox(height: 2),
                            ],
                          );
                        },
                        childCount: currentYearItems.length,
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
    );
  }

  String _monthAbbrev(int month) {
    const months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return months[month];
  }
}

class PrayerTimesSection extends StatelessWidget {
  final SelectedLocation location;
  const PrayerTimesSection({super.key, required this.location});

  // Yardımcı metodlar (gerekirse eklenir)

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerTimesViewModel>(
      builder: (context, vm, child) {
        if (vm.showSkeleton || (vm.isLoading && vm.todayPrayerTimes == null)) {
          return _buildSkeletonLoading(context);
        }
        if (vm.errorMessage != null) {
          return _buildErrorInStack(context, vm, location);
        }

        final todayPrayerTimes = vm.getFormattedTodayPrayerTimes();
        final todayDate = vm.getTodayDate();
        final hijriDate = vm.getHijriDate();
        final screenHeight = MediaQuery.of(context).size.height;
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
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
                                  SizedBox(height: Responsive.value<double>(context, xs: 8, sm: 12, md: 16, lg: 20, xl: 24)),
                                  _buildDateCard(context, todayDate, hijriDate, location),
                                  SizedBox(height: Responsive.value<double>(context, xs: 2, sm: 4, md: 6, lg: 8, xl: 10)),
                                  _buildTodayPrayerTimesCard(context, todayPrayerTimes),
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
                                  maxWidth: Responsive.value<double>(context, xs: 380, sm: 440, md: 520, lg: 580, xl: 640),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: DailyContentBar(),
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
                          SizedBox(height: Responsive.value<double>(context, xs: 16, sm: 24, md: 35, lg: 40, xl: 44)),
                          _buildDateCard(context, todayDate, hijriDate, location),
                          SizedBox(height: Responsive.value<double>(context, xs: 4, sm: 6, md: 7, lg: 8, xl: 10)),
                          _buildTodayPrayerTimesCard(context, todayPrayerTimes),
                          SizedBox(height: Responsive.value<double>(context, xs: 8, sm: 10, md: 12, lg: 14, xl: 16)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DailyContentBar(),
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
    final countdown = vm.getFormattedCountdown();
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
                  '$nextPrayerName vaktine',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: responsiveValues.titleFontSize,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: responsiveValues.spacingHeight),
                // Geri sayım için sayı kalın, metin ince font ağırlığı (tıklanabilir)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async { await vm.toggleCountdownFormat(); },
                  child: isHms
                      ? Text(
                          countdown,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: GlassBarConstants.getTextColor(context),
                                fontWeight: FontWeight.w800,
                                fontSize: responsiveValues.numberFontSize,
                                letterSpacing: 1.0,
                              ),
                          textAlign: TextAlign.center,
                        )
                      : Text.rich(
                          TextSpan(
                            children: countdown.split(' ').expand<InlineSpan>((part) {
                              final number = part.replaceAll(RegExp(r'\D+'), '');
                              final unit = part.replaceAll(RegExp(r'\d+'), '') + ' ';
                              return [
                                TextSpan(
                                  text: number,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: GlassBarConstants.getTextColor(context),
                                        fontWeight: FontWeight.w800,
                                        fontSize: responsiveValues.numberFontSize,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                TextSpan(
                                  text: unit,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: GlassBarConstants.getTextColor(context),
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
  Widget _buildKerahatWarning(BuildContext context, _ResponsiveValues responsiveValues) {
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
              'Kerahat Vakti',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: (responsiveValues.titleFontSize * 0.75).clamp(12.0, 16.0),
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

class _KerahatDotState extends State<_KerahatDot> with SingleTickerProviderStateMixin {
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
Widget _buildDateCard(BuildContext context, String todayDate, String hijriDate, SelectedLocation location) {
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
                      color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.85),
                    ),
              ),
              const SizedBox(height: 2),
            ],
            if (todayDate.isNotEmpty)
              Text(
                todayDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.85),
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
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

Widget _buildTodayPrayerTimesCard(BuildContext context, Map<String, String> prayerTimes) {
    final vm = context.read<PrayerTimesViewModel>();
    final currentPrayer = vm.getCurrentPrayerName();
    final nextPrayer = vm.nextPrayerName;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _showMonthlyPrayerTimesModal(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: prayerTimes.entries.map((entry) => Expanded(
            child: _buildHorizontalPrayerTimeItem(
              context,
              entry.key,
              entry.value,
              isActive: entry.key == currentPrayer,
              isNext: entry.key == nextPrayer,
            ),
          )).toList(),
        ),
      ),
    );
  }

Widget _buildHorizontalPrayerTimeItem(BuildContext context, String prayerName, String prayerTime, {bool isActive = false, bool isNext = false}) {
    IconData? icon;
    switch (prayerName) {
      case 'İmsak':
        icon = Symbols.bedtime_rounded;
        break;
      case 'Güneş':
        icon = Symbols.partly_cloudy_day_rounded;
        break;
      case 'Öğle':
        icon = Symbols.wb_sunny_rounded;
        break;
      case 'İkindi':
        icon = Symbols.sunny_snowing_rounded;
        break;
      case 'Akşam':
        icon = Symbols.nights_stay_rounded;
        break;
      case 'Yatsı':
        icon = Symbols.nightlight_rounded;
        break;
      default:
        icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: isActive
          ? BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: GlassBarConstants.getBorderColor(context),
                width: 1.5,
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShimmerEffect(
            isActive: isNext && !isActive,
            child: Icon(
              icon,
              color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
              size: 20,
            ),
          ),
          const SizedBox(height: 5),
          _ShimmerEffect(
            isActive: isNext && !isActive,
            child: Text(
              prayerName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.95),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 5),
          _ShimmerEffect(
            isActive: isNext && !isActive,
            child: Text(
              prayerTime,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: GlassBarConstants.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildErrorInStack(BuildContext context, PrayerTimesViewModel vm, SelectedLocation location) {
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
                  Icons.error_outline,
                  size: 58,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hata Oluştu',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  vm.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tekrar Dene'),
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
          left: 24, right: 24,
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
          left: 24, right: 24,
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
          left: 18, right: 18,
          child: SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => Expanded(
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
    final monthlyTimes = allTimes.where((prayer) {
      DateTime? prayerDate;
      if (prayer.gregorianDateShortIso8601.isNotEmpty) {
        prayerDate = DateTime.tryParse(prayer.gregorianDateShortIso8601);
      }
      if (prayerDate == null) {
        final parts = prayer.gregorianDateShort.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            prayerDate = DateTime(year, month, day);
          }
        }
      }
      if (prayerDate == null) return false;
      return (prayerDate.isAtSameMomentAs(startDate) || prayerDate.isAfter(startDate)) &&
             (prayerDate.isAtSameMomentAs(endDate) || prayerDate.isBefore(endDate));
    }).take(30).toList();

    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      settings: const RouteSettings(name: '/monthly_prayer_times'),
      transitionDuration: const Duration(milliseconds: 0),
      reverseTransitionDuration: const Duration(milliseconds: 0),
      pageBuilder: (context, animation, secondaryAnimation) {
        final extentNotifier = ValueNotifier<double>(0.6);
        
        return _AnimatedBlurModal(
          extentNotifier: extentNotifier,
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Extent değerini güncelle (blur animasyonu için)
              extentNotifier.value = notification.extent;
              
              // Modal tamamen kapanması için threshold: 0.05'in altında kapat
              if (notification.extent <= 0.05) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final modalState = context.findAncestorStateOfType<_AnimatedBlurModalState>();
                  if (modalState != null && !modalState.isClosing) {
                    modalState.closeModal();
                  }
                });
              }
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.0, // Tamamen kapanabilir
              maxChildSize: 0.92, // Daha yüksek maksimum boyut
              snap: true, // Snap behavior aktif
              snapSizes: const [0.0, 0.6, 0.92], // Snap noktaları: kapalı, orta, tam açık
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
      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
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
        final extentNotifier = ValueNotifier<double>(0.55);
        
        return _AnimatedBlurModal(
          extentNotifier: extentNotifier,
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Extent değerini güncelle (blur animasyonu için)
              extentNotifier.value = notification.extent;
              
              // Modal tamamen kapanması için threshold: 0.05'in altında kapat
              if (notification.extent <= 0.05) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final modalState = context.findAncestorStateOfType<_AnimatedBlurModalState>();
                  if (modalState != null && !modalState.isClosing) {
                    modalState.closeModal();
                  }
                });
              }
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.0, // Tamamen kapanabilir
              maxChildSize: 0.92, // Daha yüksek maksimum boyut
              snap: true, // Snap behavior aktif
              snapSizes: const [0.0, 0.55, 0.92], // Snap noktaları: kapalı, orta, tam açık
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
      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    ));
  }