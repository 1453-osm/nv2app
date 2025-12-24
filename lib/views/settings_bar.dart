import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/theme_service.dart';
import 'dart:async';
import '../services/widget_bridge.dart';
import '../services/notification_scheduler_service.dart';
import '../services/notification_settings_service.dart' as notifsvc;
import '../services/notification_sound_service.dart';
import 'package:flutter/physics.dart';

// ThemeColorMode artık ThemeService'ten import ediliyor

// Tema rengi modu carousel öğesi (top-level, library private)
class _ColorModeItem {
  final IconData icon;
  final String label;
  final ThemeColorMode mode;
  const _ColorModeItem({required this.icon, required this.label, required this.mode});
}

class _ModeCylinderWidget extends StatefulWidget {
  final List<_ColorModeItem> items;
  final int selectedIndex;
  final Color textColor;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<int> onSelectedChanged;

  const _ModeCylinderWidget({
    required this.items,
    required this.selectedIndex,
    required this.textColor,
    required this.isDark,
    required this.theme,
    required this.onSelectedChanged,
  });

  @override
  State<_ModeCylinderWidget> createState() => _ModeCylinderWidgetState();
}

class _ModeCylinderWidgetState extends State<_ModeCylinderWidget>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  Simulation? _simulation;
  
  // Döngü durumu
  double _totalRotation = 4.0; // Toplam dönüş açısı (radyan)
  bool _isDragging = false; // Kullanıcı sürüklüyor mu

  // Çember konfigürasyonu - 3D silindir için optimize edilmiş
  static const double _radius = 65.0;
  static const double _itemAngle = 2 * math.pi / 4; // 4 öğe
  static const double _perspective = 0.010;
  
  // Discrete mode switching parametreleri
  static const double _dragSensitivity = 0.004; // Daha hassas kontrol
  static const double _velocityThreshold = 800.0; // Yüksek eşik = daha az fling
  static const double _snapThreshold = 0.3; // 30% geçiş için yeterli
  static const double _magneticZone = 0.8; // 80% yaklaşınca manyetik çekme
  
  // Aggressive snap physics
  static const double _springStiffness = 500.0; // Çok hızlı snap
  static const double _springDamping = 25.0; // Overdamped, tek geçiş
  
  // Platform-specific physics
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _totalRotation = _currentIndex * _itemAngle;
    
    _controller = AnimationController.unbounded(
      vsync: this,
      value: _totalRotation,
    )
      ..addListener(_handleAnimationUpdate)
      ..addStatusListener(_handleAnimationStatus);
  }
  
  void _handleAnimationUpdate() {
    if (!mounted) return;
      setState(() {
      _totalRotation = _controller.value;
    });
    _updateCurrentIndex();
  }
  
  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      _simulation = null;
      // Profesyonel uygulamalarda selection feedback
      _triggerSelectionFeedback();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startFling(double pixelsPerSecond) {
    if (!mounted) return;
    
    // Discrete mode switching: limit fling distance
    final double velocity = -pixelsPerSecond * _dragSensitivity;
    final double clampedVelocity = velocity.clamp(-2.0, 2.0); // Çok sınırlı hız
    
    // Determine target based on velocity direction and current position
    final double currentNormalized = _controller.value / _itemAngle;
    final int currentStep = currentNormalized.round();
    
    // Velocity direction'a göre target belirle
    int targetStep;
    if (clampedVelocity.abs() < 0.5) {
      // Düşük hız: en yakın pozisyona snap
      targetStep = currentStep;
    } else if (clampedVelocity > 0) {
      // Pozitif yön: maksimum 1 adım ileri
      targetStep = currentStep + 1;
    } else {
      // Negatif yön: maksimum 1 adım geri
      targetStep = currentStep - 1;
    }
    
    final double targetRotation = targetStep * _itemAngle;
    
    // Direct spring to target (no friction phase)
    _simulation = SpringSimulation(
      SpringDescription(
        mass: 1.0,
        stiffness: _springStiffness,
        damping: _springDamping,
      ),
      _controller.value,
      targetRotation,
      clampedVelocity, // Preserve some momentum for direction
    );
    
    _controller.animateWith(_simulation!);
  }

  void _snapToNearestPosition() {
    if (!mounted) return;
    
    final double currentPosition = _controller.value;
    final double normalizedRotation = currentPosition / _itemAngle;
    
    // Smart snapping: hangi yöne yakınsa o tarafa snap yap
    final double targetStep = _getSmartSnapTarget(normalizedRotation);
    final double targetRotation = targetStep * _itemAngle;

    // Skip snap if already very close
    if ((targetRotation - currentPosition).abs() <= 0.001) {
      _simulation = null;
      return;
    }

    // Aggressive spring for immediate, precise snapping
    _simulation = SpringSimulation(
      SpringDescription(
        mass: 1.0,
        stiffness: _springStiffness,
        damping: _springDamping,
      ),
      currentPosition,
      targetRotation,
      0.0, // Zero velocity for clean snap
    );
    
    _controller.animateWith(_simulation!);
  }
  
  double _getSmartSnapTarget(double normalizedRotation) {
    final double fractionalPart = normalizedRotation - normalizedRotation.floor();
    final double floorStep = normalizedRotation.floor().toDouble();
    final double ceilStep = normalizedRotation.ceil().toDouble();
    
    // Magnetik zone: 80% geçince otomatik snap
    if (fractionalPart >= _magneticZone) {
      return ceilStep;
    } else if (fractionalPart <= (1.0 - _magneticZone)) {
      return floorStep;
    }
    
    // Normal zone: 30% threshold ile snap
    if (fractionalPart >= _snapThreshold) {
      return ceilStep;
    } else {
      return floorStep;
    }
  }
  
  double _applyMagneticEffect(double rotation) {
    final double normalizedRotation = rotation / _itemAngle;
    final double fractionalPart = normalizedRotation - normalizedRotation.floor();
    final double floorStep = normalizedRotation.floor().toDouble();
    
    // Magnetik zone içindeyse çekme efekti uygula
    if (fractionalPart >= _magneticZone) {
      // Üst limite yakın: magnetik çekme
      final double pullStrength = (fractionalPart - _magneticZone) / (1.0 - _magneticZone);
      final double pulledRotation = (floorStep + _magneticZone + pullStrength * 0.15) * _itemAngle;
      return pulledRotation;
    } else if (fractionalPart <= (1.0 - _magneticZone)) {
      // Alt limite yakın: magnetik çekme  
      final double pullStrength = ((1.0 - _magneticZone) - fractionalPart) / (1.0 - _magneticZone);
      final double pulledRotation = (floorStep + (1.0 - _magneticZone) - pullStrength * 0.15) * _itemAngle;
      return pulledRotation;
    }
    
    // Normal zone: değişiklik yok
    return rotation;
  }

  void _updateCurrentIndex() {
    final double normalizedRotation = _totalRotation / _itemAngle;
    final int newIndex = (normalizedRotation.round()) % widget.items.length;
    final int positiveIndex = newIndex < 0 ? newIndex + widget.items.length : newIndex;
    
    if (positiveIndex != _currentIndex) {
      _currentIndex = positiveIndex;
      
      // Profesyonel feedback: sadece gerçek değişiklikte
      if (!_isDragging) {
        _triggerSelectionFeedback();
      }
      
      // Callback with debouncing for professional UX
      widget.onSelectedChanged(_currentIndex);
    }
  }
  
  void _triggerSelectionFeedback() {
    // Platform-specific haptic feedback
    if (_isIOS) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final isDark = widget.isDark;
    final theme = widget.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return SizedBox(
            width: w,
            height: 100,
            child: GestureDetector(
              // Tüm alan kaydırılabilir
              behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              // Stop any ongoing animations
              _controller.stop();
              _simulation = null;
              _isDragging = true;
              
              // iOS style drag start feedback
              if (_isIOS) {
                HapticFeedback.selectionClick();
              }
            },
            onPanUpdate: (details) {
              if (!_isDragging) return;
              
              // Discrete drag with magnetic snapping
              final double delta = details.delta.dx * _dragSensitivity;
              final double rawNewRotation = _totalRotation - delta;
              
              // Apply magnetic effect near boundaries
              final double magneticRotation = _applyMagneticEffect(rawNewRotation);
              
              // Direct controller update for immediate response
              _controller.value = magneticRotation;
              _totalRotation = magneticRotation;
              
              // Live index updates during drag (without haptic feedback)
              _updateCurrentIndex();
            },
            onPanEnd: (details) {
              _isDragging = false;
              
              // Profesyonel velocity-based decision
              final double velocity = details.velocity.pixelsPerSecond.dx;
              
              if (velocity.abs() > _velocityThreshold) {
                _startFling(velocity);
              } else {
                // Immediate snap for low velocity
                _snapToNearestPosition();
            }
          },
          onTapUp: (d) {
              if (_isDragging || w <= 0) return;
            if (d.localPosition.dx > w * 0.6) {
                _snapToNearestPosition();
            } else if (d.localPosition.dx < w * 0.4) {
                _snapToNearestPosition();
            }
          },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Anlık rotasyon değerini hesapla
                final double currentRotation = _controller.value;
                
                final indices = List<int>.generate(items.length, (i) => i);
                // Derinliğe göre sırala (arkadakiler önce çizilsin)
                indices.sort((a, b) {
                  final double angleA = (a * _itemAngle) - currentRotation;
                  final double angleB = (b * _itemAngle) - currentRotation;
                  final double zA = _radius * math.cos(angleA);
                  final double zB = _radius * math.cos(angleB);
                  return zA.compareTo(zB);
                });

                return Stack(
                  clipBehavior: Clip.none,
                  children: indices.map((i) {
                    final double angle = (i * _itemAngle) - currentRotation;
                    final double normalizedAngle = ((angle + math.pi) % (2 * math.pi)) - math.pi;
                    
                    final double x = _radius * math.sin(normalizedAngle);
                    final double z = _radius * math.cos(normalizedAngle);
                    final double depthScale = (z + _radius) / (2 * _radius);
                    
                    // 3D efekt için opacity ve scale hesaplama
                    // Arkadaki ikonlar çok saydam olsun
                    final double opacity = depthScale < 0.3 ? 0.0 : (0.2 + 0.8 * depthScale);
                    final double scale = 0.7 + 0.3 * depthScale;
                    
                    // Y ekseni offseti (perspektif efekti)
                    final double yOffset = (1.0 - depthScale) * 15.0;

                    final item = items[i];
                    // En önde olan öğeyi seçili olarak işaretle (en yüksek depthScale)
                    final bool isSelected = depthScale > 0.85;

                    return Positioned(
                      left: w / 2 + x - 40,
                      top: 15 + yOffset,
                      child: Opacity(
                        opacity: opacity,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                            ..setEntry(3, 2, _perspective)
                            ..rotateY(-normalizedAngle * 0.6), // İkonların arkası silindire dönük
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 80,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: (isDark
                                          ? theme.colorScheme.surface.withOpacity(0.3 * depthScale)
                                          : Colors.white.withOpacity(0.18 * depthScale)),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isDark
                                                ? theme.colorScheme.primary.withOpacity(0.6 * depthScale)
                                                : Colors.white.withOpacity(0.6 * depthScale))
                                            : (isDark
                                                ? theme.colorScheme.outline.withOpacity(0.35 * depthScale)
                                                : Colors.white.withOpacity(0.25 * depthScale)),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                      boxShadow: [
                                        // Derinlik gölgesi - arkadakiler için minimal
                                        if (depthScale > 0.3)
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08 * (1.0 - depthScale)),
                                            blurRadius: 6 * (1.0 - depthScale),
                                            offset: Offset(0, 3 * (1.0 - depthScale)),
                                          ),
                                        if (isSelected)
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withOpacity(0.3 * depthScale),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      item.icon,
                                      size: 22,
                                      color: isSelected
                                          ? (isDark ? theme.colorScheme.primary : Colors.white).withOpacity(opacity)
                                          : widget.textColor.withOpacity(0.8 * opacity),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.0,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? theme.colorScheme.primary : Colors.white).withOpacity(opacity)
                                            : widget.textColor.withOpacity(0.8 * opacity),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// Artık NotificationSetting sınıfı services/notification_settings_service.dart'dan kullanılıyor

// Minute picker widget
class _MinutePickerWidget extends StatefulWidget {
  final String id;
  final int currentMinutes;
  final Color textColor;
  final Function(String, int) onMinuteChanged;

  const _MinutePickerWidget({
    required this.id,
    required this.currentMinutes,
    required this.textColor,
    required this.onMinuteChanged,
  });

  @override
  State<_MinutePickerWidget> createState() => _MinutePickerWidgetState();
}

class _MinutePickerWidgetState extends State<_MinutePickerWidget> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  static const Duration _animationDuration = AnimationConstants.medium;
  static const Duration _momentumDuration = AnimationConstants.pickerMomentum;
  
  late final AnimationController _valueChangeController;
  late final Animation<double> _valueChangeAnimation;
  late final AnimationController _momentumController;
  late Animation<double> _momentumAnimation;
  
  double _wheelOffset = 0.0;
  int _currentIndex = 0;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    _currentIndex = SettingsConstants.notificationMinutes.indexOf(widget.currentMinutes);
    if (_currentIndex == -1) _currentIndex = 0;
    
    _valueChangeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _momentumController = AnimationController(
      duration: _momentumDuration,
      vsync: this,
    );
    
    _valueChangeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _valueChangeController, 
      curve: AnimationConstants.elasticOut,
    ));
    
    _wheelOffset = 0.0;
  }

  @override
  void dispose() {
    _momentumController.removeListener(_momentumListener);
    _valueChangeController.dispose();
    _momentumController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _momentumController.stop();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (mounted) {
      setState(() {
        _wheelOffset -= details.delta.dx;
      });
      _checkValueChange();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    
    if (velocity.abs() > 300) {
      _startMomentumScroll(velocity);
    } else {
      _snapToNearestValue();
    }
  }

  void _startMomentumScroll(double velocity) {
    final double currentOffset = _wheelOffset;
    final double momentumDistance = -velocity * 0.3;
    final double targetOffset = currentOffset + momentumDistance;
    
    _momentumAnimation = Tween<double>(
      begin: currentOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _momentumController, 
      curve: AnimationConstants.decelerate,
    ));
    
    _momentumController.removeListener(_momentumListener);
    _momentumController.addListener(_momentumListener);
    
    _momentumController.reset();
    _momentumController.forward().then((_) {
      if (mounted) _snapToNearestValue();
    });
  }
  
  void _momentumListener() {
    if (_momentumController.isAnimating && mounted) {
      setState(() {
        _wheelOffset = _momentumAnimation.value;
      });
      _checkValueChange();
    }
  }

  void _checkValueChange() {
    final double normalizedOffset = _wheelOffset / SettingsConstants.pickerLineSpacing;
    final int rawIndex = normalizedOffset.round();
    final int nearestIndex = rawIndex % SettingsConstants.notificationMinutes.length;
    final int positiveIndex = nearestIndex < 0 ? nearestIndex + SettingsConstants.notificationMinutes.length : nearestIndex;
    
    if (positiveIndex != _currentIndex) {
      _currentIndex = positiveIndex;
      
      if (mounted) {
        if (!_valueChangeController.isAnimating) {
          _valueChangeController.reset();
          _valueChangeController.forward();
        }
        
        widget.onMinuteChanged(widget.id, SettingsConstants.notificationMinutes[_currentIndex]);
      }
    }
  }

  void _snapToNearestValue() {
    if (!mounted) return;
    
    final double normalizedOffset = _wheelOffset / SettingsConstants.pickerLineSpacing;
    final double nearestStep = normalizedOffset.roundToDouble();
    final double targetOffset = nearestStep * SettingsConstants.pickerLineSpacing;
    
    setState(() {
      _wheelOffset = targetOffset;
    });
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final double localX = details.localPosition.dx;
    final double centerX = renderBox.size.width / 2;
    
    if (localX < centerX - 20) {
      _changeValueBySteps(-1);
    } else if (localX > centerX + 20) {
      _changeValueBySteps(1);
    }
  }

  void _changeValueBySteps(int steps) {
    final int newIndex = (_currentIndex + steps) % SettingsConstants.notificationMinutes.length;
    final int positiveIndex = newIndex < 0 ? newIndex + SettingsConstants.notificationMinutes.length : newIndex;
    
    if (positiveIndex != _currentIndex && mounted) {
      setState(() {
        _currentIndex = positiveIndex;
        final double currentNormalized = _wheelOffset / SettingsConstants.pickerLineSpacing;
        final double targetNormalized = currentNormalized.roundToDouble() + steps;
        _wheelOffset = targetNormalized * SettingsConstants.pickerLineSpacing;
      });
      
      _valueChangeController.reset();
      _valueChangeController.forward();
      
      widget.onMinuteChanged(widget.id, SettingsConstants.notificationMinutes[_currentIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    
    return RepaintBoundary(
      child: GestureDetector(
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onTapUp: _handleTap,
        child: SizedBox(
          height: 40,
          child: Stack(
            children: [
              // Kayan çark çizgileri - Optimized AnimatedBuilder
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedBuilder(
                    animation: _momentumController.isAnimating 
                        ? _momentumController 
                        : _valueChangeController,
                    builder: (context, child) {
                      final double currentOffset = _momentumController.isAnimating 
                          ? _momentumAnimation.value 
                          : _wheelOffset;
                      
                      return RepaintBoundary(
                        child: CustomPaint(
                          painter: _WheelPainter(
                            textColor: widget.textColor,
                            offset: -currentOffset,
                            lineSpacing: SettingsConstants.pickerLineSpacing,
                            visibleLines: SettingsConstants.pickerVisibleLines,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Merkez vurgu çizgisi (aktif seçim) - Cache edilmiş widget
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _valueChangeAnimation,
                    builder: (context, child) => Center(
                      child: Transform.scale(
                        scale: _valueChangeAnimation.value,
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 2,
                      height: 30,
                      decoration: BoxDecoration(
                        color: GlassBarConstants.getTextColor(context),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ), // Cache edilmiş widget
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Optimized CustomPainter - Paint nesneleri static cache ile optimize
class _WheelPainter extends CustomPainter {
  final Color textColor;
  final double offset;
  final double lineSpacing;
  final int visibleLines;
  
  // Static cache for paint objects
  static final Map<Color, Paint> _mainLinePaintCache = {};
  static final Map<Color, Paint> _subLinePaintCache = {};
  
  late final Paint _mainLinePaint;
  late final Paint _subLinePaint;

  _WheelPainter({
    required this.textColor,
    required this.offset,
    required this.lineSpacing,
    required this.visibleLines,
  }) {
    // Cache'den al veya yeni oluştur
    _mainLinePaint = _mainLinePaintCache.putIfAbsent(
      textColor, 
      () => Paint()
        ..color = textColor.withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    
    _subLinePaint = _subLinePaintCache.putIfAbsent(
      textColor,
      () => Paint()
        ..color = textColor.withOpacity(0.15)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height * 0.5;
    final double startX = offset % lineSpacing - lineSpacing;
    final double width = size.width;
    
    // Optimized drawing - sadece görünür çizgileri çiz
    for (int i = 0; i <= visibleLines + 2; i++) {
      final double x = startX + (i * lineSpacing);
      
      if (x >= 1 && x <= width) {
        canvas.drawLine(
          Offset(x, centerY - 10),
          Offset(x, centerY + 10),
          _mainLinePaint,
        );
      }
      
      final double midX = x + (lineSpacing * 0.5);
      if (midX >= 0 && midX <= width) {
        canvas.drawLine(
          Offset(midX, centerY - 6),
          Offset(midX, centerY + 6),
          _subLinePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return offset != oldDelegate.offset || 
           textColor != oldDelegate.textColor ||
           lineSpacing != oldDelegate.lineSpacing ||
           visibleLines != oldDelegate.visibleLines;
  }
  
  @override
  bool shouldRebuildSemantics(covariant _WheelPainter oldDelegate) => false;
}

class SettingsBar extends StatefulWidget {
  final VoidCallback? onSettingsPressed;
  final AppThemeMode themeMode;
  final Function(AppThemeMode) onThemeChanged;
  final Function(bool)? onExpandedChanged;

  const SettingsBar({
    Key? key,
    this.onSettingsPressed,
    required this.themeMode,
    required this.onThemeChanged,
    this.onExpandedChanged,
  }) : super(key: key);

  @override
  State<SettingsBar> createState() => SettingsBarState();
}

class SettingsBarState extends State<SettingsBar> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  static const double _expandedHeight = 350.0;
  // Yüzdelik artışlar: genişlik %14, yükseklik %10
  static const double _subpageExtraWidthFraction = 0.14;
  static const double _subpageExtraHeightFraction = 0.10;

  double get _maxSubpageExtraWidth => GlassBarConstants.expandedWidth * _subpageExtraWidthFraction;
  double get _maxSubpageExtraHeight => _expandedHeight * _subpageExtraHeightFraction;

  bool _isExpanded = false;
  bool _isColorPickerVisible = false;
  bool _isNotificationsVisible = false;
  bool _isWidgetSettingsVisible = false;
  bool _isSmallWidgetExpanded = false;
  double _widgetOpacity = 1.0;
  bool _gradientEnabled = true;
  bool _isWidgetAdded = false;
  int _bgColorMode = 0; // 0: Sistem, 1: Açık, 2: Koyu
  int _textColorMode = 0; // 0: Sistem, 1: Koyu, 2: Açık (Android beklentisi)
  int _textOnlyColorMode = 0;
  int _textOnlyScalePct = 100;
  bool _isTextWidgetAdded = false;
  bool _isTextWidgetExpanded = false;


  // Re-adding necessary field declarations
  late List<notifsvc.NotificationSetting> _notificationSettings;
  int _widgetRadius = 75;

  late final AnimationController _animationController;
  late final AnimationController _titleOpacityController;
  late final AnimationController _toggleAnimationController;
  late final AnimationController _subpageSizeController;

  late final Animation<double> _widthAnimation;
  late final Animation<double> _heightAnimation;
  late final Animation<double> _titleOpacityAnimation;
  late final Animation<double> _toggleSlideAnimation;
  late final Animation<double> _subpageWidthAnimation;
  late final Animation<double> _subpageHeightAnimation;

  // Theme color mode cylinder selector state handled by dedicated widget

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(seconds: 1), () {
      _checkWidgetStatus();
    });
    _initializeNotificationSettings();
    _initializeAnimations();
    _loadWidgetAppearance();

    // Mode selector internal controller is self-contained in cylinder widget
  }

  Future<void> _checkWidgetStatus() async {
    // Only check if widget settings page is currently visible
    if (!_isWidgetSettingsVisible) return;

    try {
      final bool result = await WidgetBridgeService.isSmallWidgetPinned();
      debugPrint('Widget added state: $result');
      setState(() {
        _isWidgetAdded = result;
      });
    } catch (e) {
      debugPrint('Error checking widget status: $e');
    }
  }
  
  // Periyodik kontrol kaldırıldı; yalnızca sayfaya girildiğinde ve ekleme sonrası kontrol edilir
  
  void _initializeNotificationSettings() async {
    try {
      final svc = notifsvc.NotificationSettingsService();
      if (!svc.isLoaded) {
        await svc.loadSettings();
      }
      
      if (mounted) {
        setState(() {
          _notificationSettings = svc.settings.toList();
        });
      }
    } catch (_) {
      // Hata durumunda varsayılan ayarları kullan
      if (mounted) {
        setState(() {
          _notificationSettings = [
            const notifsvc.NotificationSetting(id: 'imsak', title: 'İmsak', minutes: 5),
            const notifsvc.NotificationSetting(id: 'gunes', title: 'Güneş', minutes: 0),
            const notifsvc.NotificationSetting(id: 'ogle', title: 'Öğle', minutes: 5),
            const notifsvc.NotificationSetting(id: 'ikindi', title: 'İkindi', minutes: 5),
            const notifsvc.NotificationSetting(id: 'aksam', title: 'Akşam', minutes: 5),
            const notifsvc.NotificationSetting(id: 'yatsi', title: 'Yatsı', minutes: 5),
            const notifsvc.NotificationSetting(id: 'cuma', title: 'Cuma', minutes: 30),
            const notifsvc.NotificationSetting(id: 'dua', title: 'Dua Bildirimi', minutes: 5),
          ];
        });
      }
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AnimationConstants.expansionTransition.duration,
      vsync: this,
    );
    
    _titleOpacityController = AnimationController(
      duration: AnimationConstants.smoothTransition.duration,
      vsync: this,
    );
    
    _toggleAnimationController = AnimationController(
      duration: AnimationConstants.smoothTransition.duration,
      vsync: this,
    );
    
    _subpageSizeController = AnimationController(
      duration: AnimationConstants.smoothTransition.duration,
      vsync: this,
    );
    
    _widthAnimation = Tween<double>(
      begin: 40.0,
      end: GlassBarConstants.expandedWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationConstants.expansionTransition.curve,
    ));
    
    _heightAnimation = Tween<double>(
      begin: 40.0,
      end: _expandedHeight,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationConstants.expansionTransition.curve,
    ));
    
    _subpageWidthAnimation = Tween<double>(
      begin: 0.0,
      end: _maxSubpageExtraWidth,
    ).animate(CurvedAnimation(
      parent: _subpageSizeController,
      curve: AnimationConstants.smoothTransition.curve,
    ));
    
    _subpageHeightAnimation = Tween<double>(
      begin: 0.0,
      end: _maxSubpageExtraHeight,
    ).animate(CurvedAnimation(
      parent: _subpageSizeController,
      curve: AnimationConstants.smoothTransition.curve,
    ));
    
    
    _titleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleOpacityController,
      curve: AnimationConstants.expansionTransition.curve,
    ));
    
    _toggleSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toggleAnimationController, 
      curve: AnimationConstants.smoothTransition.curve,
    ));
    
    // Toggle pozisyonunu başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTogglePosition();
    });
  }

  Widget _buildTriToggle({
    required int value,
    required List<String> labels,
    required ValueChanged<int> onChanged,
  }) {
    assert(labels.length == 3);
    final Color border = GlassBarConstants.getBorderColor(context);
    final Color bg = GlassBarConstants.getBackgroundColor(context);
    final Color text = GlassBarConstants.getTextColor(context);
    return Container
    (
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: List.generate(3, (i) {
          final bool selected = value == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: AnimationConstants.quickTransition.duration,
                curve: AnimationConstants.quickTransition.curve,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? text.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Widget görünüm ayarlarını SharedPreferences'tan yükle ---
  Future<void> _loadWidgetAppearance() async {
    try {
      final opacity = await WidgetBridgeService.getWidgetCardOpacity();
      final gradient = await WidgetBridgeService.getWidgetGradientEnabled();
      final radius = await WidgetBridgeService.getWidgetCardRadiusDp();
      final bgMode = await WidgetBridgeService.getWidgetBackgroundColorMode();
      final textMode = await WidgetBridgeService.getSmallWidgetTextColorMode();
      final textOnlyMode = await WidgetBridgeService.getTextOnlyWidgetTextColorMode();
      final textOnlyScale = await WidgetBridgeService.getTextOnlyWidgetTextScalePercent();
      final isTextPinned = await WidgetBridgeService.isTextWidgetPinned();
      if (!mounted) return;
      setState(() {
        _widgetOpacity = opacity;
        _gradientEnabled = gradient;
        _widgetRadius = radius;
        _bgColorMode = bgMode;
        _textColorMode = textMode;
        _textOnlyColorMode = textOnlyMode;
        _textOnlyScalePct = textOnlyScale;
        _isTextWidgetAdded = isTextPinned;
      });
    } catch (e) {
      // ignore
    }
  }

  void _updateSubpageSizeAnimation() {
    final bool isSubpageVisible = _isNotificationsVisible || _isWidgetSettingsVisible;
    if (_isExpanded && isSubpageVisible) {
      _subpageSizeController.forward();
    } else {
      _subpageSizeController.reverse();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _titleOpacityController.dispose();
    _toggleAnimationController.dispose();
    _subpageSizeController.dispose();
    // Güvenlik: bar kapanırken varsa önizlemeyi durdur
    NotificationSoundService.stopPreview();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isWidgetSettingsVisible) {
      _checkWidgetStatus();
      _loadWidgetAppearance();
    }
  }

  @override
  void didUpdateWidget(SettingsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sadece tema modu değiştiğinde toggle pozisyonunu güncelle
    if (oldWidget.themeMode != widget.themeMode) {
      _updateTogglePosition();
    }
  }

  void _updateTogglePosition() {
    final double targetPosition = switch (widget.themeMode) {
      AppThemeMode.light => 0.0,
      AppThemeMode.system => 0.5,
      AppThemeMode.dark => 1.0,
    };
    _toggleAnimationController.animateTo(targetPosition);
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _resetSubMenus();
        _animationController.forward();
        _titleOpacityController.forward();
      } else {
        _animationController.reverse();
        _titleOpacityController.reverse().then((_) {
          if (mounted && !_isExpanded) {
            setState(_resetSubMenus);
          }
        });
      }
    });
    _updateSubpageSizeAnimation();
    
    // Overlay callback'ini çağır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.onExpandedChanged != null) {
        widget.onExpandedChanged!(_isExpanded);
      }
    });
  }

  // Dışarıdan ayarlar barını kapatmak için public metod
  void closeSettings() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _animationController.reverse();
        _titleOpacityController.reverse().then((_) {
          if (mounted && !_isExpanded) {
            setState(_resetSubMenus);
          }
        });
      });
      
      // Overlay callback'ini çağır
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onExpandedChanged != null) {
          widget.onExpandedChanged!(false);
        }
      });
    }
  }

  void _resetSubMenus() {
    // Alt sayfaları kapatırken önizlemeyi durdur
    NotificationSoundService.stopPreview();
    _isColorPickerVisible = false;
    _isNotificationsVisible = false;
    _isWidgetSettingsVisible = false;
    _subpageSizeController.reverse();
  }

  void _showSubMenu(VoidCallback setVisibility) {
    setState(() {
      _resetSubMenus();
      setVisibility();
    });
    _updateSubpageSizeAnimation();
    // Alt sayfa açılınca başlık ve simge animasyonları güncellensin
    if (_isExpanded) {
      _titleOpacityController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _subpageSizeController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                const double minSize = 40.0;
                final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                final double desiredWidth = _widthAnimation.value + _subpageWidthAnimation.value;
                final double desiredHeight = _heightAnimation.value + _subpageHeightAnimation.value;
                final double maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
                final double maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity;
                final double width = isLandscape ? desiredWidth.clamp(minSize, maxWidth) : desiredWidth;
                final double height = isLandscape ? desiredHeight.clamp(minSize, maxHeight) : desiredHeight;

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (_) {
                    // Ekranın başka bir yerine dokunulduğunda önizlemeyi durdur
                    NotificationSoundService.stopPreview();
                  },
                  child: Container(
                    width: width,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: GlassBarConstants.blurSigma,
                          sigmaY: GlassBarConstants.blurSigma
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
                          child: Stack(
                            children: [
                              _buildMenuContent(),
                              _buildMenuIcon(),
                            ],
                          ),
                        ),
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

  Widget _buildMenuContent() {
    return AnimatedBuilder(
      animation: _titleOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _titleOpacityAnimation.value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * _titleOpacityAnimation.value),
            child: AnimatedSwitcher(
          duration: AnimationConstants.smoothTransition.duration,
              switchInCurve: AnimationConstants.smoothTransition.curve,
              switchOutCurve: AnimationConstants.smoothTransition.curve,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: AnimationConstants.smoothTransition.curve,
                    )),
                    child: child,
                  ),
                );
              },
              child: _getCurrentPage(),
            ),
          ),
        );
      },
    );
  }

  Widget _getCurrentPage() {
    if (_isColorPickerVisible) {
      return Container(
        key: const ValueKey('colorPicker'),
        child: _buildColorPicker(),
      );
    } else if (_isNotificationsVisible) {
      return Container(
        key: const ValueKey('notifications'),
        child: _buildNotificationsPage(),
      );
    } else if (_isWidgetSettingsVisible) {
      return Container(
        key: const ValueKey('widgetSettings'),
        child: _buildWidgetSettingsPage(),
      );
    } else {
      return Container(
        key: const ValueKey('mainMenu'),
        child: _buildMainMenu(),
      );
    }
  }

  Widget _buildMenuIcon() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final isExpanded = _isExpanded;
        final isMainMenu = !_isColorPickerVisible && !_isNotificationsVisible && !_isWidgetSettingsVisible;

        return AnimatedPositioned(
          duration: AnimationConstants.smoothTransition.duration,
          curve: AnimationConstants.smoothTransition.curve,
          top: isExpanded ? 29 : 6,
          right: isExpanded ? 20 : 6,
          child: AnimatedCrossFade(
            duration: AnimationConstants.smoothTransition.duration,
            firstCurve: AnimationConstants.smoothTransition.curve,
            secondCurve: AnimationConstants.smoothTransition.curve,
            sizeCurve: AnimationConstants.smoothTransition.curve,
            crossFadeState: isMainMenu ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: GestureDetector(
              key: const ValueKey(true),
              onTap: _toggleMenu,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _titleOpacityAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _titleOpacityAnimation.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Ayarlar',
                              style: TextStyle(
                                color: GlassBarConstants.getTextColor(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 7),
                          ],
                        ),
                      );
                    },
                  ),
                  Icon(
                    Symbols.menu,
                    color: GlassBarConstants.getTextColor(context),
                    size: 25,
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildMainMenu() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 70),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildMenuButton(
                        icon: Symbols.palette,
                        title: 'Tema Rengi',
                        onTap: () => _showSubMenu(() => _isColorPickerVisible = true),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuButton(
                        icon: Symbols.notifications,
                        title: 'Bildirimler',
                        onTap: () => _showSubMenu(() => _isNotificationsVisible = true),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuButton(
                        icon: Symbols.widgets,
                        title: 'Widget',
                        onTap: () => _showSubMenu(() {
                            _isWidgetSettingsVisible = true;
                            _checkWidgetStatus();
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Sol üstte tema toggle'ı
        Positioned(
          top: 25,
          left: 20,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _titleOpacityAnimation.value,
            child: _buildThemeToggle(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final surfaceColor = GlassBarConstants.getBackgroundColor(context);
    final borderColor = GlassBarConstants.getBorderColor(context);
    final textColor = GlassBarConstants.getTextColor(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: surfaceColor,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: GlassBarConstants.getBackgroundColor(context),
              ),
              child: Icon(
                icon,
                color: textColor.withOpacity(0.8),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Symbols.arrow_forward_ios,
              color: textColor.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = GlassBarConstants.getTextColor(context);
    
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                title: 'Tema Rengi',
                onBack: () => setState(() => _isColorPickerVisible = false),
              ),
              const SizedBox(height: 8),
              // Renk modu seçici: 3D silindir hissi veren yatay kaydırmalı carousel
              _buildColorModeCylinderSelector(textColor, isDark, theme, themeService),
              const SizedBox(height: 0),
              
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  child: themeService.themeColorMode == ThemeColorMode.static
                      ? _buildStaticColorList(themeService)
                      : themeService.themeColorMode == ThemeColorMode.dynamic
                          ? _buildDynamicColorInfo(textColor, isDark, theme, themeService)
                          : themeService.themeColorMode == ThemeColorMode.system
                              ? _buildSystemColorInfo(textColor, isDark, theme)
                              : _buildBlackColorInfo(textColor, isDark, theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _modeIndexOf(ThemeColorMode mode) {
    switch (mode) {
      case ThemeColorMode.static:
        return 0;
      case ThemeColorMode.dynamic:
        return 1;
      case ThemeColorMode.system:
        return 2;
      case ThemeColorMode.black:
        return 3;
      case ThemeColorMode.amoled:
        return 4;
    }
  }

  // kaldırıldı: _modeByIndex kullanılmıyor

  List<_ColorModeItem> get _colorModeItems => const [
    _ColorModeItem(icon: Symbols.palette, label: 'Sabit', mode: ThemeColorMode.static),
    _ColorModeItem(icon: Symbols.schedule, label: 'Dinamik', mode: ThemeColorMode.dynamic),
    _ColorModeItem(icon: Symbols.routine, label: 'Sistem', mode: ThemeColorMode.system),
    _ColorModeItem(icon: Symbols.dark_mode, label: 'Karanlık', mode: ThemeColorMode.black),
  ];

  Widget _buildColorModeCylinderSelector(
    Color textColor,
    bool isDark,
    ThemeData theme,
    ThemeService themeService,
  ) {
    final List<_ColorModeItem> items = _colorModeItems;
    final int selectedIndex = _modeIndexOf(themeService.themeColorMode).clamp(0, items.length - 1);

    return _ModeCylinderWidget(
      items: items,
      selectedIndex: selectedIndex,
      textColor: textColor,
      isDark: isDark,
      theme: theme,
      onSelectedChanged: (i) => themeService.setThemeColorMode(items[i].mode),
    );
  }

  // sınıf top-level'a taşındı

  Widget _buildNotificationsPage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = GlassBarConstants.getTextColor(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: 'Bildirimler',
            onBack: () {
              _closeAllPickers(); // Geri giderken picker'ları kapat
              setState(() {
                _isNotificationsVisible = false;
              });
              _updateSubpageSizeAnimation();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 0),
              physics: const BouncingScrollPhysics(),
              itemCount: _notificationSettings.length,
              itemBuilder: (context, index) {
                final setting = _notificationSettings[index];
                final bool isEnabled = setting.enabled;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildNotificationCard(
                    setting: setting,
                    isEnabled: isEnabled,
                    textColor: textColor,
                    isDark: isDark,
                    theme: theme,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // kaldırıldı: eski bar seçici

  // kaldırıldı: eski bar seçeneği render

  Widget _buildStaticColorList(ThemeService themeService) {
    return ListView.builder(
      key: const ValueKey('staticColors'),
      padding: EdgeInsets.zero,
      itemCount: SettingsConstants.themeColors.length,
      itemBuilder: (context, index) {
        final colorData = SettingsConstants.themeColors[index];
        final Color color = colorData.color;
        final bool isSelected = color == themeService.selectedThemeColor;
        
        return _buildColorOption(
          color: color,
          name: colorData.name,
          isSelected: isSelected,
          onTap: () => themeService.setSelectedThemeColor(color),
        );
      },
    );
  }

  Widget _buildDynamicColorInfo(Color textColor, bool isDark, ThemeData theme, ThemeService themeService) {
    return Container(
      key: const ValueKey('dynamicInfo'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.palette,
                  color: textColor.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dinamik Tema Rengi',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: Scrollbar(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Text(
                    'Tema rengi namaz vaktine göre dinamik olarak ayarlanacaktır. Her namaz vakti için farklı bir renk kullanılır.',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlackColorInfo(Color textColor, bool isDark, ThemeData theme) {
    return Container(
      key: const ValueKey('blackInfo'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: textColor.withOpacity(0.6)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Text(
                      'Tam siyah renk kullanılır. Oled ekranlarda pil tasarrufu sağlar.',
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.35,
                      ),
                      softWrap: true,
                    ),
                  ),
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemColorInfo(Color textColor, bool isDark, ThemeData theme) {
    return Container(
      key: const ValueKey('systemInfo'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.palette,
              color: textColor.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Text(
                      'Android 12 ve üzeri cihazlarda renkler duvar kâğıdına göre otomatik olarak ayarlanır.',
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.35,
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption({
    required Color color,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {

    final textColor = GlassBarConstants.getTextColor(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: GlassBarConstants.getBackgroundColor(context).withOpacity(isSelected ? 0.3 : 0.1),
            border: Border.all(
              color: GlassBarConstants.getBorderColor(context).withOpacity(isSelected ? 0.6 : 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: textColor),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Notification operations
  void _toggleNotificationSetting(String id) {
    final index = _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    final newEnabled = !_notificationSettings[index].enabled;
    setState(() {
      _notificationSettings[index] = _notificationSettings[index].copyWith(
        enabled: newEnabled,
      );
      // Tüm picker'ları kapatmadan önce önizlemeyi durdur
      NotificationSoundService.stopPreview();
      // Tüm picker'ları kapat
      _closeAllPickers();
    });
    // Toggle sonrası ayarı kalıcı olarak kaydet ve bildirimleri yeniden planla
    _persistAndReschedule(_notificationSettings[index]);
  }

  void _updateNotificationMinutes(String id, int minutes) {
    final index = _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    setState(() {
      _notificationSettings[index] = _notificationSettings[index].copyWith(
        minutes: minutes,
      );
    });
    _debouncedPersistAndReschedule(_notificationSettings[index]);
  }

  void _togglePickerVisibility(String id) {
    final index = _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    setState(() {
      final bool currentVisibility = _notificationSettings[index].pickerVisible;
      // Dakika seçimine geçerken ses önizlemesini durdur
      NotificationSoundService.stopPreview();
      // Önce tüm picker'ları kapat
      _closeAllPickers();
      // Eğer zaten açıksa kapat, kapalıysa aç
      _notificationSettings[index] = _notificationSettings[index].copyWith(
        pickerVisible: !currentVisibility,
      );
    });
  }

  void _closeAllPickers() {
    for (int i = 0; i < _notificationSettings.length; i++) {
      _notificationSettings[i] = _notificationSettings[i].copyWith(
        pickerVisible: false,
        soundPickerVisible: false,
      );
    }
  }

  void _toggleSoundPickerVisibility(String id) {
    final index = _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    setState(() {
      final bool currentVisibility = _notificationSettings[index].soundPickerVisible;
      // Kapatılıyorsa önizlemeyi durdur
      if (currentVisibility) {
        NotificationSoundService.stopPreview();
      }
      // Önce tüm picker'ları kapat
      _closeAllPickers();
      // Eğer zaten açıksa kapat, kapalıysa aç
      _notificationSettings[index] = _notificationSettings[index].copyWith(
        soundPickerVisible: !currentVisibility,
      );
    });
  }

  void _updateNotificationSound(String id, String soundId) {
    final index = _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    setState(() {
      _notificationSettings[index] = _notificationSettings[index].copyWith(
        sound: soundId,
      );
    });
    _persistAndReschedule(_notificationSettings[index]);
  }

  // --- Persist ve yeniden planlama ---
  Timer? _persistDebounce;

  void _debouncedPersistAndReschedule(notifsvc.NotificationSetting setting) {
    _persistDebounce?.cancel();
    final snapshot = setting;
    _persistDebounce = Timer(const Duration(milliseconds: 350), () {
      _persistAndReschedule(snapshot);
    });
  }

  Future<void> _persistAndReschedule(notifsvc.NotificationSetting setting) async {
    try {
      await notifsvc.NotificationSettingsService().updateSetting(setting.id, setting);
      await NotificationSchedulerService.instance.rescheduleTodayNotifications();
    } catch (e) {
      // ignore: persist error
    }
  }

  // Helper methods for notifications
  double _calculateControlsHeight(notifsvc.NotificationSetting setting) {
    double baseHeight = 97.0;
    
    if (setting.pickerVisible) {
      baseHeight += 57.0;
    }
    
    if (setting.soundPickerVisible) {
      baseHeight += 177.0;
    }
    
    return baseHeight;
  }

  Widget _buildNotificationCard({
    required notifsvc.NotificationSetting setting,
    required bool isEnabled,
    required Color textColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    final bool isDua = setting.id == 'dua';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: GlassBarConstants.getBackgroundColor(context).withOpacity(isEnabled ? 0.15 : 0.05),
        border: Border.all(
          color: GlassBarConstants.getBorderColor(context).withOpacity(isEnabled ? 0.6 : 0.3),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  setting.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _buildCustomSwitch(
                isEnabled: isEnabled,
                onToggle: () => _toggleNotificationSetting(setting.id),
              ),
            ],
          ),
          if (!isDua)
            AnimatedContainer(
              duration: AnimationConstants.quickTransition.duration,
              curve: AnimationConstants.quickTransition.curve,
              height: isEnabled ? _calculateControlsHeight(setting) : 0.0,
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: AnimationConstants.quickTransition.duration,
                  curve: AnimationConstants.quickTransition.curve,
                  opacity: isEnabled ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildNotificationControls(setting, textColor, isDark, theme),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationControls(notifsvc.NotificationSetting setting, Color textColor, bool isDark, ThemeData theme) {
    return Column(
      children: [
        // Dakika seçimi butonu ve çekmecesi
        _buildTimePicker(setting, textColor, isDark, theme),
        const SizedBox(height: 8),
        // Ses seçimi butonu ve çekmecesi
        _buildSoundSelector(setting, textColor, isDark, theme),
      ],
    );
  }

  Widget _buildTimePicker(notifsvc.NotificationSetting setting, Color textColor, bool isDark, ThemeData theme) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _togglePickerVisibility(setting.id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.15),
              border: Border.all(
                color: GlassBarConstants.getBorderColor(context).withOpacity(0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.schedule,
                  color: textColor.withOpacity(0.95),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    setting.minutes == 0 
                        ? 'Tam zamanında'
                        : '${setting.minutes} dakika önce',
                    style: TextStyle(
                      color: textColor.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: setting.pickerVisible ? 0.5 : 0.0,
                        child: Icon(
                    Symbols.keyboard_arrow_down,
                    color: textColor.withOpacity(0.95),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          height: setting.pickerVisible ? 48.0 : 0.0,
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildMinutePicker(
                id: setting.id,
                currentMinutes: setting.minutes,
                textColor: textColor,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSelector(notifsvc.NotificationSetting setting, Color textColor, bool isDark, ThemeData theme) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _toggleSoundPickerVisibility(setting.id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.15),
              border: Border.all(
                color: GlassBarConstants.getBorderColor(context).withOpacity(0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  SettingsConstants.soundOptions.firstWhere((sound) => sound.id == setting.sound).icon,
                  color: textColor.withOpacity(0.95),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SettingsConstants.soundOptions.firstWhere((sound) => sound.id == setting.sound).name,
                    style: TextStyle(
                      color: textColor.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: setting.soundPickerVisible ? 0.5 : 0.0,
                  child: Icon(
                    Symbols.keyboard_arrow_down,
                    color: textColor.withOpacity(0.95),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: AnimationConstants.containerTransition.duration,
          curve: AnimationConstants.containerTransition.curve,
          height: setting.soundPickerVisible ? 168.0 : 0.0,
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildSoundPicker(
                id: setting.id,
                currentSoundId: setting.sound,
                textColor: textColor,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinutePicker({
    required String id,
    required int currentMinutes,
    required Color textColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    return RepaintBoundary(
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
        ),
        child: _MinutePickerWidget(
          id: id,
          currentMinutes: currentMinutes,
          textColor: textColor,
          onMinuteChanged: _updateNotificationMinutes,
        ),
      ),
    );
  }

  Widget _buildSoundPicker({
    required String id,
    required String currentSoundId,
    required Color textColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    const double itemHeight = 36.0;
    const double padding = 16.0;
    const double maxHeight = 160.0;
    final double calculatedHeight = (SettingsConstants.soundOptions.length * itemHeight) + padding;
    final double optimalHeight = calculatedHeight.clamp(100.0, maxHeight);
    
    return Container(
      height: optimalHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.15),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        physics: const ClampingScrollPhysics(),
        itemCount: SettingsConstants.soundOptions.length,
        itemBuilder: (context, index) => _buildSoundOption(
          sound: SettingsConstants.soundOptions[index],
          currentSoundId: currentSoundId,
          textColor: textColor,
          theme: theme,
          onTap: () {
            _updateNotificationSound(id, SettingsConstants.soundOptions[index].id);
          },
        ),
      ),
    );
  }

  Widget _buildSoundOption({
    required SoundOptionData sound,
    required String currentSoundId,
    required Color textColor,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final bool isSelected = sound.id == currentSoundId;
    
    return GestureDetector(
      onTap: () {
        // Seçilen sesi önizle ve ayarı güncelle
        NotificationSoundService.previewSound(sound.id);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 32,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.15)
              : const Color.fromARGB(129, 0, 0, 0),
        ),
        child: Row(
          children: [
            Icon(
              sound.icon,
              color: isSelected 
                  ? theme.colorScheme.primary
                  : textColor.withOpacity(0.7),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sound.name,
                style: TextStyle(
                  color: isSelected 
                      ? theme.colorScheme.primary
                      : textColor.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(
                Symbols.check_circle,
                color: theme.colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  // not used currently

  Widget _buildCustomSwitch({required bool isEnabled, required VoidCallback onToggle}) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onPrimary;
    
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: isEnabled 
              ? theme.colorScheme.primary
              : textColor.withOpacity(0.3),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader({required String title, required VoidCallback onBack}) {
    final textColor = GlassBarConstants.getTextColor(context);
    
    return AnimatedSwitcher(
      duration: AnimationConstants.smoothTransition.duration,
      switchInCurve: AnimationConstants.smoothTransition.curve,
      switchOutCurve: AnimationConstants.smoothTransition.curve,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.smoothTransition.curve,
            )),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey(title),
        children: [
          GestureDetector(
            onTap: onBack,
            child: SizedBox(
              width: 35,
              height: 35,
              child: Icon(
                Symbols.arrow_back_ios,
                color: textColor,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = GlassBarConstants.getBackgroundColor(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: surfaceColor,
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _toggleSlideAnimation,
            builder: (context, child) {
              final indicatorColor = isDark 
                  ? theme.colorScheme.primary.withOpacity(0.4)
                  : Colors.white.withOpacity(0.25);
              return Positioned(
                // Toggle pozisyonu (animation non-null olmalı çünkü initState içinde başlatılıyor)
                left: _toggleSlideAnimation.value * 61,
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: indicatorColor,
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                icon: Symbols.light_mode,
                mode: AppThemeMode.light,
                isSelected: widget.themeMode == AppThemeMode.light,
              ),
              const SizedBox(width: 2),
              _buildThemeOption(
                icon: Symbols.routine,
                mode: AppThemeMode.system,
                isSelected: widget.themeMode == AppThemeMode.system,
              ),
              const SizedBox(width: 2),
              _buildThemeOption(
                icon: Symbols.dark_mode,
                mode: AppThemeMode.dark,
                isSelected: widget.themeMode == AppThemeMode.dark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required AppThemeMode mode,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: _isExpanded ? () => widget.onThemeChanged(mode) : null,
      child: Container(
        width: 29,
        height: 29,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          color: GlassBarConstants.getTextColor(context).withOpacity(isSelected ? 1.0 : 0.7),
          size: 16,
        ),
      ),
    );
  }

  Widget _buildWidgetSettingsPage() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: 'Widget Ayarları',
            onBack: () {
                setState(() {
                   _isWidgetSettingsVisible = false;
                });
                _updateSubpageSizeAnimation();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmallWidgetCard(context),
                  const SizedBox(height: 12),
                  _buildTextOnlyWidgetCard(context),
                  // You can add more widget settings here if needed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallWidgetCard(BuildContext context) {
    final textColor = GlassBarConstants.getTextColor(context);
    if (!_isWidgetAdded) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Küçük Widget',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(2),
                backgroundColor: GlassBarConstants.getBackgroundColor(context).withOpacity(0.2),
                minimumSize: const Size(34, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                try {
                  await WidgetBridgeService.requestPinSmallWidget();
                  // 2 saniye sonra kontrol et; bazı launcherdlar OS sheet gösterir
                  await Future.delayed(const Duration(seconds: 2));
                  final status = await WidgetBridgeService.isSmallWidgetPinned();
                  if (mounted) {
                    setState(() {
                      _isWidgetAdded = status;
                      _isSmallWidgetExpanded = status;
                    });
                  }
                } catch (e) {
                  debugPrint('Widget pin error: $e');
                }
              },
              child: Icon(Symbols.add, size: 16, color: GlassBarConstants.getTextColor(context)),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSmallWidgetExpanded = !_isSmallWidgetExpanded;
        });
      },
      child: AnimatedContainer(
        duration: AnimationConstants.quickTransition.duration,
        curve: AnimationConstants.quickTransition.curve,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and arrow icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Küçük Widget',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Değişiklik: widget eklendiyse ok ikonu göster
                AnimatedRotation(
                  turns: _isSmallWidgetExpanded ? 0.75 : 0.25,
                  duration: AnimationConstants.quickTransition.duration,
                  child: Icon(
                    Symbols.arrow_forward_ios_rounded,
                    color: textColor,
                    size: 16,
                  ),
                ),
              ],
            ),
            // Animated expansion for card content using notifications card style
            AnimatedContainer(
              duration: AnimationConstants.quickTransition.duration,
              curve: AnimationConstants.quickTransition.curve,
              height: _isSmallWidgetExpanded ? 220.0 : 0.0,
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: AnimationConstants.quickTransition.duration,
                  curve: AnimationConstants.quickTransition.curve,
                  opacity: _isSmallWidgetExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          'Arka Plan Opaklığı',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        _DebouncedSlider(
                          value: _widgetOpacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          labelBuilder: (v) => v.toStringAsFixed(1),
                          onChangedImmediate: (v) {
                            setState(() { _widgetOpacity = v; });
                          },
                          onDebouncedChangeEnd: (v) async {
                            try {
                              await WidgetBridgeService.setWidgetCardOpacity(v);
                              await WidgetBridgeService.forceUpdateSmallWidget();
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Widget Gradient',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _buildCustomSwitch(
                              isEnabled: _gradientEnabled,
                              onToggle: () async {
                                setState(() {
                                  _gradientEnabled = !_gradientEnabled;
                                });
                                try {
                                  await WidgetBridgeService.setWidgetGradientEnabled(_gradientEnabled);
                                  await WidgetBridgeService.forceUpdateSmallWidget();
                                } catch (e) {
                                  // Hata yönetimi
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Köşe Yarıçapı',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        _DebouncedSlider(
                          value: _widgetRadius.toDouble(),
                          min: 0,
                          max: 120,
                          divisions: 120,
                          labelBuilder: (v) => v.round().toString(),
                          onChangedImmediate: (v) {
                            setState(() { _widgetRadius = v.round(); });
                          },
                          onDebouncedChangeEnd: (v) async {
                            try {
                              await WidgetBridgeService.setWidgetCardRadiusDp(v.round());
                              await WidgetBridgeService.forceUpdateSmallWidget();
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Arka Plan Rengi',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildTriToggle(
                          value: _bgColorMode,
                          labels: const ['Sistem', 'Açık', 'Koyu'],
                          onChanged: (mode) async {
                            setState(() { _bgColorMode = mode; });
                            await WidgetBridgeService.setWidgetBackgroundColorMode(mode);
                            await WidgetBridgeService.forceUpdateSmallWidget();
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'İçerik Metin Rengi',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildTriToggle(
                          value: _textColorMode,
                          labels: const ['Sistem', 'Koyu', 'Açık'],
                          onChanged: (mode) async {
                            setState(() { _textColorMode = mode; });
                            await WidgetBridgeService.setSmallWidgetTextColorMode(mode);
                            await WidgetBridgeService.forceUpdateSmallWidget();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOnlyWidgetCard(BuildContext context) {
    final textColor = GlassBarConstants.getTextColor(context);
    if (!_isTextWidgetAdded) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Metin Widget',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(2),
                backgroundColor: GlassBarConstants.getBackgroundColor(context).withOpacity(0.2),
                minimumSize: const Size(34, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                try {
                  await WidgetBridgeService.requestPinTextWidget();
                  await Future.delayed(const Duration(seconds: 2));
                  final status = await WidgetBridgeService.isTextWidgetPinned();
                  if (mounted) {
                    setState(() { 
                      _isTextWidgetAdded = status; 
                      _isTextWidgetExpanded = status;
                    });
                  }
                } catch (_) {}
              },
              child: Icon(Symbols.add, size: 16, color: GlassBarConstants.getTextColor(context)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() { _isTextWidgetExpanded = !_isTextWidgetExpanded; });
      },
      child: AnimatedContainer(
        duration: AnimationConstants.quickTransition.duration,
        curve: AnimationConstants.quickTransition.curve,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: GlassBarConstants.getBackgroundColor(context),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metin Widgetı',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AnimatedRotation(
                  turns: _isTextWidgetExpanded ? 0.75 : 0.25,
                  duration: AnimationConstants.quickTransition.duration,
                  child: Icon(
                    Symbols.arrow_forward_ios_rounded,
                    color: textColor,
                    size: 16,
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: AnimationConstants.quickTransition.duration,
              curve: AnimationConstants.quickTransition.curve,
              height: _isTextWidgetExpanded ? 160.0 : 0.0,
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: AnimationConstants.quickTransition.duration,
                  curve: AnimationConstants.quickTransition.curve,
                  opacity: _isTextWidgetExpanded ? 1.0 : 0.0,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Metin Boyutu',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        _DebouncedSlider(
                          value: _textOnlyScalePct.toDouble(),
                          min: 80,
                          max: 140,
                          divisions: 60,
                          labelBuilder: (v) => '${v.round()}%',
                          onChangedImmediate: (v) {
                            setState(() { _textOnlyScalePct = v.round(); });
                          },
                          onDebouncedChangeEnd: (v) async {
                            try {
                              await WidgetBridgeService.setTextOnlyWidgetTextScalePercent(v.round());
                              await WidgetBridgeService.forceUpdateSmallWidget();
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Metin Rengi',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildTriToggle(
                          value: _textOnlyColorMode,
                          labels: const ['Sistem', 'Koyu', 'Açık'],
                          onChanged: (mode) async {
                            setState(() { _textOnlyColorMode = mode; });
                            await WidgetBridgeService.setTextOnlyWidgetTextColorMode(mode);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

class _DebouncedSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) labelBuilder;
  final ValueChanged<double> onChangedImmediate;
  final ValueChanged<double> onDebouncedChangeEnd;

  const _DebouncedSlider({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.labelBuilder,
    required this.onChangedImmediate,
    required this.onDebouncedChangeEnd,
  });

  @override
  State<_DebouncedSlider> createState() => _DebouncedSliderState();
}

class _DebouncedSliderState extends State<_DebouncedSlider> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.labelBuilder(widget.value),
      onChanged: (v) {
        widget.onChangedImmediate(v);
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 200), () {
          widget.onDebouncedChangeEnd(v);
        });
      },
      onChangeEnd: (v) {
        _debounce?.cancel();
        widget.onDebouncedChangeEnd(v);
      },
    );
  }

}
