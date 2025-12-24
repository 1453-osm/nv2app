import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../services/theme_service.dart';
import '../services/notification_sound_service.dart';
import '../models/location_model.dart';
import 'location_bar.dart';
import 'settings_bar.dart';
import 'qibla_bar.dart';
import 'prayer_times_section.dart';
import 'dart:ui';
import 'dart:async';
import '../utils/responsive.dart';
import '../utils/constants.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  // Bar keys
  final GlobalKey<LocationBarState> _locationBarKey = GlobalKey<LocationBarState>();
  final GlobalKey<SettingsBarState> _settingsBarKey = GlobalKey<SettingsBarState>();
  final GlobalKey<QiblaBarState> _qiblaBarKey = GlobalKey<QiblaBarState>();
  
  // Bar states
  final Map<String, bool> _isBarExpanded = {
    'location': false,
    'settings': false,
    'qibla': false,
  };
  
  final Map<String, bool> _isBarClosing = {
    'location': false,
    'settings': false,
    'qibla': false,
  };
  
  final Map<String, Timer?> _barTimers = {
    'location': null,
    'settings': null,
    'qibla': null,
  };

  @override
  void dispose() {
    _disposeTimers();
    super.dispose();
  }
  
  void _disposeTimers() {
    _barTimers.values.forEach((timer) => timer?.cancel());
  }

  // Herhangi bir bar açık mı?
  bool get _isAnyBarExpanded => _isBarExpanded.values.any((expanded) => expanded);
  
  // Bar kapanma animasyonunu başlat
  void _startClosingAnimation(String barType) {
    if (!_isBarClosing.containsKey(barType)) return;
    
    _isBarClosing[barType] = true;
    _barTimers[barType]?.cancel();
    _barTimers[barType] = Timer(AnimationConstants.medium, () {
      if (mounted) {
        setState(() {
          _isBarClosing[barType] = false;
        });
      }
    });
  }
  
  // Diğer barları kapatma helper metodu
  void _closeOtherBars(String excludeBar) {
    final closeMethods = {
      'location': () => _locationBarKey.currentState?.closeLocationBar(),
      'settings': () => _settingsBarKey.currentState?.closeSettings(),
      'qibla': () => _qiblaBarKey.currentState?.closeQiblaBar(),
    };
    
    for (final barType in _isBarExpanded.keys) {
      if (barType != excludeBar && (_isBarExpanded[barType] ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            closeMethods[barType]?.call();
            setState(() {
              _isBarExpanded[barType] = false;
            });
          }
        });
      }
    }
  }
  
  // Bar sıralaması helper metodu
  void _reorderBarsForZIndex(List<Widget> bars) {
    final barTypes = ['location', 'qibla', 'settings'];
    
    for (int i = 0; i < barTypes.length; i++) {
      final barType = barTypes[i];
      if ((_isBarExpanded[barType] ?? false) || (_isBarClosing[barType] ?? false)) {
        final bar = bars.removeAt(i);
        bars.add(bar);
        break; // Sadece bir bar en üste olabilir
      }
    }
  }

  // Dinamik z-index için bar sıralaması
  List<Widget> _buildBarWidgets(SelectedLocation selectedLocation) {
    final List<Widget> bars = [];
    final media = MediaQuery.of(context);
    final bool isLandscape = media.orientation == Orientation.landscape;
    final double screenWidth = media.size.width;
    // Landscape'te PrayerTimesSection sol (flex:7) ve sağ (flex:5) olarak bölünüyor
    // Üst barları sol sütunun sağ üstüne yerleştirmek için sağ sütun genişliği kadar içeri alıyoruz
    const double rightColumnFlex = 5.0;
    const double leftColumnFlex = 7.0;
    final double rightColumnWidth = isLandscape ? screenWidth * (rightColumnFlex / (leftColumnFlex + rightColumnFlex)) : 0.0;
    final double settingsBaseRight = (isLandscape ? rightColumnWidth : 0.0) + context.rem(15);
    final double qiblaBaseRightOffset = Responsive.value<double>(
      context,
      xs: 57.0,
      sm: 65.0,
      md: 73.0,
      lg: 81.0,
      xl: 89.0,
    );
    final double qiblaRight = (isLandscape ? rightColumnWidth : 0.0) + qiblaBaseRightOffset;
    
    // Location Bar
    bars.add(
      Positioned(
        top: context.rem(15),
        left: context.rem(15),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Genişlik: landscape'te sol sütun genişliğini, portrede ekran genişliğini geçmesin
            maxWidth: isLandscape
                ? (screenWidth * (leftColumnFlex / (leftColumnFlex + rightColumnFlex)) - context.rem(30) - GlassBarConstants.borderWidth * 2)
                : (media.size.width - context.rem(30)),
            // Yükseklik: her iki yönde de ekran yüksekliğini aşmasın
            maxHeight: isLandscape 
                ? (media.size.height - media.padding.top - media.padding.bottom - context.rem(30))
                : (media.size.height - media.padding.top - context.rem(30)),
          ),
          child: LocationBar(
            key: _locationBarKey,
            location: selectedLocation.city.name,
            onLocationSelected: (selectedLocation) {
              context.read<LocationViewModel>().selectLocation(selectedLocation);
              context.read<PrayerTimesViewModel>().loadPrayerTimes(selectedLocation.city.id);
            },
            onExpandedChanged: (isExpanded) {
              if (mounted) {
                setState(() {
                  _isBarExpanded['location'] = isExpanded;
                                      // Diğer barlar açıksa kapat
                  if (isExpanded) {
                    _closeOtherBars('location');
                  } else {
                    // Bar kapandığında kapanma animasyonunu başlat
                    _startClosingAnimation('location');
                  }
                });
              }
            },
          ),
        ),
      ),
    );

    // Qibla Bar
    bars.add(
      Positioned(
        top: context.rem(15),
        right: qiblaRight, // Settings bar'ın solunda; landscape'te sağ sütun genişliği kadar içeri alınır
        child: QiblaBar(
          key: _qiblaBarKey,
          location: selectedLocation,
          onExpandedChanged: (isExpanded) {
            if (mounted) {
              setState(() {
                _isBarExpanded['qibla'] = isExpanded;
                // Diğer barlar açıksa kapat
                if (isExpanded) {
                  _closeOtherBars('qibla');
                } else {
                  // Bar kapandığında kapanma animasyonunu başlat
                  _startClosingAnimation('qibla');
                }
              });
            }
          },
        ),
      ),
    );

    // Settings Bar
    bars.add(
      Positioned(
        top: context.rem(15),
        right: settingsBaseRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? (screenWidth - settingsBaseRight - context.rem(8)) : double.infinity,
            maxHeight: isLandscape ? (media.size.height - media.padding.top - context.rem(20)) : double.infinity,
          ),
          child: SettingsBar(
            key: _settingsBarKey,
            onSettingsPressed: () => Navigator.pushNamed(context, '/settings'),
            themeMode: context.watch<SettingsViewModel>().themeMode,
            onThemeChanged: (mode) => context.read<SettingsViewModel>().changeThemeMode(mode),
            onExpandedChanged: (isExpanded) {
              if (mounted) {
                setState(() {
                  _isBarExpanded['settings'] = isExpanded;
                  if (isExpanded) {
                    _closeOtherBars('settings');
                  } else {
                    _startClosingAnimation('settings');
                  }
                });
              }
            },
          ),
        ),
      ),
    );

      // Overlay'i ekle - animasyonlu overlay ve blur
    bars.add(
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !_isAnyBarExpanded,
          child: GestureDetector(
            onTap: _handleOverlayTap,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: _isAnyBarExpanded ? 1.0 : 0.0,
              ),
              duration: AnimationConstants.medium,
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassBarConstants.blurSigma * (value * 0.015),
                    sigmaY: GlassBarConstants.blurSigma * (value * 0.015),
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 
                      ((Theme.of(context).brightness == Brightness.dark) 
                        ? AppConstants.overlayOpacityDark 
                        : AppConstants.overlayOpacityLight) * value,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Dinamik sıralama: Açık olan bar en üste taşınır
    _reorderBarsForZIndex(bars);

    return bars;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[900] 
          : Colors.white,
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Dinamik tema rengini al
          final themeColor = themeService.currentThemeColor;
          
          return AnimatedContainer(
            width: double.infinity,
            height: double.infinity,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  themeColor.withValues(alpha: 1.0),
                  themeColor.withValues(alpha: 0.4),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    // Ekranda herhangi bir dokunuşta önizleme sesini durdur
                    NotificationSoundService.stopPreview();
                  },
                  child: SafeArea(
                    child: Selector<LocationViewModel, SelectedLocation?>(
                      selector: (context, locationViewModel) => locationViewModel.selectedLocation,
                      builder: (context, selectedLocation, child) {
                        if (selectedLocation == null) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            // Namaz vakitleri, geri sayım ve tarih en altta
                            PrayerTimesSection(location: selectedLocation),
                            // Dinamik z-index ile barlar ve overlay
                            ..._buildBarWidgets(selectedLocation),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // SafeArea dış kenarları için overlay (landscape'te kenarlar açık kalmasın)
                Positioned(
                  left: 0,
                  top: MediaQuery.of(context).padding.top,
                  bottom: MediaQuery.of(context).padding.bottom,
                  width: MediaQuery.of(context).padding.left,
                  child: IgnorePointer(
                    ignoring: !_isAnyBarExpanded,
                    child: GestureDetector(
                      onTap: _handleOverlayTap,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                        duration: AnimationConstants.medium,
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            color: Colors.black.withValues(alpha: 
                              ((Theme.of(context).brightness == Brightness.dark) 
                                ? AppConstants.overlayOpacityDark 
                                : AppConstants.overlayOpacityLight) * value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: MediaQuery.of(context).padding.top,
                  bottom: MediaQuery.of(context).padding.bottom,
                  width: MediaQuery.of(context).padding.right,
                  child: IgnorePointer(
                    ignoring: !_isAnyBarExpanded,
                    child: GestureDetector(
                      onTap: _handleOverlayTap,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                        duration: AnimationConstants.medium,
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            color: Colors.black.withValues(alpha: 
                              ((Theme.of(context).brightness == Brightness.dark) 
                                ? AppConstants.overlayOpacityDark 
                                : AppConstants.overlayOpacityLight) * value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: MediaQuery.of(context).padding.bottom,
                  child: IgnorePointer(
                    ignoring: !_isAnyBarExpanded,
                    child: GestureDetector(
                      onTap: _handleOverlayTap,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                        duration: AnimationConstants.medium,
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            color: Colors.black.withValues(alpha: 
                              ((Theme.of(context).brightness == Brightness.dark) 
                                ? AppConstants.overlayOpacityDark 
                                : AppConstants.overlayOpacityLight) * value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Status bar alanı için kararma + kapatma tıklaması (landscape köşeleri de kapsa)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).padding.top,
                  child: IgnorePointer(
                    ignoring: !_isAnyBarExpanded,
                    child: GestureDetector(
                      onTap: _handleOverlayTap,
                      behavior: HitTestBehavior.opaque,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: _isAnyBarExpanded ? 1.0 : 0.0,
                        ),
                        duration: AnimationConstants.medium,
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            color: Colors.black.withValues(alpha: 
                              ((Theme.of(context).brightness == Brightness.dark) 
                                ? AppConstants.overlayOpacityDark 
                                : AppConstants.overlayOpacityLight) * value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Köşe overlay blokları kaldırıldı; sol/sağ kenar overlay'leri artık
                // status bar ve alt çene padding'lerini hariç tutacak şekilde ayarlandı.
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleOverlayTap() {
    // Açık olan tüm barları kapat
    final closeMethods = {
      'location': () => _locationBarKey.currentState?.closeLocationBar(),
      'settings': () => _settingsBarKey.currentState?.closeSettings(),
      'qibla': () => _qiblaBarKey.currentState?.closeQiblaBar(),
    };
    
    for (final barType in _isBarExpanded.keys) {
      if (_isBarExpanded[barType] ?? false) {
        closeMethods[barType]?.call();
        setState(() {
          _isBarExpanded[barType] = false;
        });
        _startClosingAnimation(barType);
      }
    }
  }
}