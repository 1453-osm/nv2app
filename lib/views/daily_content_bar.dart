import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../viewmodels/daily_content_viewmodel.dart';

class DailyContentBar extends StatefulWidget {
  const DailyContentBar({super.key});

  @override
  State<DailyContentBar> createState() => _DailyContentBarState();
}

class _DailyContentBarState extends State<DailyContentBar> {
  int _currentIndex = 0;
  bool _isForward = true;
  void _onHorizontalDrag(DragEndDetails details) {
    final isForward = details.primaryVelocity != null && details.primaryVelocity! < 0;
    final vm = context.read<DailyContentViewModel?>();
    final int itemsCount = ((vm?.ayet != null) ? 1 : 0) + ((vm?.hadis != null) ? 1 : 0);
    if (itemsCount > 1) {
      setState(() {
        _isForward = isForward;
        if (isForward && _currentIndex < itemsCount - 1) {
          _currentIndex++;
        } else if (!isForward && _currentIndex > 0) {
          _currentIndex--;
        }
      });
    } else {
      setState(() { _isForward = isForward; });
    }
  }

  // Eski statik liste kaldırıldı; içerikler VM'den geliyor

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Ekran boyutuna göre uygun kart boyutu hesaplama
    // Genişlik
    final cardWidth = isLandscape ? double.infinity : screenWidth * 0.92;
    
    // Yükseklik kısıtları (portrait için koru, landscape'te Expanded ile sığdır)
    final maxHeight = isLandscape ? screenHeight * 0.8 : screenHeight * 0.42;
    final minHeight = isLandscape ? 220.0 : 320.0;
    final cardHeight = maxHeight < minHeight ? minHeight : maxHeight;

    final card = GestureDetector(
      onHorizontalDragEnd: _onHorizontalDrag,
      child: Container(
        width: cardWidth,
        constraints: isLandscape
            ? const BoxConstraints()
            : BoxConstraints(
                minHeight: minHeight,
                maxHeight: cardHeight,
              ),
        child: Builder(
          builder: (context) {
            final vm = context.watch<DailyContentViewModel?>();
            final hasAny = (vm?.ayet != null) || (vm?.hadis != null);
            if (vm == null || (vm.isLoading && !hasAny)) {
              return _buildLoadingSkeleton();
            }
            if (vm.errorMessage != null && !hasAny) {
              return _buildErrorCard(vm.errorMessage!, onRetry: vm.retry);
            }
            final items = <DailyContentItem>[];
            if (vm.ayet != null) {
              final q = vm.ayet!.locales[vm.currentLang] ?? vm.ayet!.locales['tr'] ?? vm.ayet!.locales['en'];
              items.add(DailyContentItem(
                title: 'Günün Ayeti',
                content: q?.text ?? '',
                source: q?.source ?? '',
                icon: Symbols.book_2,
                type: ContentType.verse,
              ));
            }
            if (vm.hadis != null) {
              final q = vm.hadis!.locales[vm.currentLang] ?? vm.hadis!.locales['tr'] ?? vm.hadis!.locales['en'];
              items.add(DailyContentItem(
                title: 'Günün Hadisi',
                content: q?.text ?? '',
                source: q?.source ?? '',
                icon: Symbols.auto_stories,
                type: ContentType.hadith,
              ));
            }
            if (items.isEmpty) {
              return _buildErrorCard('İçerik bulunamadı', onRetry: vm.retry);
            }
            // Sayfalamayı eski mantıkla koruyoruz
            final index = _currentIndex.clamp(0, items.length - 1);
            return _buildContentCard(items[index]);
          },
        ),
      ),
    );

    return Column(
      children: [
        if (isLandscape) Expanded(child: card) else card,
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final vm = context.watch<DailyContentViewModel?>();
            final int itemsCount = ((vm?.ayet != null) ? 1 : 0) + ((vm?.hadis != null) ? 1 : 0);
            final count = itemsCount == 0 ? 1 : itemsCount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (index) => _buildPageIndicator(index)),
            );
          },
        ),
        const SizedBox(height: 0),
      ],
    );
  }

  Widget _buildContentCard(DailyContentItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final availableH = constraints.maxHeight.isFinite ? constraints.maxHeight : MediaQuery.of(context).size.height * (isLandscape ? 0.6 : 0.35);
        final availableW = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        // Dinamik font: yüksekliğe ve genişliğe göre sınırla, metin uzunluğuna göre ince ayar
        double contentFont = (availableW * 0.045).clamp(12.0, isLandscape ? 20.0 : 18.0);
        if (availableH < 260) contentFont -= 1.0;
        if (item.content.length > 180) contentFont -= 1.0;
        if (item.content.length > 260) contentFont -= 1.0;
        if (contentFont < 12.0) contentFont = 12.0;

        return Container(
          margin: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: GlassBarConstants.blurSigma,
                sigmaY: GlassBarConstants.blurSigma,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: GlassBarConstants.getBackgroundColor(context),
                  borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                  border: Border.all(
                    color: GlassBarConstants.getBorderColor(context),
                    width: GlassBarConstants.borderWidth,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(GlassBarConstants.contentPadding + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      AnimatedSwitcher(
                        duration: AnimationConstants.smoothTransition.duration,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(_isForward ? 0.1 : -0.1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          item.title,
                          key: ValueKey(item.title),
                          style: TextStyle(
                            color: GlassBarConstants.getTextColor(context).withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Content: sadece taşma olduğunda scroll edilsin
                      Expanded(
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
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(_isForward ? 0.1 : -0.1, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
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

                      const SizedBox(height: 16),

                      // Source
                      AnimatedSwitcher(
                        duration: AnimationConstants.smoothTransition.duration,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(_isForward ? 0.1 : -0.1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Tema uyumlu renk seçimi
    final activeColor = isDark 
        ? theme.colorScheme.primary
        : GlassBarConstants.getTextColor(context);
    
    final inactiveColor = isDark 
        ? theme.colorScheme.primary.withValues(alpha: 0.3)
        : GlassBarConstants.getTextColor(context).withValues(alpha: 0.3);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentIndex == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentIndex == index ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassBarConstants.blurSigma,
            sigmaY: GlassBarConstants.blurSigma,
          ),
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
      ),
    );
  }

  Widget _buildErrorCard(String message, {required VoidCallback onRetry}) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassBarConstants.blurSigma,
            sigmaY: GlassBarConstants.blurSigma,
          ),
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
                TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
              ],
            ),
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
}

enum ContentType { verse, hadith } 