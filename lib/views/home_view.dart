import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/qibla_viewmodel.dart';
import '../viewmodels/location_bar_viewmodel.dart';
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
import '../utils/rtl_helper.dart';
import '../utils/error_messages.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:geolocator/geolocator.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Bar keys
  final GlobalKey<LocationBarState> _locationBarKey =
      GlobalKey<LocationBarState>();
  final GlobalKey<SettingsBarState> _settingsBarKey =
      GlobalKey<SettingsBarState>();
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
  late final Future<bool> _locationServiceStatusFuture;
  StreamSubscription<ServiceStatus>? _locationServiceStatusSubscription;
  bool? _isLocationServiceEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationServiceStatusFuture = Geolocator.isLocationServiceEnabled();
    // getServiceStatusStream web platformunda desteklenmiyor
    if (!kIsWeb) {
      _locationServiceStatusSubscription =
          Geolocator.getServiceStatusStream().listen((status) {
        final enabled = status == ServiceStatus.enabled;
        if (enabled != _isLocationServiceEnabled && mounted) {
          setState(() {
            _isLocationServiceEnabled = enabled;
          });
        }
      });
    } else {
      // Web platformunda varsayılan olarak servis aktif kabul edilir
      _isLocationServiceEnabled = true;
    }

    // LocationBar history'yi arka planda preload et (drawer açılış performansı için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final locationBarVm = context.read<LocationBarViewModel>();
        locationBarVm.preloadHistory();
      } catch (_) {
        // Provider henüz oluşturulmamışsa sessizce devam et
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama resume olduğunda, eğer konum yüklü değilse yeniden yüklemeyi dene
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        final locationVm = context.read<LocationViewModel>();
        // Konum yüklü değilse ve kaydedilmiş konum varsa yüklemeyi dene
        locationVm.ensureLocationLoaded();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationServiceStatusSubscription?.cancel();
    _disposeTimers();
    super.dispose();
  }

  void _disposeTimers() {
    _barTimers.values.forEach((timer) => timer?.cancel());
  }

  // Herhangi bir bar açık mı?
  bool get _isAnyBarExpanded =>
      _isBarExpanded.values.any((expanded) => expanded);

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
      if ((_isBarExpanded[barType] ?? false) ||
          (_isBarClosing[barType] ?? false)) {
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
        final isCompact = context.isLandscape && context.isPhone;
        final scaleFactor = isCompact ? 0.8 : 1.0;

        final buttonHeight = context.space(SpaceSize.xxl) * scaleFactor;
        final horizontalPadding = context.space(SpaceSize.sm) * scaleFactor;
        final verticalPadding = context.space(SpaceSize.xs) * scaleFactor;
        final fontSize = context.font(FontSize.xs) * scaleFactor;

        return ClipRRect(
          borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
          child: Container(
            height: buttonHeight,
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius:
                  BorderRadius.circular(GlassBarConstants.borderRadius),
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
                borderRadius:
                    BorderRadius.circular(GlassBarConstants.borderRadius),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding, vertical: verticalPadding),
                  child: Center(
                    child: Text(
                      locationName,
                      style: TextStyle(
                        color: GlassBarConstants.getTextColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize,
                        letterSpacing: 0.7,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        final isCompact = context.isLandscape && context.isPhone;
        final scaleFactor = isCompact ? 0.8 : 1.0;

        final buttonSize = context.space(SpaceSize.xxl) * scaleFactor;
        final iconSize = context.icon(IconSizeLevel.md) * scaleFactor;

        return ClipRRect(
          borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: GlassBarConstants.getBackgroundColor(context),
              borderRadius:
                  BorderRadius.circular(GlassBarConstants.borderRadius),
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
                borderRadius:
                    BorderRadius.circular(GlassBarConstants.borderRadius),
                child: Center(
                  child: Icon(
                    Symbols.menu_rounded,
                    color: GlassBarConstants.getTextColor(context),
                    size: iconSize,
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
        final isCompact = context.isLandscape && context.isPhone;
        final scaleFactor = isCompact ? 0.8 : 1.0;

        final buttonSize = context.space(SpaceSize.xxl) * scaleFactor;
        final iconSizeNormal = context.icon(IconSizeLevel.md) * scaleFactor;
        final iconSizeSmall = context.icon(IconSizeLevel.sm) * scaleFactor;

        return Selector<QiblaViewModel, (QiblaStatus, ErrorCode?, bool)>(
          selector: (_, vm) => (vm.status, vm.errorCode, vm.isPointingToQibla),
          builder: (context, data, _) {
            final (status, errorCode, isPointingToQibla) = data;
            final textColor = GlassBarConstants.getTextColor(context);
            final bool isGpsError = status == QiblaStatus.error &&
                errorCode == ErrorCode.gpsLocationNotAvailable;

            return FutureBuilder<bool>(
              future: _locationServiceStatusFuture,
              builder: (context, snapshot) {
                final bool isLocationServiceDisabled =
                    !(_isLocationServiceEnabled ?? snapshot.data ?? true);

                return ClipRRect(
                  borderRadius:
                      BorderRadius.circular(GlassBarConstants.borderRadius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: isPointingToQibla
                          ? Colors.green.withValues(alpha: 0.3)
                          : GlassBarConstants.getBackgroundColor(context),
                      borderRadius:
                          BorderRadius.circular(GlassBarConstants.borderRadius),
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
                          if (status != QiblaStatus.ready) {
                            context
                                .read<QiblaViewModel>()
                                .calculateQiblaDirection();
                          }
                        },
                        borderRadius: BorderRadius.circular(
                            GlassBarConstants.borderRadius),
                        child: Center(
                          child: Selector<QiblaViewModel, (double, double)>(
                            selector: (_, vm) =>
                                (vm.qiblaDirection, vm.currentDirection),
                            builder: (context, angles, _) {
                              final (qiblaDir, currentDir) = angles;
                              return Transform.rotate(
                                angle: (status == QiblaStatus.ready)
                                    ? (qiblaDir - currentDir) * (math.pi / 180)
                                    : 0,
                                child: Icon(
                                  isGpsError || isLocationServiceDisabled
                                      ? Symbols.near_me_disabled_rounded
                                      : Symbols.navigation_rounded,
                                  color: textColor,
                                  size: isGpsError || isLocationServiceDisabled
                                      ? iconSizeSmall
                                      : iconSizeNormal,
                                ),
                              );
                            },
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
          PositionedDirectional(
            top: 0,
            end: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
                maxWidth: drawerWidth,
              ),
              child: GestureDetector(
                onTap: () {
                  // Menü içine tıklanınca hiçbir şey yapma
                },
                child: Selector<QiblaViewModel, bool>(
                  selector: (_, vm) => vm.isPointingToQibla,
                  builder: (context, isPointingToQibla, _) {
                    final bool isRTL = RTLHelper.isRTLFromContext(context);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isPointingToQibla
                            ? Colors.green.withValues(alpha: 0.3)
                            : GlassBarConstants.getBackgroundColor(context),
                        borderRadius: isRTL
                            ? const BorderRadius.only(
                                topRight: Radius.circular(34),
                                bottomRight: Radius.circular(34),
                                bottomLeft: Radius.circular(34),
                              )
                            : const BorderRadius.only(
                                topLeft: Radius.circular(34),
                                bottomLeft: Radius.circular(34),
                                bottomRight: Radius.circular(34),
                              ),
                        border: Border(
                          left: isRTL
                              ? BorderSide.none
                              : BorderSide(
                                  color: isPointingToQibla
                                      ? Colors.green.withValues(alpha: 0.7)
                                      : GlassBarConstants.getBorderColor(
                                          context),
                                  width: GlassBarConstants.borderWidth,
                                ),
                          right: isRTL
                              ? BorderSide(
                                  color: isPointingToQibla
                                      ? Colors.green.withValues(alpha: 0.7)
                                      : GlassBarConstants.getBorderColor(
                                          context),
                                  width: GlassBarConstants.borderWidth,
                                )
                              : BorderSide.none,
                          top: BorderSide.none,
                          bottom: BorderSide(
                            color: isPointingToQibla
                                ? Colors.green.withValues(alpha: 0.7)
                                : GlassBarConstants.getBorderColor(context),
                            width: GlassBarConstants.borderWidth,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: isRTL
                            ? const BorderRadius.only(
                                topRight: Radius.circular(34),
                                bottomRight: Radius.circular(34),
                                bottomLeft: Radius.circular(34),
                              )
                            : const BorderRadius.only(
                                topLeft: Radius.circular(34),
                                bottomLeft: Radius.circular(34),
                                bottomRight: Radius.circular(34),
                              ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: GlassBarConstants.blurmSigma,
                            sigmaY: GlassBarConstants.blurmSigma,
                          ),
                          child: Container(
                            width: drawerWidth,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: SafeArea(
                              top: false,
                              right: !isRTL,
                              left: isRTL,
                              bottom: false,
                              child: QiblaBar(
                                key: _qiblaBarKey,
                                isDrawerMode: true,
                                location: context
                                    .watch<LocationViewModel>()
                                    .selectedLocation,
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
          Builder(
            builder: (context) {
              final bool isRTL = RTLHelper.isRTLFromContext(context);
              return PositionedDirectional(
                top: 0,
                start: 0,
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
                      borderRadius: isRTL
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(34),
                              bottomLeft: Radius.circular(34),
                              bottomRight: Radius.circular(34),
                            )
                          : const BorderRadius.only(
                              topRight: Radius.circular(34),
                              bottomRight: Radius.circular(34),
                              bottomLeft: Radius.circular(34),
                            ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: GlassBarConstants.blurmSigma,
                          sigmaY: GlassBarConstants.blurmSigma,
                        ),
                        child: Container(
                          width: drawerWidth,
                          decoration: BoxDecoration(
                            color:
                                GlassBarConstants.getBackgroundColor(context),
                            borderRadius: isRTL
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(34),
                                    bottomLeft: Radius.circular(34),
                                    bottomRight: Radius.circular(34),
                                  )
                                : const BorderRadius.only(
                                    topRight: Radius.circular(34),
                                    bottomRight: Radius.circular(34),
                                    bottomLeft: Radius.circular(34),
                                  ),
                            border: Border(
                              right: isRTL
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: GlassBarConstants.getBorderColor(
                                          context),
                                      width: GlassBarConstants.borderWidth,
                                    ),
                              left: isRTL
                                  ? BorderSide(
                                      color: GlassBarConstants.getBorderColor(
                                          context),
                                      width: GlassBarConstants.borderWidth,
                                    )
                                  : BorderSide.none,
                              top: BorderSide.none,
                              bottom: BorderSide(
                                color:
                                    GlassBarConstants.getBorderColor(context),
                                width: GlassBarConstants.borderWidth,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            left: isRTL,
                            right: !isRTL,
                            bottom: false,
                            child:
                                Selector<LocationViewModel, SelectedLocation?>(
                              selector: (_, vm) => vm.selectedLocation,
                              builder: (context, selectedLocation, _) {
                                final locale = Localizations.localeOf(context);
                                final locationViewModel =
                                    context.read<LocationViewModel>();

                                return LocationBar(
                                  key: _locationBarKey,
                                  location: selectedLocation?.city
                                          .getDisplayName(locale) ??
                                      '',
                                  onLocationSelected: (sl) {
                                    locationViewModel.selectLocation(sl);
                                    context
                                        .read<PrayerTimesViewModel>()
                                        .loadPrayerTimes(sl.city.id);
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
              );
            },
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
          Builder(
            builder: (context) {
              final bool isRTL = RTLHelper.isRTLFromContext(context);
              return PositionedDirectional(
                top: 0,
                end: 0,
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
                      borderRadius: isRTL
                          ? const BorderRadius.only(
                              topRight: Radius.circular(34),
                              bottomRight: Radius.circular(34),
                              bottomLeft: Radius.circular(34),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(34),
                              bottomLeft: Radius.circular(34),
                              bottomRight: Radius.circular(34),
                            ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: GlassBarConstants.blurmSigma,
                          sigmaY: GlassBarConstants.blurmSigma,
                        ),
                        child: Container(
                          width: drawerWidth,
                          decoration: BoxDecoration(
                            color:
                                GlassBarConstants.getBackgroundColor(context),
                            borderRadius: isRTL
                                ? const BorderRadius.only(
                                    topRight: Radius.circular(34),
                                    bottomRight: Radius.circular(34),
                                    bottomLeft: Radius.circular(34),
                                  )
                                : const BorderRadius.only(
                                    topLeft: Radius.circular(34),
                                    bottomLeft: Radius.circular(34),
                                    bottomRight: Radius.circular(34),
                                  ),
                            border: Border(
                              left: isRTL
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: GlassBarConstants.getBorderColor(
                                          context),
                                      width: GlassBarConstants.borderWidth,
                                    ),
                              right: isRTL
                                  ? BorderSide(
                                      color: GlassBarConstants.getBorderColor(
                                          context),
                                      width: GlassBarConstants.borderWidth,
                                    )
                                  : BorderSide.none,
                              top: BorderSide.none,
                              bottom: BorderSide(
                                color:
                                    GlassBarConstants.getBorderColor(context),
                                width: GlassBarConstants.borderWidth,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            right: !isRTL,
                            left: isRTL,
                            bottom: false,
                            child: SettingsBar(
                              key: _settingsBarKey,
                              isDrawerMode: true,
                              onSettingsPressed: () =>
                                  Navigator.pushNamed(context, '/settings'),
                              themeMode:
                                  context.watch<SettingsViewModel>().themeMode,
                              onThemeChanged: (mode) => context
                                  .read<SettingsViewModel>()
                                  .changeThemeMode(mode),
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
              );
            },
          ),
        ],
      ),
    );
  }

  // Dinamik z-index için bar sıralaması
  List<Widget> _buildBarWidgets(SelectedLocation selectedLocation) {
    final List<Widget> bars = [];
    // Barlar için konumları hesapla - simetrik padding
    final double topPadding = context.space(SpaceSize.md);
    final double horizontalPadding = context.space(SpaceSize.md);
    final double buttonSpacing = context.space(SpaceSize.xs);
    final double buttonSize = context.space(SpaceSize.xxl) *
        (context.isLandscape && context.isPhone ? 0.8 : 1.0);

    // Location Drawer butonu - sol üst köşe
    final locale = Localizations.localeOf(context);
    bars.add(
      PositionedDirectional(
        top: topPadding,
        start: horizontalPadding,
        child: _buildLocationDrawerButton(
            selectedLocation.city.getDisplayName(locale)),
      ),
    );

    // Qibla Drawer butonu (küçük pusula butonu) - sağ üst
    // Settings butonunun solunda, aralarında buttonSpacing boşluk
    bars.add(
      PositionedDirectional(
        top: topPadding,
        end: horizontalPadding + buttonSize + buttonSpacing,
        child: _buildQiblaDrawerButton(selectedLocation),
      ),
    );

    // Settings Drawer butonu - sağ üst köşe (konum butonuyla simetrik)
    bars.add(
      PositionedDirectional(
        top: topPadding,
        end: horizontalPadding,
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
                    color: Colors.black.withValues(
                      alpha: ((Theme.of(context).brightness == Brightness.dark)
                              ? AppConstants.overlayOpacityDark
                              : AppConstants.overlayOpacityLight) *
                          value,
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
    final mediaQuery = MediaQuery.of(context);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final overlayOpacityBase = isDarkTheme
        ? AppConstants.overlayOpacityDark
        : AppConstants.overlayOpacityLight;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDarkTheme ? Colors.black : Colors.grey[500],
      drawerScrimColor: DrawerConstants.scrimColor,
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
          Selector<ThemeService, (Color, Color, ThemeColorMode)>(
            selector: (_, service) => (
              service.currentThemeColor,
              service.currentSecondaryColor,
              service.themeColorMode,
            ),
            builder: (context, data, _) {
              final (themeColor, secondaryColor, themeColorMode) = data;

              Color effectiveSecondary;

              // İkincil renk sadece dinamik modda kullanılır
              if (themeColorMode == ThemeColorMode.dynamic) {
                // Karanlık modda ikincil rengi hafifçe koyulaştır
                final isDark = Theme.of(context).brightness == Brightness.dark;
                effectiveSecondary = isDark
                    ? Color.lerp(secondaryColor, Colors.black, 0.15) ??
                        secondaryColor
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
                          selector: (context, locationViewModel) =>
                              locationViewModel.selectedLocation,
                          builder: (context, selectedLocation, child) {
                            if (selectedLocation == null) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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
                      top: mediaQuery.padding.top,
                      bottom: mediaQuery.padding.bottom,
                      width: mediaQuery.padding.left,
                      child: IgnorePointer(
                        ignoring: !_isAnyBarExpanded,
                        child: GestureDetector(
                          onTap: _handleOverlayTap,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                            duration: AnimationConstants.medium,
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                color: Colors.black.withValues(
                                    alpha: overlayOpacityBase * value),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: mediaQuery.padding.top,
                      bottom: mediaQuery.padding.bottom,
                      width: mediaQuery.padding.right,
                      child: IgnorePointer(
                        ignoring: !_isAnyBarExpanded,
                        child: GestureDetector(
                          onTap: _handleOverlayTap,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                            duration: AnimationConstants.medium,
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                color: Colors.black.withValues(
                                    alpha: overlayOpacityBase * value),
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
                      height: mediaQuery.padding.bottom,
                      child: IgnorePointer(
                        ignoring: !_isAnyBarExpanded,
                        child: GestureDetector(
                          onTap: _handleOverlayTap,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0.0, end: _isAnyBarExpanded ? 1.0 : 0.0),
                            duration: AnimationConstants.medium,
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                color: Colors.black.withValues(
                                    alpha: overlayOpacityBase * value),
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
                      height: mediaQuery.padding.top,
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
                                color: Colors.black.withValues(
                                    alpha: overlayOpacityBase * value),
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
              ignoring: !(_isLocationDrawerOpen ||
                  _isQiblaDrawerOpen ||
                  _isSettingsDrawerOpen),
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
                  child: (_isLocationDrawerOpen ||
                          _isQiblaDrawerOpen ||
                          _isSettingsDrawerOpen)
                      ? BackdropFilter(
                          key: const ValueKey('blur'),
                          filter: ImageFilter.blur(
                            sigmaX: DrawerConstants.overlayBlurSigma,
                            sigmaY: DrawerConstants.overlayBlurSigma,
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
