import 'dart:ui';
import '../utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../viewmodels/daily_content_viewmodel.dart';
import '../utils/error_messages.dart';
import '../l10n/app_localizations.dart';

class DailyContentBar extends StatefulWidget {
  final ValueNotifier<double>? expandAnimationNotifier;

  const DailyContentBar({super.key, this.expandAnimationNotifier});

  @override
  State<DailyContentBar> createState() => _DailyContentBarState();
}

class _DailyContentBarState extends State<DailyContentBar>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isExpanded = false;
  // ignore: unused_field - Swipe yönü için (gelecekte animasyon yönü belirleme için gerekebilir)
  final bool _isForward = true;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    // Daha yavaş ve yumuşak animasyon için süre artırıldı
    final expandDuration = AnimationConstants.slow; // 800ms
    _expandController = AnimationController(
      duration: expandDuration,
      reverseDuration: expandDuration,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic, // Her iki yönde de yumuşak geçiş
      reverseCurve: Curves.easeInOutCubic, // Kapanışta da yumuşak bitiş
    );

    // Animasyon değerini dışarı aktar
    _expandAnimation.addListener(() {
      widget.expandAnimationNotifier?.value = _expandAnimation.value;
    });

    _loadSavedState();
  }

  /// Kaydedilmiş durumu yükle
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedExpanded = prefs.getBool('daily_content_bar_expanded');

      // Eğer kaydedilmiş bir durum yoksa varsayılan olarak kapalı
      final isExpanded = savedExpanded ?? false;

      if (mounted) {
        setState(() {
          _isExpanded = isExpanded;
          if (isExpanded) {
            _expandController.value =
                1.0; // Animasyon olmadan direkt açık duruma getir
          } else {
            _expandController.value =
                0.0; // Animasyon olmadan direkt kapalı duruma getir
          }
          // İlk yüklemede değeri bildir
          widget.expandAnimationNotifier?.value = _expandController.value;
        });
      }
    } catch (e) {
      // Hata durumunda varsayılan olarak kapalı
      if (mounted) {
        setState(() {
          _isExpanded = false;
          _expandController.value = 0.0;
        });
      }
    }
  }

  /// Durumu kaydet
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('daily_content_bar_expanded', _isExpanded);
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    // Yatay modda (landscape) olan cihazlarda kapanmasın
    if (Responsive.isLandscape(context)) return;

    _isExpanded = !_isExpanded;
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
    // Durumu kaydet
    _saveState();
  }

  void _onHorizontalDrag(DragEndDetails details) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final rawVelocity = details.primaryVelocity ?? 0.0;
    // RTL dillerinde yönü tersine çevir
    final isForward = isRTL ? rawVelocity > 0 : rawVelocity < 0;

    final vm = context.read<DailyContentViewModel?>();
    final contentState = _ContentState.fromVm(vm, context);
    final int itemsCount = contentState.items.length;

    setState(() {
      if (itemsCount > 1) {
        if (isForward && _currentIndex < itemsCount - 1) {
          _currentIndex++;
        } else if (!isForward && _currentIndex > 0) {
          _currentIndex--;
        }
      } else if (itemsCount == 0) {
        _currentIndex = 0;
      }
    });
  }

  int _activeIndex(int itemsCount) {
    if (itemsCount == 0) return 0;
    return _currentIndex.clamp(0, itemsCount - 1);
  }

  Widget _buildStateAwareCard(_ContentState state, int activeIndex,
      bool isLandscape, Size screenSize, double opacityValue) {
    // Bar kapalıyken yükleme işareti gösterilmesin
    if (state.isLoading && opacityValue > 0.3) {
      return _buildLoadingSkeleton();
    }
    // Bar kapalıyken ve yükleniyorsa boş container göster (sadece "Günlük İçerik" metni görünecek)
    if (state.isLoading && opacityValue <= 0.3) {
      return _buildEmptyCard();
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return _buildErrorCard(state.errorMessage!,
          onRetry: state.onRetry ?? () {});
    }
    if (state.items.isEmpty) {
      return _buildErrorCard(ErrorMessages.contentNotFound(context),
          onRetry: state.onRetry ?? () {});
    }
    return _buildContentCard(
        state.items[activeIndex], isLandscape, screenSize, opacityValue);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Selector<DailyContentViewModel?, _ContentState>(
      selector: (_, vm) => _ContentState.fromVm(vm, context),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, state, _) {
        final activeIndex = _activeIndex(state.items.length);

        // Belirteç noktaları için alt boşluk - simetrik olması için space token kullan
        final indicatorBottomSpace = context.space(SpaceSize.sm);
        final indicatorCount = state.items.isEmpty ? 1 : state.items.length;

        // Tema uyumlu renk seçimi
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final activeColor = isDark
            ? theme.colorScheme.primary
            : GlassBarConstants.getTextColor(context);

        final inactiveColor = isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.3)
            : GlassBarConstants.getTextColor(context).withValues(alpha: 0.3);

        return LayoutBuilder(
          builder: (context, constraints) {
            // Mevcut maksimum genişlik ve yükseklik değerlerini al
            // Animasyon sonunda sıçrama olmaması için sabit değerler kullan
            final maxWidth = isLandscape
                ? constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : mediaQuery.size.width
                : mediaQuery.size.width * 0.92;
            // maxHeight'ı parent'ın (Expanded) sağladığı tam alana eşitle
            // Bu sayede bar vakitlerden "arta kalan" tüm alanı dinamik olarak kullanabilir.
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : mediaQuery.size.height * (isLandscape ? 0.6 : 0.4);

            return RepaintBoundary(
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  // KAPALI DURUM: Sabit boyutlar ve konum
                  final double collapsedWidthPx = Responsive.value<double>(
                    context,
                    xs: 128.0,
                    sm: 135.0,
                    md: 143.0,
                    lg: 158.0,
                    xl: 173.0,
                  );
                  final bool isLandscapePhone =
                      context.isLandscape && context.isPhone;
                  final double screenHeight = mediaQuery.size.height;

                  final double collapsedHeightPx = isLandscapePhone
                      ? (screenHeight * 0.12).clamp(32.0, 42.0)
                      : Responsive.value<double>(
                          context,
                          xs: 55.0,
                          sm: 59.0,
                          md: 62.0,
                          lg: 68.0,
                          xl: 75.0,
                        );

                  final double minCollapsedWidth = Responsive.value<double>(
                    context,
                    xs: 110.0,
                    sm: 120.0,
                    md: 130.0,
                    lg: 145.0,
                    xl: 160.0,
                  );

                  final double minCollapsedHeight = isLandscapePhone
                      ? (screenHeight * 0.11).clamp(30.0, 38.0)
                      : Responsive.value<double>(
                          context,
                          xs: 48.0,
                          sm: 52.0,
                          md: 55.0,
                          lg: 60.0,
                          xl: 65.0,
                        );

                  // Yatay modda (landscape) olan cihazlarda hep açık kalsın
                  final bool forceOpen = Responsive.isLandscape(context);
                  final double t =
                      forceOpen ? 1.0 : _expandAnimation.value.clamp(0.0, 1.0);

                  // Eğer zorunlu açık olma durumu değiştiyse veya notifier güncel değilse bildir
                  if (widget.expandAnimationNotifier != null &&
                      widget.expandAnimationNotifier!.value != t) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        widget.expandAnimationNotifier!.value = t;
                      }
                    });
                  }

                  // Değişkenleri bir kez hesapla (her karede Responsive.value çağırmamak için)
                  final double collapsedWidth =
                      collapsedWidthPx.clamp(minCollapsedWidth, maxWidth);
                  final double collapsedHeight = collapsedHeightPx.clamp(
                      minCollapsedHeight, double.infinity);

                  // Animasyon değerine göre boyutları lerp et
                  final double animatedWidth = constraints.hasTightWidth
                      ? constraints.maxWidth
                      : lerpDouble(collapsedWidth, maxWidth, t)!;

                  final double animatedHeight = constraints.hasTightHeight
                      ? constraints.maxHeight
                      : lerpDouble(collapsedHeight, maxHeight, t)!;

                  return GestureDetector(
                    onTap: _toggleExpand,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: animatedWidth,
                        height: animatedHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ana içerik kısmı
                            Expanded(
                              child: GestureDetector(
                                onHorizontalDragEnd: _onHorizontalDrag,
                                behavior: HitTestBehavior.opaque,
                                child: _buildStateAwareCard(state, activeIndex,
                                    isLandscape, mediaQuery.size, t),
                              ),
                            ),
                            // Belirteç noktaları - yumuşak fade in/out animasyonu
                            Opacity(
                              opacity: (t * 2).clamp(0.0, 1.0),
                              child: IgnorePointer(
                                ignoring: t < 0.4,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: (t * 2).clamp(0.0, 1.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                            height:
                                                context.space(SpaceSize.sm)),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            indicatorCount,
                                            (index) => _buildPageIndicator(
                                                index,
                                                activeIndex,
                                                activeColor,
                                                inactiveColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: indicatorBottomSpace),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentCard(DailyContentItem item, bool isLandscape,
      Size screenSize, double opacityValue,
      {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final availableH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenSize.height * (isLandscape ? 0.6 : 0.35);
        final availableW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenSize.width;
        // Font boyutları için referans değerler
        final double baseTitleFont = context.font(FontSize.lg);
        final double baseSourceFont = context.font(FontSize.sm);
        final double expandedContentFontBase =
            (availableW * 0.045).clamp(12.0, isLandscape ? 20.0 : 18.0);

        // Açık durumdaki font ayarı (sabit, animasyon sırasında değişmez)
        double expandedContentFont = expandedContentFontBase;
        if (availableH < 260) expandedContentFont -= 1.0;
        if (item.content.length > 180) expandedContentFont -= 1.0;
        if (item.content.length > 260) expandedContentFont -= 1.0;
        expandedContentFont = expandedContentFont.clamp(12.0, double.infinity);

        // Lerp değerleri
        final double contentFont =
            lerpDouble(12.0, expandedContentFont, opacityValue)!;
        final double titleFont =
            lerpDouble(baseTitleFont * 0.7, baseTitleFont, opacityValue)!;
        final double sourceFont =
            lerpDouble(baseSourceFont * 0.7, baseSourceFont, opacityValue)!;
        final double currentPadding = lerpDouble(
          GlassBarConstants.contentPadding * 0.5,
          GlassBarConstants.contentPadding + context.space(SpaceSize.xs),
          opacityValue,
        )!;

        // Opacity değerini sınırla
        final double textOpacity = opacityValue.clamp(0.0, 1.0);

        return Container(
          margin: EdgeInsets.all(context.space(SpaceSize.xs)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
            child: Container(
              decoration: BoxDecoration(
                color: GlassBarConstants.getBackgroundColor(context),
                borderRadius:
                    BorderRadius.circular(GlassBarConstants.borderRadius),
                border: Border.all(
                  color: GlassBarConstants.getBorderColor(context),
                  width: GlassBarConstants.borderWidth,
                ),
              ),
              child: Stack(
                children: [
                  // Ana içerik (metinler) - animasyonlu padding
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.05, 0.0),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      key: ValueKey(
                          'content_${item.title}_${item.content.hashCode}'),
                      padding: EdgeInsets.all(currentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title - tek konum, animasyonlu opacity ve scale
                          RepaintBoundary(
                            child: Opacity(
                              opacity: textOpacity,
                              child: Transform.scale(
                                scale: 0.95 +
                                    (0.05 *
                                        textOpacity), // Kapalıyken biraz küçük
                                child: Text(
                                  item.type == ContentType.verse
                                      ? AppLocalizations.of(context)!.dailyVerse
                                      : AppLocalizations.of(context)!
                                          .dailyHadith,
                                  style: TextStyle(
                                    color:
                                        GlassBarConstants.getTextColor(context)
                                            .withValues(alpha: 0.9),
                                    fontSize: titleFont,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: context.space(SpaceSize.md)),

                          // Content: tek konum, animasyonlu opacity - tasarruflu rendering
                          Expanded(
                            child: RepaintBoundary(
                              child: Opacity(
                                opacity: textOpacity,
                                child: LayoutBuilder(
                                  builder: (context, contentConstraints) {
                                    return SingleChildScrollView(
                                      physics: item.content.length > 200
                                          ? const BouncingScrollPhysics()
                                          : const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        // Mevcut Expanded alanının tamamını kapsayarak ortalamayı sağlar
                                        constraints: BoxConstraints(
                                          minHeight:
                                              contentConstraints.maxHeight,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          item.content,
                                          style: TextStyle(
                                            color:
                                                GlassBarConstants.getTextColor(
                                                        context)
                                                    .withValues(alpha: 0.9),
                                            fontSize: contentFont,
                                            height: 1.4,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: context.space(SpaceSize.md)),

                          // Source - tek konum, animasyonlu opacity ve scale
                          RepaintBoundary(
                            child: Opacity(
                              opacity: textOpacity,
                              child: Transform.scale(
                                scale: 0.95 +
                                    (0.05 *
                                        textOpacity), // Kapalıyken biraz küçük
                                child: Text(
                                  item.source,
                                  style: TextStyle(
                                    color:
                                        GlassBarConstants.getTextColor(context)
                                            .withValues(alpha: 0.6),
                                    fontSize: sourceFont,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // "Günlük İçerik" metni - bar kapalıyken görünür (opaklık artarak)
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - opacityValue)
                            .clamp(0.0, 1.0), // Bar kapandıkça opaklık artar
                        child: IgnorePointer(
                          ignoring: opacityValue >
                              0.3, // Metinler görünürken tıklanamaz
                          child: Text(
                            AppLocalizations.of(context)!.dailyContent,
                            style: TextStyle(
                              color: GlassBarConstants.getTextColor(context)
                                  .withValues(alpha: 0.9),
                              fontSize: context.font(FontSize.md),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(
      int index, int activeIndex, Color activeColor, Color inactiveColor) {
    return AnimatedContainer(
      duration: AnimationConstants.medium,
      curve: AnimationConstants.easeInOutCubic,
      margin: EdgeInsets.symmetric(horizontal: context.space(SpaceSize.xs)),
      width: activeIndex == index
          ? context.space(SpaceSize.xl)
          : context.space(SpaceSize.sm),
      height: context.space(SpaceSize.sm),
      decoration: BoxDecoration(
        color: activeIndex == index ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(context.space(SpaceSize.xs)),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: EdgeInsets.all(context.space(SpaceSize.xs)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: GlassBarConstants.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
            border: Border.all(
              color: GlassBarConstants.getBorderColor(context),
              width: GlassBarConstants.borderWidth,
            ),
          ),
          child: Center(
            child: Text(
              'Günlük İçerik',
              style: TextStyle(
                color: GlassBarConstants.getTextColor(context)
                    .withValues(alpha: 0.9),
                fontSize: context.font(FontSize.md),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      margin: EdgeInsets.all(context.space(SpaceSize.xs)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: GlassBarConstants.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
            border: Border.all(
              color: GlassBarConstants.getBorderColor(context),
              width: GlassBarConstants.borderWidth,
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, {required VoidCallback onRetry}) {
    return Container(
      margin: EdgeInsets.all(context.space(SpaceSize.xs)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: GlassBarConstants.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
            border: Border.all(
              color: GlassBarConstants.getBorderColor(context),
              width: GlassBarConstants.borderWidth,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.space(SpaceSize.md)),
                child: Text(
                  message,
                  style: TextStyle(
                    color: GlassBarConstants.getTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: context.space(SpaceSize.sm)),
              TextButton(
                  onPressed: onRetry,
                  child: Text(ErrorMessages.retryLowercase(context))),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyContentItem {
  final String title;
  final String content;
  final String source;
  final IconData icon;
  final ContentType type;

  const DailyContentItem({
    required this.title,
    required this.content,
    required this.source,
    required this.icon,
    required this.type,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyContentItem &&
        other.title == title &&
        other.content == content &&
        other.source == source &&
        other.icon == icon &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(title, content, source, icon, type);
}

enum ContentType { verse, hadith }

class _ContentState {
  final bool isLoading;
  final String? errorMessage;
  final List<DailyContentItem> items;
  final VoidCallback? onRetry;

  const _ContentState({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
    required this.onRetry,
  });

  factory _ContentState.fromVm(
      DailyContentViewModel? vm, BuildContext context) {
    if (vm == null) {
      return const _ContentState(
        isLoading: true,
        errorMessage: null,
        items: [],
        onRetry: null,
      );
    }

    final hasAny = (vm.ayet != null) || (vm.hadis != null);
    if (vm.isLoading && !hasAny) {
      return _ContentState(
        isLoading: true,
        errorMessage: null,
        items: const [],
        onRetry: vm.retry,
      );
    }

    if (vm.errorMessage != null && !hasAny) {
      return _ContentState(
        isLoading: false,
        errorMessage: vm.errorMessage,
        items: const [],
        onRetry: vm.retry,
      );
    }

    final items = <DailyContentItem>[];
    if (vm.ayet != null) {
      final q = vm.ayet!.locales[vm.currentLang] ??
          vm.ayet!.locales['tr'] ??
          vm.ayet!.locales['en'];
      items.add(DailyContentItem(
        title: 'Günün Ayeti', // Will be localized in builder
        content: q?.text ?? '',
        source: q?.source ?? '',
        icon: Symbols.book_2,
        type: ContentType.verse,
      ));
    }
    if (vm.hadis != null) {
      final q = vm.hadis!.locales[vm.currentLang] ??
          vm.hadis!.locales['tr'] ??
          vm.hadis!.locales['en'];
      items.add(DailyContentItem(
        title: 'Günün Hadisi', // Will be localized in builder
        content: q?.text ?? '',
        source: q?.source ?? '',
        icon: Symbols.auto_stories,
        type: ContentType.hadith,
      ));
    }

    if (items.isEmpty) {
      return _ContentState(
        isLoading: false,
        errorMessage: ErrorMessages.contentNotFound(context),
        items: items,
        onRetry: vm.retry,
      );
    }

    return _ContentState(
      isLoading: false,
      errorMessage: null,
      items: items,
      onRetry: vm.retry,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ContentState &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        listEquals(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(isLoading, errorMessage, Object.hashAll(items));
}
