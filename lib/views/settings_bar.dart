import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import 'dart:async';
import '../services/notification_scheduler_service.dart';
import '../services/notification_settings_service.dart' as notifsvc;
import '../services/notification_sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../viewmodels/settings_viewmodel.dart';

// Ses seçim listesindeki zorlamalarda ana scroll'u germemek için hafifletilmiş davranış
class _GentleOverscrollBehavior extends ScrollBehavior {
  const _GentleOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Glow/stretch yerine sakin bir deneyim
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

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
  static const double _radius = 65.0;
  static const double _itemAngle = 2 * math.pi / 4;
  static const double _perspective = 0.010;
  static const double _dragSensitivity = 0.016;
  static const Duration _snapDuration = Duration(milliseconds: 220);

  late int _currentIndex;
  late AnimationController _controller;
  double _totalRotation = 0.0;
  bool _isDragging = false;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  double get _maxRotation =>
      math.max(widget.items.length * _itemAngle, _itemAngle);

  double _wrapRotation(double value) {
    final double max = _maxRotation;
    if (max == 0) return 0;
    double wrapped = value % max;
    if (wrapped < 0) wrapped += max;
    return wrapped;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex.clamp(0, widget.items.length - 1);
    _totalRotation = _currentIndex * _itemAngle;
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: _maxRotation,
      value: _totalRotation,
    )
      ..addListener(_handleAnimationUpdate)
      ..addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationUpdate() {
    if (!mounted) return;
    _totalRotation = _wrapRotation(_controller.value);
    _updateCurrentIndex();
    setState(() {});
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      final double wrapped = _wrapRotation(_controller.value);
      if ((_controller.value - wrapped).abs() > 1e-6) {
        _controller.value = wrapped;
      }
      _totalRotation = wrapped;
      _triggerSelectionFeedback();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateCurrentIndex() {
    if (widget.items.isEmpty) return;
    final double normalized = _totalRotation / _itemAngle;
    final int newIndex = (normalized.round()) % widget.items.length;
    final int positiveIndex = newIndex < 0 ? newIndex + widget.items.length : newIndex;
    if (positiveIndex != _currentIndex) {
      _currentIndex = positiveIndex;
      widget.onSelectedChanged(_currentIndex);
    }
  }

  void _triggerSelectionFeedback() {
    if (_isIOS) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _snapToNearestPosition() {
    if (widget.items.isEmpty) return;
    final double normalized = _totalRotation / _itemAngle;
    final int targetStep = normalized.round() % widget.items.length;
    _animateToStep(targetStep);
  }

  void _animateToStep(int step) {
    if (!mounted || widget.items.isEmpty) return;
    final int wrappedStep = (step % widget.items.length + widget.items.length) % widget.items.length;
    final double targetRotation = wrappedStep * _itemAngle;
    _animateToRotation(targetRotation);
  }

  void _animateToRotation(double targetRotation) {
    double adjustedTarget = _wrapRotation(targetRotation);
    final double current = _controller.value;
    final double halfRange = _maxRotation / 2;
    double delta = adjustedTarget - current;
    if (delta.abs() > halfRange) {
      if (delta > 0) {
        adjustedTarget -= _maxRotation;
      } else {
        adjustedTarget += _maxRotation;
      }
    }
    _controller.animateTo(
      adjustedTarget.clamp(0.0, _maxRotation),
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

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
            dragStartBehavior: DragStartBehavior.down,
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _controller.stop();
              _isDragging = true;
            },
            onHorizontalDragUpdate: (details) {
              if (!_isDragging) return;
              final double primaryDelta = details.primaryDelta ?? details.delta.dx;
              _totalRotation = _wrapRotation(_totalRotation - primaryDelta * _dragSensitivity);
              _controller.value = _totalRotation;
              _updateCurrentIndex();
            },
            onHorizontalDragEnd: (_) {
              _isDragging = false;
              _snapToNearestPosition();
            },
            onHorizontalDragCancel: () {
              _isDragging = false;
              _snapToNearestPosition();
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double currentRotation = _totalRotation;
                final indices = List<int>.generate(items.length, (i) => i);
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
                    final double opacity = depthScale < 0.3 ? 0.0 : (0.2 + 0.8 * depthScale);
                    final double scale = 0.7 + 0.3 * depthScale;
                    final double yOffset = (1.0 - depthScale) * 15.0;

                    final item = items[i];
                    final bool isSelected = i == _currentIndex;

                    return Positioned(
                      left: w / 2 + x - 40,
                      top: 15 + yOffset,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, _perspective)
                            ..rotateY(-normalizedAngle * 0.6),
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
  late final List<int> _minutes;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    final List<int> baseList = List<int>.from(SettingsConstants.notificationMinutes);
    final bool isFridayNotification = widget.id == 'cuma';
    List<int> resolved = isFridayNotification
        ? baseList.where((minute) => minute >= 15).toList()
        : baseList;

    if (resolved.isEmpty) {
      resolved = <int>[isFridayNotification ? 15 : 0];
    }

    _minutes = resolved;

    int initialValue = widget.currentMinutes;
    if (!_minutes.contains(initialValue)) {
      initialValue = _nearestAvailableMinute(initialValue);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMinuteChanged(widget.id, initialValue);
      });
    }

    _currentIndex = _minutes.indexOf(initialValue);
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

  int _nearestAvailableMinute(int value) {
    if (_minutes.isEmpty) return value;
    int best = _minutes.first;
    int bestDiff = (value - best).abs();
    for (final minute in _minutes) {
      final int diff = (value - minute).abs();
      if (diff < bestDiff || (diff == bestDiff && minute < best)) {
        best = minute;
        bestDiff = diff;
      }
    }
    return best;
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
      const double dragMultiplier = 1.35;
      final double primaryDelta = details.primaryDelta ?? details.delta.dx;
      setState(() {
        _wheelOffset -= primaryDelta * dragMultiplier;
      });
      _checkValueChange();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    
    if (velocity.abs() > 190) {
      _startMomentumScroll(velocity);
    } else {
      _snapToNearestValue();
    }
  }

  void _startMomentumScroll(double velocity) {
    final double currentOffset = _wheelOffset;
    final double momentumDistance = -velocity * 0.18;
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
    if (_minutes.isEmpty) return;
    final double normalizedOffset = _wheelOffset / SettingsConstants.pickerLineSpacing;
    final int rawIndex = normalizedOffset.round();
    final int nearestIndex = rawIndex % _minutes.length;
    final int positiveIndex = nearestIndex < 0 ? nearestIndex + _minutes.length : nearestIndex;
    
    if (positiveIndex != _currentIndex) {
      _currentIndex = positiveIndex;
      
      if (mounted) {
        if (!_valueChangeController.isAnimating) {
          _valueChangeController.reset();
          _valueChangeController.forward();
        }
        
        if (_currentIndex >= 0 && _currentIndex < _minutes.length) {
          widget.onMinuteChanged(widget.id, _minutes[_currentIndex]);
        }
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
    if (_minutes.isEmpty) return;
    final int newIndex = (_currentIndex + steps) % _minutes.length;
    final int positiveIndex = newIndex < 0 ? newIndex + _minutes.length : newIndex;
    
    if (positiveIndex != _currentIndex && mounted) {
      setState(() {
        _currentIndex = positiveIndex;
        final double currentNormalized = _wheelOffset / SettingsConstants.pickerLineSpacing;
        final double targetNormalized = currentNormalized.roundToDouble() + steps;
        _wheelOffset = targetNormalized * SettingsConstants.pickerLineSpacing;
      });
      
      _valueChangeController.reset();
      _valueChangeController.forward();
      
      if (_currentIndex >= 0 && _currentIndex < _minutes.length) {
        widget.onMinuteChanged(widget.id, _minutes[_currentIndex]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    
    return RepaintBoundary(
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _handlePanStart,
        onHorizontalDragUpdate: _handlePanUpdate,
        onHorizontalDragEnd: _handlePanEnd,
        onHorizontalDragCancel: () {
          _momentumController.stop();
          _snapToNearestValue();
        },
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
  final ValueChanged<bool>? onDrawerDragLockChanged;
  final bool isDrawerMode;

  const SettingsBar({
    Key? key,
    this.onSettingsPressed,
    required this.themeMode,
    required this.onThemeChanged,
    this.onExpandedChanged,
    this.onDrawerDragLockChanged,
    this.isDrawerMode = true,
  }) : super(key: key);

  @override
  State<SettingsBar> createState() => SettingsBarState();
}

class SettingsBarState extends State<SettingsBar> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isColorPickerVisible = false;
  bool _isNotificationsVisible = false;
  bool _isLanguageSelectorVisible = false;
  bool _lastDrawerLockState = false;

  bool get _isDrawerSubpageActive =>
      _isColorPickerVisible || _isNotificationsVisible || _isLanguageSelectorVisible;

  late final ScrollController _soundPickerController;

  void _notifyDrawerGestureLock({bool force = false}) {
    if (!widget.isDrawerMode || widget.onDrawerDragLockChanged == null) return;
    final bool isLocked = _isDrawerSubpageActive;
    if (force || isLocked != _lastDrawerLockState) {
      _lastDrawerLockState = isLocked;
      widget.onDrawerDragLockChanged!(isLocked);
    }
  }


  // Bildirim ayarları (NotificationSettingsService üzerinden yüklenir)
  List<notifsvc.NotificationSetting> _notificationSettings = [];

  late final AnimationController _toggleAnimationController;
  late final Animation<double> _toggleSlideAnimation;

  // Theme color mode cylinder selector state handled by dedicated widget

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soundPickerController = ScrollController();
    _initializeNotificationSettings();
    _initializeToggleAnimation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyDrawerGestureLock(force: true);
      }
    });
  }


  
  void _initializeNotificationSettings() async {
    try {
      final svc = notifsvc.NotificationSettingsService();
      if (!svc.isLoaded) {
        await svc.loadSettings();
      }
      
      // Service'ten ayarları al
      final settings = svc.settings;
      
      // Eğer ayarlar boşsa, varsayılan ayarları kullan
      if (settings.isEmpty) {
        if (mounted) {
          final localizations = AppLocalizations.of(context)!;
          setState(() {
            _notificationSettings = [
              notifsvc.NotificationSetting(id: 'imsak', title: localizations.imsak, enabled: false, minutes: 0, sound: 'bird'),
              notifsvc.NotificationSetting(id: 'gunes', title: localizations.gunes, enabled: false, minutes: 0, sound: 'bird'),
              notifsvc.NotificationSetting(id: 'ogle', title: localizations.ogle, enabled: true, minutes: 10, sound: 'default'),
              notifsvc.NotificationSetting(id: 'ikindi', title: localizations.ikindi, enabled: true, minutes: 10, sound: 'default'),
              notifsvc.NotificationSetting(id: 'aksam', title: localizations.aksam, enabled: true, minutes: 10, sound: 'default'),
              notifsvc.NotificationSetting(id: 'yatsi', title: localizations.yatsi, enabled: true, minutes: 10, sound: 'default'),
              notifsvc.NotificationSetting(id: 'cuma', title: localizations.cuma, enabled: true, minutes: 45, sound: 'alarm'),
              notifsvc.NotificationSetting(id: 'dua', title: localizations.duaNotification, enabled: true, minutes: 0),
            ];
          });
        }
        return;
      }
      
      if (mounted) {
        // Service'ten gelen title'ları çevir
        final localizations = AppLocalizations.of(context)!;
        setState(() {
          _notificationSettings = settings.map((setting) {
            // ID'ye göre çevrilmiş title'ı al
            String localizedTitle;
            switch (setting.id) {
              case 'imsak':
                localizedTitle = localizations.imsak;
                break;
              case 'gunes':
                localizedTitle = localizations.gunes;
                break;
              case 'ogle':
                localizedTitle = localizations.ogle;
                break;
              case 'ikindi':
                localizedTitle = localizations.ikindi;
                break;
              case 'aksam':
                localizedTitle = localizations.aksam;
                break;
              case 'yatsi':
                localizedTitle = localizations.yatsi;
                break;
              case 'cuma':
                localizedTitle = localizations.cuma;
                break;
              case 'dua':
                localizedTitle = localizations.duaNotification;
                break;
              default:
                // Ek bildirimler için (imsak_1, imsak_2, vb.) base ID'yi al
                final baseId = setting.id.split('_').first;
                switch (baseId) {
                  case 'imsak':
                    localizedTitle = localizations.imsak;
                    break;
                  case 'gunes':
                    localizedTitle = localizations.gunes;
                    break;
                  case 'ogle':
                    localizedTitle = localizations.ogle;
                    break;
                  case 'ikindi':
                    localizedTitle = localizations.ikindi;
                    break;
                  case 'aksam':
                    localizedTitle = localizations.aksam;
                    break;
                  case 'yatsi':
                    localizedTitle = localizations.yatsi;
                    break;
                  case 'cuma':
                    localizedTitle = localizations.cuma;
                    break;
                  default:
                    localizedTitle = setting.title; // Fallback
                }
            }
            return setting.copyWith(title: localizedTitle);
          }).toList();
        });
      }
    } catch (_) {
      // Hata durumunda varsayılan ayarları kullan
      if (mounted) {
        // Varsayılan ayarları context ile çevirilmiş isimlerle oluştur
        final localizations = AppLocalizations.of(context)!;
        setState(() {
          _notificationSettings = [
            notifsvc.NotificationSetting(id: 'imsak', title: localizations.imsak, enabled: false, minutes: 0, sound: 'bird'),
            notifsvc.NotificationSetting(id: 'gunes', title: localizations.gunes, enabled: false, minutes: 0, sound: 'bird'),
            notifsvc.NotificationSetting(id: 'ogle', title: localizations.ogle, enabled: true, minutes: 10, sound: 'default'),
            notifsvc.NotificationSetting(id: 'ikindi', title: localizations.ikindi, enabled: true, minutes: 10, sound: 'default'),
            notifsvc.NotificationSetting(id: 'aksam', title: localizations.aksam, enabled: true, minutes: 10, sound: 'default'),
            notifsvc.NotificationSetting(id: 'yatsi', title: localizations.yatsi, enabled: true, minutes: 10, sound: 'default'),
            notifsvc.NotificationSetting(id: 'cuma', title: localizations.cuma, enabled: true, minutes: 45, sound: 'alarm'),
            notifsvc.NotificationSetting(id: 'dua', title: localizations.duaNotification, enabled: true, minutes: 0),
          ];
        });
      }
    }
  }

  void _initializeToggleAnimation() {
    _toggleAnimationController = AnimationController(
      duration: AnimationConstants.smoothTransition.duration,
      vsync: this,
      value: _themeModeToToggleValue(widget.themeMode),
    );

    _toggleSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toggleAnimationController, 
      curve: AnimationConstants.smoothTransition.curve,
    ));
  }



  void _updateSubpageSizeAnimation() {
    _notifyDrawerGestureLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toggleAnimationController.dispose();
    _soundPickerController.dispose();
    // Güvenlik: bar kapanırken varsa önizlemeyi durdur
    NotificationSoundService.stopPreview();
    super.dispose();
  }



  @override
  void didUpdateWidget(SettingsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sadece tema modu değiştiğinde toggle pozisyonunu güncelle
    if (oldWidget.themeMode != widget.themeMode) {
      _updateTogglePosition();
    }
  }

  double _themeModeToToggleValue(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 0.0;
      case AppThemeMode.system:
        return 0.5;
      case AppThemeMode.dark:
        return 1.0;
    }
  }

  void _updateTogglePosition() {
    _toggleAnimationController.animateTo(
      _themeModeToToggleValue(widget.themeMode),
    );
  }

  // Dışarıdan ayarlar barını kapatmak için public metod
  void closeSettings() {
    setState(_resetSubMenus);
    _notifyDrawerGestureLock(force: true);
  }

  void _resetSubMenus() {
    // Alt sayfaları kapatırken önizlemeyi durdur
    NotificationSoundService.stopPreview();
    _isColorPickerVisible = false;
    _isNotificationsVisible = false;
    _isLanguageSelectorVisible = false;
  }

  void _showSubMenu(VoidCallback setVisibility) {
    setState(() {
      _resetSubMenus();
      setVisibility();
    });
    _updateSubpageSizeAnimation();
    
    // Bildirimler sayfası açıldığında ayarları yüklemeyi garantile
    if (_isNotificationsVisible && _notificationSettings.isEmpty) {
      _initializeNotificationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        // Ekranın başka bir yerine dokunulduğunda önizlemeyi durdur
        NotificationSoundService.stopPreview();
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: _buildMenuContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _getCurrentPage(),
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
    } else if (_isLanguageSelectorVisible) {
      return Container(
        key: const ValueKey('languageSelector'),
        child: _buildLanguagePage(),
      );
    } else {
      return Container(
        key: const ValueKey('mainMenu'),
        child: _buildMainMenu(),
      );
    }
  }


  Widget _buildMainMenu() {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThemeToggle(),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Symbols.palette_rounded,
                  title: AppLocalizations.of(context)!.themeColor,
                  onTap: () => _showSubMenu(() => _isColorPickerVisible = true),
                ),
                const SizedBox(height: 12),
                _buildMenuButton(
                  icon: Symbols.notifications_rounded,
                  title: AppLocalizations.of(context)!.notifications,
                  onTap: () => _showSubMenu(() => _isNotificationsVisible = true),
                ),
                const SizedBox(height: 12),
                _buildMenuButton(
                  icon: Symbols.language_rounded,
                  title: AppLocalizations.of(context)!.language,
                  onTap: () => _showSubMenu(() => _isLanguageSelectorVisible = true),
                ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          top: 18,
          end: 12,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              width: 45,
              height: 33,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Symbols.menu_rounded,
                color: GlassBarConstants.getTextColor(context),
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagePage() {
    final surfaceColor = GlassBarConstants.getBackgroundColor(context);
    final borderColor = GlassBarConstants.getBorderColor(context);
    
    // Drawer modunda dinamik boyut
    if (widget.isDrawerMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst alan - kapatma butonu ile aynı yükseklikte
          const SizedBox(height: 18),
          // Başlık - sabit (scroll edilmez)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
            child: _buildPageHeader(
              title: AppLocalizations.of(context)!.language,
              onBack: () {
                setState(() => _isLanguageSelectorVisible = false);
                _updateSubpageSizeAnimation();
                _notifyDrawerGestureLock();
              },
            ),
          ),
          const SizedBox(height: 16),
          // Scroll edilebilir içerik
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 5),
                child: Consumer<LocaleService>(
                  builder: (context, localeService, child) {
                    final currentLocale = localeService.currentLocale;
                    
                    return Column(
                      children: LocaleService.supportedLocales.map((Locale locale) {
                        final isSelected = locale == currentLocale;
                        final languageName = LocaleService.getLanguageName(locale);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              localeService.setLocale(locale);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: surfaceColor.withOpacity(isSelected ? 0.15 : 0.05),
                                border: Border.all(
                                  color: borderColor.withOpacity(isSelected ? 0.6 : 0.3),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                textDirection: TextDirection.ltr, // Dil adı her zaman LTR
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: surfaceColor.withOpacity(0.1),
                                    ),
                                    child: Icon(
                                      Symbols.language_rounded,
                                      color: GlassBarConstants.getTextColor(context).withOpacity(0.8),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      languageName,
                                      style: TextStyle(
                                        color: GlassBarConstants.getTextColor(context),
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      textDirection: TextDirection.ltr, // Dil adı her zaman LTR
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Symbols.check_rounded,
                                      color: GlassBarConstants.getTextColor(context),
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Normal bar modu
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: AppLocalizations.of(context)!.language,
            onBack: () {
              setState(() => _isLanguageSelectorVisible = false);
              _updateSubpageSizeAnimation();
              _notifyDrawerGestureLock();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer<LocaleService>(
              builder: (context, localeService, child) {
                final currentLocale = localeService.currentLocale;
                
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: LocaleService.supportedLocales.length,
                  itemBuilder: (context, index) {
                    final locale = LocaleService.supportedLocales[index];
                    final isSelected = locale == currentLocale;
                    final languageName = LocaleService.getLanguageName(locale);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          localeService.setLocale(locale);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: surfaceColor.withOpacity(isSelected ? 0.15 : 0.05),
                            border: Border.all(
                              color: borderColor.withOpacity(isSelected ? 0.6 : 0.3),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            textDirection: TextDirection.ltr, // Dil adı her zaman LTR
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: surfaceColor.withOpacity(0.1),
                                ),
                                child: Icon(
                                  Symbols.language_rounded,
                                  color: GlassBarConstants.getTextColor(context).withOpacity(0.8),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  languageName,
                                  style: TextStyle(
                                    color: GlassBarConstants.getTextColor(context),
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                  textDirection: TextDirection.ltr, // Dil adı her zaman LTR
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Symbols.check_rounded,
                                  color: GlassBarConstants.getTextColor(context),
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
          textDirection: Directionality.of(context) == TextDirection.rtl 
              ? TextDirection.rtl 
              : TextDirection.ltr,
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
              Symbols.arrow_forward_ios_rounded,
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
    
    return Consumer2<ThemeService, SettingsViewModel>(
      builder: (context, themeService, settingsVm, child) {
        // Drawer modunda dinamik boyut
        if (widget.isDrawerMode) {
          return Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst alan - kapatma butonu ile aynı yükseklikte
                  const SizedBox(height: 18),
                  // Başlık - sabit (scroll edilmez)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
                    child: _buildPageHeader(
                      title: AppLocalizations.of(context)!.themeColor,
                      onBack: () {
                        setState(() => _isColorPickerVisible = false);
                        _updateSubpageSizeAnimation();
                        _notifyDrawerGestureLock();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
              // Scroll edilebilir içerik
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildColorModeCylinderSelector(textColor, isDark, theme, themeService),
                        const SizedBox(height: 10),
                        _buildColorModeContent(themeService, textColor, isDark, theme),
                      ],
                    ),
                  ),
                ),
              ),
              // Oto karartma switch - scroll dışı, en altta
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                child: _buildAutoDarkModeSwitch(textColor, isDark, theme, settingsVm),
              ),
            ],
          ),
        ],
      );
    }
        
        // Normal bar modu
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                title: 'Tema Rengi',
                onBack: () {
                  setState(() => _isColorPickerVisible = false);
                  _updateSubpageSizeAnimation();
                  _notifyDrawerGestureLock();
                },
              ),
              const SizedBox(height: 8),
              _buildColorModeCylinderSelector(textColor, isDark, theme, themeService),
              const SizedBox(height: 0),
              
              Expanded(
                child: _buildColorModeContent(themeService, textColor, isDark, theme),
              ),
              // Oto karartma switch - scroll dışı, en altta
              _buildAutoDarkModeSwitch(textColor, isDark, theme, settingsVm),
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


  Widget _buildColorModeCylinderSelector(
    Color textColor,
    bool isDark,
    ThemeData theme,
    ThemeService themeService,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final List<_ColorModeItem> items = [
      _ColorModeItem(icon: Symbols.palette_rounded, label: localizations.custom, mode: ThemeColorMode.static),
      _ColorModeItem(icon: Symbols.schedule_rounded, label: localizations.dynamicMode, mode: ThemeColorMode.dynamic),
      _ColorModeItem(icon: Symbols.routine_rounded, label: localizations.system, mode: ThemeColorMode.system),
      _ColorModeItem(icon: Symbols.dark_mode_rounded, label: localizations.dark, mode: ThemeColorMode.black),
    ];
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

  Widget _buildColorModeContent(
    ThemeService themeService,
    Color textColor,
    bool isDark,
    ThemeData theme,
  ) {
    final Widget child = themeService.themeColorMode == ThemeColorMode.static
        ? _buildStaticColorList(themeService)
        : themeService.themeColorMode == ThemeColorMode.dynamic
            ? _buildDynamicColorInfo(textColor, isDark, theme, themeService)
            : themeService.themeColorMode == ThemeColorMode.system
                ? _buildSystemColorInfo(textColor, isDark, theme)
                : _buildBlackColorInfo(textColor, isDark, theme);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: child,
      ),
    );
  }

  // sınıf top-level'a taşındı

  Widget _buildNotificationsPage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = GlassBarConstants.getTextColor(context);
    
    // Eğer liste boşsa ve service'te veri varsa, yüklemeyi dene
    if (_notificationSettings.isEmpty) {
      final svc = notifsvc.NotificationSettingsService();
      if (svc.isLoaded && svc.settings.isNotEmpty) {
        // Service yüklü ve veri var, ama local liste boş - hemen güncelle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _initializeNotificationSettings();
          }
        });
      }
    }
    
    // Aynı vakte ait bildirimleri grupla (imsak, imsak_1, imsak_2 ... gibi)
    final Map<String, List<notifsvc.NotificationSetting>> grouped = {};
    for (final setting in _notificationSettings) {
      final String baseId = _baseNotificationId(setting.id);
      grouped.putIfAbsent(baseId, () => []).add(setting);
    }
    final List<MapEntry<String, List<notifsvc.NotificationSetting>>> groups =
        grouped.entries.toList();
    
    // Drawer modunda dinamik boyut
    if (widget.isDrawerMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst alan - kapatma butonu ile aynı yükseklikte
          const SizedBox(height: 18),
          // Başlık - sabit (scroll edilmez)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
            child: _buildPageHeader(
              title: AppLocalizations.of(context)!.notifications,
              onBack: () {
                _closeAllPickers();
                setState(() {
                  _isNotificationsVisible = false;
                });
                _updateSubpageSizeAnimation();
                _notifyDrawerGestureLock();
              },
            ),
          ),
          const SizedBox(height: 16),
          // Scroll edilebilir içerik
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 5),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final String baseId = group.key;
                    final List<notifsvc.NotificationSetting> settings = group.value;
                    final bool isEnabled = settings.any((s) => s.enabled);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNotificationCard(
                        baseId: baseId,
                        settings: settings,
                        isEnabled: isEnabled,
                        textColor: textColor,
                        isDark: isDark,
                        theme: theme,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Normal bar modu
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: AppLocalizations.of(context)!.notifications,
            onBack: () {
              _closeAllPickers();
              setState(() {
                _isNotificationsVisible = false;
              });
              _updateSubpageSizeAnimation();
              _notifyDrawerGestureLock();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 0),
              physics: const BouncingScrollPhysics(),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final String baseId = group.key;
                final List<notifsvc.NotificationSetting> settings = group.value;
                final bool isEnabled = settings.any((s) => s.enabled);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildNotificationCard(
                    baseId: baseId,
                    settings: settings,
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                      AppLocalizations.of(context)!.dynamicThemeDescription,
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
                      AppLocalizations.of(context)!.blackThemeDescription,
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
                      AppLocalizations.of(context)!.systemThemeDescription,
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

  Widget _buildAutoDarkModeSwitch(
    Color textColor,
    bool isDark,
    ThemeData theme,
    SettingsViewModel settingsVm,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          settingsVm.setAutoDarkMode(!settingsVm.autoDarkMode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.1),
            border: Border.all(
              color: GlassBarConstants.getBorderColor(context).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Symbols.dark_mode,
                color: textColor.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.autoDarkMode,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.autoDarkModeDescription,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildCustomSwitch(
                isEnabled: settingsVm.autoDarkMode,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  settingsVm.setAutoDarkMode(!settingsVm.autoDarkMode);
                },
              ),
            ],
          ),
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
  String _baseNotificationId(String id) {
    final int idx = id.indexOf('_');
    if (idx == -1) return id;
    return id.substring(0, idx);
  }

  bool _canAddExtraNotification(String id) {
    final String baseId = _baseNotificationId(id);
    // Dua ve Cuma için çoklu bildirim şu an desteklenmiyor
    return baseId != 'dua' && baseId != 'cuma';
  }

  String _generateNewNotificationId(String baseId) {
    int maxIndex = 0;
    for (final setting in _notificationSettings) {
      if (setting.id == baseId) {
        // ana kayıt varsayılan olarak index 0 kabul edilir
        maxIndex = maxIndex > 0 ? maxIndex : 0;
      } else if (setting.id.startsWith('${baseId}_')) {
        final String suffix = setting.id.substring(baseId.length + 1);
        final int idx = int.tryParse(suffix) ?? 0;
        if (idx > maxIndex) {
          maxIndex = idx;
        }
      }
    }
    final int nextIndex = maxIndex + 1;
    return '${baseId}_$nextIndex';
  }

  Future<void> _addNotificationFor(notifsvc.NotificationSetting setting) async {
    final String baseId = _baseNotificationId(setting.id);
    if (!_canAddExtraNotification(baseId)) {
      return;
    }

    final String newId = _generateNewNotificationId(baseId);
    final notifsvc.NotificationSetting newSetting = notifsvc.NotificationSetting(
      id: newId,
      title: setting.title,
      enabled: true,
      minutes: setting.minutes,
      pickerVisible: false,
      sound: setting.sound,
      soundPickerVisible: false,
    );

    setState(() {
      final int index =
          _notificationSettings.indexWhere((s) => s.id == setting.id);
      if (index == -1 || index >= _notificationSettings.length - 1) {
        _notificationSettings.add(newSetting);
      } else {
        _notificationSettings.insert(index + 1, newSetting);
      }
      _closeAllPickers();
    });

    await _persistAndReschedule(newSetting);
  }

  Future<void> _removeNotification(String id) async {
    final int index =
        _notificationSettings.indexWhere((setting) => setting.id == id);
    if (index == -1) return;

    setState(() {
      NotificationSoundService.stopPreview();
      _notificationSettings.removeAt(index);
      _closeAllPickers();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String base = 'nv_notif_${id}_';
      await prefs.remove('${base}enabled');
      await prefs.remove('${base}minutes');
      await prefs.remove('${base}sound');
      await prefs.reload();
    } catch (e) {
      if (kDebugMode) {
      }
    }

    try {
      await NotificationSchedulerService.instance.rescheduleTodayNotifications();
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  void _toggleNotificationSetting(String id) {
    final String baseId = _baseNotificationId(id);
    final List<int> indices = [];
    bool currentEnabled = false;

    for (int i = 0; i < _notificationSettings.length; i++) {
      final s = _notificationSettings[i];
      if (_baseNotificationId(s.id) == baseId) {
        indices.add(i);
        if (s.id == baseId) {
          currentEnabled = s.enabled;
        }
      }
    }
    if (indices.isEmpty) return;

    final bool newEnabled = !currentEnabled;

    setState(() {
      for (final i in indices) {
        _notificationSettings[i] =
            _notificationSettings[i].copyWith(enabled: newEnabled);
      }
      // Tüm picker'ları kapatmadan önce önizlemeyi durdur
      NotificationSoundService.stopPreview();
      // Tüm picker'ları kapat
      _closeAllPickers();
    });

    // Tüm grup için ayarları kalıcı olarak kaydet ve yeniden planla
    for (final i in indices) {
      _persistAndReschedule(_notificationSettings[i]);
    }
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
      // SharedPreferences commit işleminin tamamlanması için kısa bir gecikme
      await Future.delayed(const Duration(milliseconds: 100));
      await NotificationSchedulerService.instance.rescheduleTodayNotifications();
    } catch (e) {
      if (kDebugMode) {
      }
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
    required String baseId,
    required List<notifsvc.NotificationSetting> settings,
    required bool isEnabled,
    required Color textColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    final bool isDua = baseId == 'dua';
    
    // Grupları sırala: önce ana kayıt (imsak), sonra ekler (imsak_1, imsak_2 ...)
    final List<notifsvc.NotificationSetting> ordered = List.of(settings);
    ordered.sort((a, b) {
      final String aId = a.id;
      final String bId = b.id;
      if (aId == baseId && bId != baseId) return -1;
      if (bId == baseId && aId != baseId) return 1;
      return aId.compareTo(bId);
    });

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
          for (int i = 0; i < ordered.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 1,
                  width: double.infinity,
                  color: GlassBarConstants.getBorderColor(context)
                      .withOpacity(0.25),
                ),
              ),
            _buildNotificationRow(
              baseId: baseId,
              setting: ordered[i],
              textColor: textColor,
              isDark: isDark,
              theme: theme,
              isDua: isDua,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationRow({
    required String baseId,
    required notifsvc.NotificationSetting setting,
    required Color textColor,
    required bool isDark,
    required ThemeData theme,
    required bool isDua,
  }) {
    final bool isEnabled = setting.enabled;
    final bool isBase = setting.id == baseId;
    final bool canAddOrRemove = _canAddExtraNotification(baseId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                () {
                  if (isBase) return setting.title;
                  final String rawId = setting.id;
                  final int underscoreIndex = rawId.indexOf('_');
                  if (underscoreIndex == -1 ||
                      underscoreIndex + 1 >= rawId.length) {
                    return setting.title;
                  }
                  final String suffix = rawId.substring(underscoreIndex + 1);
                  final int? suffixIndex = int.tryParse(suffix);
                  if (suffixIndex == null) {
                    return setting.title;
                  }
                  // Ana kayıt 1, imsak_1 -> 2, imsak_2 -> 3 ...
                  final int displayNumber = suffixIndex + 1;
                  return '${setting.title} $displayNumber';
                }(),
                style: TextStyle(
                  color: textColor,
                  fontSize: isBase ? 16 : 14,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (canAddOrRemove && (isBase ? isEnabled : true))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () {
                    if (isBase) {
                      _addNotificationFor(setting);
                    } else {
                      _removeNotification(setting.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GlassBarConstants.getBackgroundColor(context)
                          .withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GlassBarConstants.getBorderColor(context)
                            .withOpacity(0.7),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isBase ? Symbols.add : Symbols.delete,
                      size: 16,
                      color: textColor.withOpacity(0.95),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            if (isBase)
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
                  child: _buildNotificationControls(
                    setting,
                    textColor,
                    isDark,
                    theme,
                  ),
                ),
              ),
            ),
          ),
      ],
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
                        ? AppLocalizations.of(context)!.onTime
                        : AppLocalizations.of(context)!.minutesBefore(setting.minutes),
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
      child: ScrollConfiguration(
        behavior: const _GentleOverscrollBehavior(),
        child: PrimaryScrollController.none(
          child: ListView.builder(
            controller: _soundPickerController,
            primary: false,
            shrinkWrap: true,
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
                Symbols.arrow_back_ios_rounded ,
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
            textDirection: TextDirection.ltr, // Toggle pozisyonu LTR için hesaplandığından her zaman LTR kullan
            children: [
              _buildThemeOption(
                icon: Symbols.light_mode_rounded,
                mode: AppThemeMode.light,
                isSelected: widget.themeMode == AppThemeMode.light,
              ),
              const SizedBox(width: 2),
              _buildThemeOption(
                icon: Symbols.routine_rounded,
                mode: AppThemeMode.system,
                isSelected: widget.themeMode == AppThemeMode.system,
              ),
              const SizedBox(width: 2),
              _buildThemeOption(
                icon: Symbols.dark_mode_rounded,
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
      onTap: () => widget.onThemeChanged(mode),
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
}
