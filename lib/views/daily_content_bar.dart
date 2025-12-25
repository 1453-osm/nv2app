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
  
  const DailyContentBar({Key? key, this.expandAnimationNotifier}) : super(key: key);

  @override
  State<DailyContentBar> createState() => _DailyContentBarState();
}

class _DailyContentBarState extends State<DailyContentBar> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isForward = true;
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  static const Duration _expandDuration = Duration(milliseconds: 420);

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: _expandDuration,
      reverseDuration: _expandDuration,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic, // Açılış-kapanış aynı hız eğrisi
      reverseCurve: Curves.easeInOutCubic,
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
            _expandController.value = 1.0; // Animasyon olmadan direkt açık duruma getir
          } else {
            _expandController.value = 0.0; // Animasyon olmadan direkt kapalı duruma getir
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
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
      // Durumu kaydet
      _saveState();
    });
  }

  void _onHorizontalDrag(DragEndDetails details) {
    final isForward = details.primaryVelocity != null && details.primaryVelocity! < 0;
    final vm = context.read<DailyContentViewModel?>();
    final contentState = _ContentState.fromVm(vm, context);
    final int itemsCount = contentState.items.length;

      setState(() {
        _isForward = isForward;
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

  Widget _buildDirectionalTransition(Widget child, Animation<double> animation) {
    final isReverse = animation.status == AnimationStatus.reverse;
    final beginOffset = isReverse
        ? Offset(_isForward ? -0.1 : 0.1, 0)
        : Offset(_isForward ? 0.1 : -0.1, 0);

    final slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(slideAnimation),
        child: child,
      ),
    );
  }

  Widget _buildStateAwareCard(_ContentState state, int activeIndex, bool isLandscape, Size screenSize, double opacityValue) {
    // Bar kapalıyken yükleme işareti gösterilmesin
    if (state.isLoading && opacityValue > 0.3) {
      return _buildLoadingSkeleton();
    }
    // Bar kapalıyken ve yükleniyorsa boş container göster (sadece "Günlük İçerik" metni görünecek)
    if (state.isLoading && opacityValue <= 0.3) {
      return _buildEmptyCard();
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return _buildErrorCard(state.errorMessage!, onRetry: state.onRetry ?? () {});
    }
    if (state.items.isEmpty) {
      return _buildErrorCard(ErrorMessages.contentNotFound(context), onRetry: state.onRetry ?? () {});
    }
    return _buildContentCard(state.items[activeIndex], isLandscape, screenSize, opacityValue);
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

        // Belirteç noktaları için alt boşluk
        const indicatorBottomSpace = 12.0;
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
            final maxWidth = isLandscape 
                ? constraints.maxWidth.isFinite 
                    ? constraints.maxWidth 
                    : mediaQuery.size.width
                : mediaQuery.size.width * 0.92;
            final maxHeight = constraints.maxHeight.isFinite 
                ? constraints.maxHeight 
                : mediaQuery.size.height * (isLandscape ? 0.6 : 0.35);
            
            return AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                // Kapalı durumda sabit genişlik ve yükseklik (dinamik oran yok)
                const double collapsedWidthPx = 150.0;
                const double collapsedHeightPx = 65.0;

                // Küçük ekranlarda taşmayı engellemek için üst sınırı mevcut alana sabitle
                final double collapsedWidth = collapsedWidthPx.clamp(0.0, maxWidth).toDouble();
                final double collapsedHeight = collapsedHeightPx.clamp(0.0, maxHeight).toDouble();
                
                // Yumuşak geçiş için easing uygula (animasyon zaten eğri kullanıyor ama ekstra yumuşaklık için)
                final double easedValue = _expandAnimation.value;
                
                // Animasyonlu genişlik ve yükseklik hesapla - sabit kapalı boyut -> tam genişlik/yükseklik
                final double animatedWidth = collapsedWidth + (maxWidth - collapsedWidth) * easedValue;
                final double animatedHeight = collapsedHeight + (maxHeight - collapsedHeight) * easedValue;
        
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
                              child: _buildStateAwareCard(state, activeIndex, isLandscape, mediaQuery.size, _expandAnimation.value),
                            ),
                          ),
                          // Belirteç noktaları - yumuşak fade in/out animasyonu
                          Opacity(
                            opacity: (_expandAnimation.value * 2).clamp(0.0, 1.0), // 0.5'te tam görünür olacak şekilde
                            child: IgnorePointer(
                              ignoring: _expandAnimation.value < 0.4,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: (_expandAnimation.value * 2).clamp(0.0, 1.0), // Yumuşak yükseklik animasyonu
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
            const SizedBox(height: 12),
                                      Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          indicatorCount,
                                          (index) => _buildPageIndicator(index, activeIndex, activeColor, inactiveColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
            ),
                          const SizedBox(height: indicatorBottomSpace),
          ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContentCard(DailyContentItem item, bool isLandscape, Size screenSize, double opacityValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableH = constraints.maxHeight.isFinite ? constraints.maxHeight : screenSize.height * (isLandscape ? 0.6 : 0.35);
        final availableW = constraints.maxWidth.isFinite ? constraints.maxWidth : screenSize.width;
        // Dinamik font: yüksekliğe ve genişliğe göre sınırla, metin uzunluğuna göre ince ayar
        double contentFont = (availableW * 0.045).clamp(12.0, isLandscape ? 20.0 : 18.0);
        if (availableH < 260) contentFont -= 1.0;
        if (item.content.length > 180) contentFont -= 1.0;
        if (item.content.length > 260) contentFont -= 1.0;
        if (contentFont < 12.0) contentFont = 12.0;

        // Opacity değerini metinlere uygula
        final double textOpacity = opacityValue.clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.all(4),
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
              child: Stack(
                children: [
                  // Ana içerik (metinler)
                  Padding(
                  padding: EdgeInsets.all(GlassBarConstants.contentPadding + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title - opacity animasyonu
                      Opacity(
                        opacity: textOpacity,
                        child: AnimatedSwitcher(
                        duration: AnimationConstants.smoothTransition.duration,
                          transitionBuilder: _buildDirectionalTransition,
                        child: Text(
                            item.type == ContentType.verse 
                                ? AppLocalizations.of(context)!.dailyVerse
                                : AppLocalizations.of(context)!.dailyHadith,
                          key: ValueKey(item.title),
                          style: TextStyle(
                            color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Content: sadece taşma olduğunda scroll edilsin - opacity animasyonu
                      Expanded(
                        child: Opacity(
                          opacity: textOpacity,
                        child: LayoutBuilder(
                          builder: (context, contentConstraints) {
                            final TextStyle contentStyle = TextStyle(
                              color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                              fontSize: contentFont,
                              height: 1.4,
                              letterSpacing: 0.2,
                            );

                            final TextPainter painter = TextPainter(
                              text: TextSpan(text: item.content, style: contentStyle),
                              textAlign: TextAlign.center,
                              textDirection: Directionality.of(context),
                              maxLines: null,
                            )..layout(maxWidth: contentConstraints.maxWidth);

                            final bool isOverflowing = painter.size.height > contentConstraints.maxHeight;

                            return AnimatedSwitcher(
                              duration: AnimationConstants.smoothTransition.duration,
                                transitionBuilder: _buildDirectionalTransition,
                              child: isOverflowing
                                  ? SingleChildScrollView(
                                      key: ValueKey('${item.content}_scroll'),
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      child: Text(
                                        item.content,
                                        style: contentStyle,
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                      ),
                                    )
                                  : Center(
                                      key: ValueKey('${item.content}_static'),
                                      child: Text(
                                        item.content,
                                        style: contentStyle,
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                      ),
                                    ),
                            );
                          },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Source - opacity animasyonu
                      Opacity(
                        opacity: textOpacity,
                        child: AnimatedSwitcher(
                        duration: AnimationConstants.smoothTransition.duration,
                          transitionBuilder: _buildDirectionalTransition,
                        child: Text(
                          item.source,
                          key: ValueKey(item.source),
                          style: TextStyle(
                            color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                  // "Günlük İçerik" metni - bar kapalıyken görünür (opaklık artarak)
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - opacityValue).clamp(0.0, 1.0), // Bar kapandıkça opaklık artar
                        child: IgnorePointer(
                          ignoring: opacityValue > 0.3, // Metinler görünürken tıklanamaz
                          child: Text(
                            AppLocalizations.of(context)!.dailyContent,
                            style: TextStyle(
                              color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                              fontSize: 14,
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

  Widget _buildPageIndicator(int index, int activeIndex, Color activeColor, Color inactiveColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: activeIndex == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: activeIndex == index ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.all(4),
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
                color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                fontSize: 14,
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
      margin: const EdgeInsets.all(4),
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
      margin: const EdgeInsets.all(4),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: TextStyle(
                    color: GlassBarConstants.getTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: Text(ErrorMessages.retryLowercase(context))),
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

  factory _ContentState.fromVm(DailyContentViewModel? vm, BuildContext context) {
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
      final q = vm.ayet!.locales[vm.currentLang] ?? vm.ayet!.locales['tr'] ?? vm.ayet!.locales['en'];
      items.add(DailyContentItem(
        title: 'Günün Ayeti', // Will be localized in builder
        content: q?.text ?? '',
        source: q?.source ?? '',
        icon: Symbols.book_2,
        type: ContentType.verse,
      ));
    }
    if (vm.hadis != null) {
      final q = vm.hadis!.locales[vm.currentLang] ?? vm.hadis!.locales['tr'] ?? vm.hadis!.locales['en'];
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
  int get hashCode => Object.hash(isLoading, errorMessage, Object.hashAll(items));
}
