import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../viewmodels/qibla_viewmodel.dart';
import '../models/location_model.dart';
import '../utils/constants.dart';
import 'dart:math' as math;

class QiblaBar extends StatefulWidget {
  final SelectedLocation? location;
  final Function(bool)? onExpandedChanged;
  
  const QiblaBar({
    Key? key,
    this.location,
    this.onExpandedChanged,
  }) : super(key: key);

  @override
  State<QiblaBar> createState() => QiblaBarState();
}

class QiblaBarState extends State<QiblaBar> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _iconPositionAnimation;
  late Animation<double> _fadeAnimation;
  
  static const double _collapsedSize = 40.0;
  static const double _expandedSize = 200.0;
  bool _previousIsExpanded = false;
  SelectedLocation? _lastCalculatedLocation;

  // Performans için cache değişkenleri
  Color? _cachedTextColor;
  Color? _cachedBackgroundColor;
  Color? _cachedBorderColor;
  
  // Animation optimization: Cache animation values
  bool get _shouldShowExpandedContent => 
      _animationController.status == AnimationStatus.forward ||
      _animationController.status == AnimationStatus.completed ||
      (_animationController.status == AnimationStatus.reverse && _animationController.value > 0.0);

  // Widget optimization: Create commonly used widgets as methods
  Widget _buildNavigationIcon(QiblaViewModel viewModel, Color textColor, double size, double iconPosition) {
    final bool isGpsError = viewModel.status == QiblaStatus.error && viewModel.errorMessage == 'GPS konumu alınamadı';
    return Positioned(
      top: isGpsError ? lerpDouble(size / 2 - 11, 15, iconPosition) : lerpDouble(size / 2 - 14, 15, iconPosition),
      left: isGpsError ? size / 2 - 13 : size / 2 - 14,
      child: GestureDetector(
        onTap: () => viewModel.toggleExpansion(),
        child: Transform.rotate(
          angle: (!isGpsError && viewModel.status == QiblaStatus.ready) 
              ? (viewModel.qiblaDirection - viewModel.currentDirection) * (math.pi / 180)
              : 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: isGpsError ? 0.8 : 1.0,
                child: Icon(
                  isGpsError ? Symbols.near_me_disabled : Symbols.navigation_rounded,
                  color: textColor,
                  size: isGpsError ? 20 : 24,
                ),
              ),
              if (viewModel.status == QiblaStatus.needsCalibration)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.3),
                        width: 1,
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

  Widget _buildTitle(Color textColor) {
    return Positioned(
      top: 47,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_animationController.isCompleted,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Kıble Pusulası',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton(QiblaViewModel viewModel, Color textColor) {
    return Positioned(
      bottom: 10,
      right: 10,
      child: IgnorePointer(
        ignoring: !_animationController.isCompleted,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () => viewModel.refreshCompass(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Symbols.refresh,
                color: textColor,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AnimationConstants.expansionTransition.duration,
      vsync: this,
    );

    _sizeAnimation = Tween<double>(
      begin: _collapsedSize,
      end: _expandedSize,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationConstants.expansionTransition.curve,
    ));
    
    _iconPositionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationConstants.expansionTransition.curve,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void closeQiblaBar() {
    final viewModel = context.read<QiblaViewModel>();
    viewModel.closeQiblaBar();
  }

  // Helper method for handling expansion animation
  void _handleExpansionAnimation(QiblaViewModel viewModel) {
    if (viewModel.isExpanded != _previousIsExpanded) {
      if (viewModel.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      _previousIsExpanded = viewModel.isExpanded;
      
      // Safe callback execution with mounting check
      _safePostFrameCallback(() {
        widget.onExpandedChanged?.call(viewModel.isExpanded);
      });
    }
  }

  // Helper method for handling location changes
  void _handleLocationChange(QiblaViewModel viewModel) {
    if (widget.location != null && 
        (_lastCalculatedLocation == null || 
         _lastCalculatedLocation!.city.id != widget.location!.city.id)) {
      _lastCalculatedLocation = widget.location;
      _safePostFrameCallback(() {
        viewModel.calculateQiblaDirection(widget.location!);
      });
    }
  }

  // Safe callback execution method to prevent memory leaks
  void _safePostFrameCallback(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback();
      }
    });
  }

  // Helper method for getting bar colors based on qibla status
  ({Color backgroundColor, Color borderColor}) _getBarColors(
    QiblaViewModel viewModel, 
    BuildContext context
  ) {
    if (viewModel.isPointingToQibla && viewModel.status == QiblaStatus.ready) {
      return (
        backgroundColor: Colors.green.withValues(alpha: 0.3),
        borderColor: Colors.green.withValues(alpha: 0.7),
      );
    }
    return (
      backgroundColor: GlassBarConstants.getBackgroundColor(context),
      borderColor: GlassBarConstants.getBorderColor(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QiblaViewModel>(
      builder: (context, viewModel, child) {
        _handleExpansionAnimation(viewModel);
        _handleLocationChange(viewModel);

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final size = _sizeAnimation.value;
            final iconPosition = _iconPositionAnimation.value;

            final cachedValues = _getCachedAnimationValues(context);
            final textColor = cachedValues.textColor;
            final barColors = _getBarColors(viewModel, context);

            return Container(
              width: size,
              height: size,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassBarConstants.blurSigma, 
                    sigmaY: GlassBarConstants.blurSigma
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColors.backgroundColor,
                      borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                      border: Border.all(
                        color: barColors.borderColor,
                        width: GlassBarConstants.borderWidth,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Navigasyon ikonu - pozisyon animasyonlu
                        _buildNavigationIcon(viewModel, textColor, size, iconPosition),
                        
                        // Başlık - fade animasyonlu
                        if (_shouldShowExpandedContent)
                          _buildTitle(textColor),
                        
                        // Orta kısım - mesafe, loading veya GPS hata durumu
                        if (_shouldShowExpandedContent)
                          Positioned(
                            top: 75,
                            left: 5,
                            right: 5,
                            child: IgnorePointer(
                              ignoring: !viewModel.isExpanded,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: viewModel.status == QiblaStatus.ready 
                                    ? _buildDistanceContent(viewModel, textColor)
                                    : viewModel.status == QiblaStatus.loading
                                        ? _buildLoadingContent(viewModel, textColor)
                                        : (viewModel.status == QiblaStatus.error && viewModel.errorMessage == 'GPS konumu alınamadı')
                                            ? _buildCenterErrorContent(viewModel, textColor)
                                            : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        
                        // Sol alt kısım - sadece GPS dışı hatalar ve calibration mesajları
                        if (_shouldShowExpandedContent && ((viewModel.status == QiblaStatus.error && viewModel.errorMessage != 'GPS konumu alınamadı') || viewModel.status == QiblaStatus.needsCalibration))
                          Positioned(
                            bottom: 45,
                            left: 8,
                            right: 8,
                            child: IgnorePointer(
                              ignoring: !viewModel.isExpanded,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildStatusMessage(viewModel, textColor),
                              ),
                            ),
                          ),
                        
                        // Kalibrasyon bilgisi - sol alt (her zaman sabit)
                        if (_shouldShowExpandedContent)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 50, // sağda yenile butonu için boşluk bırak
                            child: IgnorePointer(
                              ignoring: !viewModel.isExpanded,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/calibre.gif',
                                        width: 80,
                                        height: 40,
                                        fit: BoxFit.fitWidth,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Symbols.gesture,
                                          color: textColor,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 0),
                                      Text(
                                        'Cihazınızı kalibre etmeyi\nunutmayın',
                                        softWrap: true,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Yenileme butonu
                        if (_shouldShowExpandedContent)
                          _buildRefreshButton(viewModel, textColor),

                        // Konum ayarlarını açma butonu - yenile butonunun üstünde
                        if (_shouldShowExpandedContent)
                          Positioned(
                            bottom: 50,
                            right: 10,
                            child: IgnorePointer(
                              ignoring: !_animationController.isCompleted,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: GestureDetector(
                                  onTap: () => viewModel.openLocationSettings(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: textColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Symbols.location_on,
                                      color: textColor,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],                 
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildDistanceContent(QiblaViewModel viewModel, Color textColor) {
    return Column(
      children: [
        Text(
          'Kabe\'ye mesafe',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 0),
        Text(
          '${viewModel.distanceToKaaba.toStringAsFixed(0)} km',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoadingContent(QiblaViewModel viewModel, Color textColor) {
    return Column(
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hesaplanıyor...',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCenterErrorContent(QiblaViewModel viewModel, Color textColor) {
    return Column(
      children: [
        Icon(
          Symbols.error,
          color: Colors.red,
          size: 14,
        ),
        const SizedBox(height: 4),
        Text(
          'GPS konumu alınamadı',
          style: TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildStatusMessage(QiblaViewModel viewModel, Color textColor) {
    switch (viewModel.status) {
      case QiblaStatus.loading:
      case QiblaStatus.ready:
        return const SizedBox.shrink();
      
      case QiblaStatus.error:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error,
              color: Colors.red,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                viewModel.errorMessage,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      
      case QiblaStatus.needsCalibration:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.compass_calibration,
              color: Colors.orange,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'Pusula kalibre edilmeli',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
    }
  }

  // Animasyon sırasında yoğun hesaplamaları önlemek için değerleri cache'ler
  ({Color textColor, Color backgroundColor, Color borderColor}) _getCachedAnimationValues(BuildContext context) {
    // Her animasyon frame'inde renkleri yeniden hesaplamaktansa cache kullan
    _cachedTextColor ??= GlassBarConstants.getTextColor(context);
    _cachedBackgroundColor ??= GlassBarConstants.getBackgroundColor(context);
    _cachedBorderColor ??= GlassBarConstants.getBorderColor(context);

    return (
      textColor: _cachedTextColor!,
      backgroundColor: _cachedBackgroundColor!,
      borderColor: _cachedBorderColor!,
    );
  }
}