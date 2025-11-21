import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/qibla_viewmodel.dart';
import '../services/theme_service.dart';
import '../services/notification_sound_service.dart';
import '../models/location_model.dart';
import 'location_bar.dart';
import 'settings_bar.dart';
import 'qibla_bar.dart';
import 'prayer_times_section.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import '../utils/responsive.dart';
import '../utils/constants.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:geolocator/geolocator.dart';

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
  
  bool _isLocationDrawerOpen = false;
  bool _isQiblaDrawerOpen = false;
  bool _isSettingsDrawerOpen = false;
  bool _isQiblaActive = false; // Kıble drawer mı, Settings drawer mı açık?

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
  
  
  // Bar sıralaması helper metodu
  void _reorderBarsForZIndex(List<Widget> bars) {
    final barTypes = ['location', 'qibla'];
    
    for (int i = 0; i < barTypes.length; i++) {
      final barType = barTypes[i];
      if ((_isBarExpanded[barType] ?? false) || (_isBarClosing[barType] ?? false)) {
        final bar = bars.removeAt(i);
        bars.add(bar);
        break; // Sadece bir bar en üste olabilir
      }
    }
  }

  // Location Drawer açma butonu - seçili konum adını göster
  Widget _buildLocationDrawerButton(String locationName) {
    return Builder(
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
              border: Border.all(
                color: GlassBarConstants.getBorderColor(context),
                width: GlassBarConstants.borderWidth,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Drawer'ı aç
                  Scaffold.of(context).openDrawer();
                },
                borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Center(
                    child: Text(
                      locationName,
                      style: TextStyle(
                        color: GlassBarConstants.getTextColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.7,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
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

  // Settings Drawer açma butonu
  Widget _buildDrawerButton() {
    return Builder(
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
              border: Border.all(
                color: GlassBarConstants.getBorderColor(context),
                width: GlassBarConstants.borderWidth,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Settings drawer'ı aç (sağdan)
                  setState(() {
                    _isQiblaActive = false;
                  });
                  Scaffold.of(context).openEndDrawer();
                },
                borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                child: Center(
                  child: Icon(
                    Icons.menu,
                    color: GlassBarConstants.getTextColor(context),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Küçük pusula butonu (Qibla drawer açma)
  Widget _buildQiblaDrawerButton(SelectedLocation selectedLocation) {
    return Builder(
      builder: (BuildContext context) {
        return Consumer<QiblaViewModel>(
          builder: (context, viewModel, _) {
            final textColor = GlassBarConstants.getTextColor(context);
            final bool isGpsError = viewModel.status == QiblaStatus.error && viewModel.errorMessage == 'GPS konumu alınamadı';
            final bool isPointingToQibla = viewModel.isPointingToQibla;
            
            return FutureBuilder<bool>(
              future: Geolocator.isLocationServiceEnabled(),
              builder: (context, snapshot) {
                final bool isLocationServiceDisabled = snapshot.data == false;
                
                return ClipRRect(
                  borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPointingToQibla 
                          ? Colors.green.withValues(alpha: 0.3)
                          : GlassBarConstants.getBackgroundColor(context),
                      borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                      border: Border.all(
                        color: isPointingToQibla
                            ? Colors.green.withValues(alpha: 0.7)
                            : GlassBarConstants.getBorderColor(context),
                        width: GlassBarConstants.borderWidth,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                    onTap: () {
                      // Qibla drawer'ı aç (sağdan)
                      setState(() {
                        _isQiblaActive = true;
                      });
                      Scaffold.of(context).openEndDrawer();
                      // Konum hesapla
                      if (viewModel.status != QiblaStatus.ready) {
                        viewModel.calculateQiblaDirection();
                      }
                    },
                        borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                        child: Center(
                          child: Transform.rotate(
                            angle: (viewModel.status == QiblaStatus.ready)
                                ? (viewModel.qiblaDirection - viewModel.currentDirection) * (math.pi / 180)
                                : 0,
                            child: Icon(
                              isGpsError || isLocationServiceDisabled 
                                  ? Symbols.near_me_disabled_rounded 
                                  : Symbols.navigation_rounded,
                              color: textColor,
                              size: isGpsError || isLocationServiceDisabled ? 18 : 22,
                            ),
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
  
  // Qibla drawer'ını oluştur (sağdan açılır)
  Widget _buildQiblaDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Drawer genişliğini ekran boyutuna göre ayarla
    final drawerWidth = Responsive.value<double>(
      context,
      xs: screenWidth * 0.85,
      sm: 320.0,
      md: 360.0,
      lg: 400.0,
      xl: 420.0,
    ).clamp(280.0, screenWidth * 0.9);
    
    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      width: drawerWidth,
      child: Stack(
        children: [
          // Menü dışı alan - tıklanınca drawer kapanır
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Menü içeriği - sadece görünen kısım tıklanabilir
          Positioned(
            top: 0,
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
                maxWidth: drawerWidth,
              ),
              child: GestureDetector(
                onTap: () {
                  // Menü içine tıklanınca hiçbir şey yapma
                },
                child: Consumer<QiblaViewModel>(
                  builder: (context, viewModel, _) {
                    final bool isPointingToQibla = viewModel.isPointingToQibla;
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isPointingToQibla 
                            ? Colors.green.withValues(alpha: 0.3)
                            : GlassBarConstants.getBackgroundColor(context),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(34),
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: isPointingToQibla
                                ? Colors.green.withValues(alpha: 0.7)
                                : GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                          top: BorderSide.none,
                          right: BorderSide.none,
                          bottom: BorderSide(
                            color: isPointingToQibla
                                ? Colors.green.withValues(alpha: 0.7)
                                : GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(34),
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: GlassBarConstants.blurSigma,
                            sigmaY: GlassBarConstants.blurSigma,
                          ),
                          child: Container(
                            width: drawerWidth,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: SafeArea(
                              top: false,
                              right: false,
                              bottom: false,
                              child: QiblaBar(
                                key: _qiblaBarKey,
                                isDrawerMode: true,
                                location: context.watch<LocationViewModel>().selectedLocation,
                                onDrawerClose: () {
                                  Navigator.of(context).pop();
                                },
                                onExpandedChanged: (isExpanded) {
                                  // Drawer içinde kullanılmıyor
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Konum drawer'ını oluştur
  Widget _buildLocationDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Drawer genişliğini ekran boyutuna göre ayarla
    final drawerWidth = Responsive.value<double>(
      context,
      xs: screenWidth * 0.85,
      sm: 320.0,
      md: 360.0,
      lg: 400.0,
      xl: 420.0,
    ).clamp(280.0, screenWidth * 0.9);
    
    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      width: drawerWidth,
      child: Stack(
        children: [
          // Menü dışı alan - tıklanınca drawer kapanır
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Menü içeriği - sadece görünen kısım tıklanabilir
          Positioned(
            top: 0,
            left: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
                maxWidth: drawerWidth,
              ),
              child: GestureDetector(
                onTap: () {
                  // Menü içine tıklanınca hiçbir şey yapma
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                    bottomLeft: Radius.circular(34),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: GlassBarConstants.blurSigma,
                      sigmaY: GlassBarConstants.blurSigma,
                    ),
                    child: Container(
                      width: drawerWidth,
                      decoration: BoxDecoration(
                        color: GlassBarConstants.getBackgroundColor(context),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                          bottomLeft: Radius.circular(34),
                        ),
                        border: Border(
                          right: BorderSide(
                            color: GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                          top: BorderSide.none,
                          left: BorderSide.none,
                          bottom: BorderSide(
                            color: GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        left: false,
                        bottom: false,
                        child: Consumer<LocationViewModel>(
                          builder: (context, locationViewModel, _) {
                            return LocationBar(
                              key: _locationBarKey,
                              isDrawerMode: true,
                              location: locationViewModel.selectedLocation?.city.name ?? '',
                              onLocationSelected: (selectedLocation) {
                                locationViewModel.selectLocation(selectedLocation);
                                context.read<PrayerTimesViewModel>().loadPrayerTimes(selectedLocation.city.id);
                              },
                              onExpandedChanged: (isExpanded) {
                                if (mounted) {
                                  setState(() {
                                    _isBarExpanded['location'] = isExpanded;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ayarlar drawer'ını oluştur (sağdan açılır)
  Widget _buildSettingsDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Drawer genişliğini ekran boyutuna göre ayarla
    final drawerWidth = Responsive.value<double>(
      context,
      xs: screenWidth * 0.85,
      sm: 320.0,
      md: 360.0,
      lg: 400.0,
      xl: 420.0,
    ).clamp(280.0, screenWidth * 0.9);
    
    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      width: drawerWidth,
      child: Stack(
        children: [
          // Menü dışı alan - tıklanınca drawer kapanır
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Menü içeriği - sadece görünen kısım tıklanabilir
          Positioned(
            top: 0,
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
                maxWidth: drawerWidth,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Menü içine tıklanınca hiçbir şey yapma
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(34),
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: GlassBarConstants.blurSigma,
                      sigmaY: GlassBarConstants.blurSigma,
                    ),
                    child: Container(
                      width: drawerWidth,
                      decoration: BoxDecoration(
                        color: GlassBarConstants.getBackgroundColor(context),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(34),
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                          top: BorderSide.none,
                          right: BorderSide.none,
                          bottom: BorderSide(
                            color: GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        right: false,
                        bottom: false,
                        child: SettingsBar(
                          key: _settingsBarKey,
                          isDrawerMode: true,
                          onSettingsPressed: () => Navigator.pushNamed(context, '/settings'),
                          themeMode: context.watch<SettingsViewModel>().themeMode,
                          onThemeChanged: (mode) => context.read<SettingsViewModel>().changeThemeMode(mode),
                          onExpandedChanged: (isExpanded) {
                            // Drawer içinde expansion durumunu yönet
                            if (mounted) {
                              setState(() {
                                _isBarExpanded['settings'] = isExpanded;
                              });
                            }
                          },
                          onDrawerDragLockChanged: (locked) {
                            // Geriye uyumluluk için callback korunuyor, davranış değiştirmiyor
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    
    // Location Drawer butonu
    bars.add(
      Positioned(
        top: context.rem(15),
        left: context.rem(15),
        child: _buildLocationDrawerButton(selectedLocation.city.name),
      ),
    );

    // Qibla Drawer butonu (küçük pusula butonu)
    bars.add(
      Positioned(
        top: context.rem(15),
        right: qiblaRight,
        child: _buildQiblaDrawerButton(selectedLocation),
      ),
    );

    // Settings Drawer butonu
    bars.add(
      Positioned(
        top: context.rem(15),
        right: settingsBaseRight,
        child: _buildDrawerButton(),
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
          ? Colors.black 
          : Colors.grey[900],
      drawerScrimColor: Colors.transparent,
      drawer: _buildLocationDrawer(),
      endDrawer: _isQiblaActive ? _buildQiblaDrawer() : _buildSettingsDrawer(),
      onDrawerChanged: (isOpened) {
        setState(() {
          _isLocationDrawerOpen = isOpened;
        });
      },
      onEndDrawerChanged: (isOpened) {
        setState(() {
          if (_isQiblaActive) {
            _isQiblaDrawerOpen = isOpened;
          } else {
            _isSettingsDrawerOpen = isOpened;
          }
        });
      },
      body: Stack(
        children: [
          Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Dinamik tema rengini al
          final themeColor = themeService.currentThemeColor;
          
          Color effectiveSecondary;
          
          // İkincil renk sadece dinamik modda kullanılır
          if (themeService.themeColorMode == ThemeColorMode.dynamic) {
            final secondaryColor = themeService.currentSecondaryColor;
            // Karanlık modda ikincil rengi hafifçe koyulaştır
            final isDark = Theme.of(context).brightness == Brightness.dark;
            effectiveSecondary = isDark 
                ? Color.lerp(secondaryColor, Colors.black, 0.15) ?? secondaryColor 
                : secondaryColor;
          } else {
            // Diğer modlarda ana rengin opaklığı azaltılmış halini kullan
            effectiveSecondary = themeColor.withValues(alpha: 0.4);
          }
          
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
                  themeColor,
                  effectiveSecondary,
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
                    // Bottom padding'i devre dışı bırak, manuel olarak yönetiyoruz
                    bottom: false,
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
          // Drawer açıkken hafif blur overlay (location, qibla, settings)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !(_isLocationDrawerOpen || _isQiblaDrawerOpen || _isSettingsDrawerOpen),
              child: GestureDetector(
                onTap: () {
                  // Herhangi bir drawer açıksa kapat
                  if (_isQiblaDrawerOpen || _isSettingsDrawerOpen) {
                    Scaffold.of(context).closeEndDrawer();
                  }
                  if (_isLocationDrawerOpen) {
                    Scaffold.of(context).closeDrawer();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: (_isLocationDrawerOpen || _isQiblaDrawerOpen || _isSettingsDrawerOpen)
                      ? BackdropFilter(
                          key: const ValueKey('blur'),
                          filter: ImageFilter.blur(
                            sigmaX: 3.0,
                            sigmaY: 3.0,
                          ),
                          child: Container(
                            color: Colors.transparent,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-blur')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOverlayTap() {
    // Açık olan tüm barları kapat
    final closeMethods = {
      'location': () => _locationBarKey.currentState?.closeLocationBar(),
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