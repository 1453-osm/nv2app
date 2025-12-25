import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:ui';
import '../viewmodels/onboarding_viewmodel.dart';
import '../viewmodels/location_viewmodel.dart';
import '../models/location_model.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../services/theme_service.dart';
import 'package:material_symbols_icons/symbols.dart';

const BorderRadius _radius24 = BorderRadius.all(Radius.circular(24));
const BorderRadius _radius16 = BorderRadius.all(Radius.circular(16));
const BorderRadius _radius12 = BorderRadius.all(Radius.circular(12));
final ImageFilter _blurStrong = ImageFilter.blur(sigmaX: 200, sigmaY: 200);
final ImageFilter _blurMedium = ImageFilter.blur(sigmaX: 100, sigmaY: 100);
const String _nastaliqFontFamily = 'Nestaliq';

// Sabit renkler - gereksiz oluşturmaları önlemek için
class _OnboardingColors {
  static final white90 = Colors.white.withValues(alpha: 0.9);
  static final white85 = Colors.white.withValues(alpha: 0.85);
  static final white80 = Colors.white.withValues(alpha: 0.8);
  static final white70 = Colors.white.withValues(alpha: 0.7);
  static final white60 = Colors.white.withValues(alpha: 0.6);
  static final white50 = Colors.white.withValues(alpha: 0.5);
  static final white30 = Colors.white.withValues(alpha: 0.3);
  static final white20 = Colors.white.withValues(alpha: 0.2);
  static final white15 = Colors.white.withValues(alpha: 0.15);
  static final white12 = Colors.white.withValues(alpha: 0.12);
  static final white10 = Colors.white.withValues(alpha: 0.1);
  static final white05 = Colors.white.withValues(alpha: 0.05);
  static final white95 = Colors.white.withValues(alpha: 0.95);
  static final white92 = Colors.white.withValues(alpha: 0.92);
  static final red15 = Colors.red.withValues(alpha: 0.15);
  static final red30 = Colors.red.withValues(alpha: 0.3);
  static final green50 = Colors.green.withValues(alpha: 0.5);
}

// Sabit stiller
class _OnboardingStyles {
  static const whiteText14 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
  static const whiteText13 = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
}

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Kullanılmayan controller'ları kaldırdık
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _introDone = false;
  late final AnimationController _introController;
  late final Animation<double> _arabicOpacity;
  late final Animation<Offset> _arabicSlide;
  late final Animation<double> _turkishOpacity;
  late final Animation<Offset> _turkishSlide;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    // Arapça metinler için animasyon (hemen başlar)
    _arabicOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _arabicSlide = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    // Türkçe metin için animasyon (biraz gecikme ile başlar, aynı animasyon)
    _turkishOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
    );
    _turkishSlide = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    // Konum ve izinler için senkronize animasyonlar
    final cardAnimationCurve = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
    );
    _cardOpacity = cardAnimationCurve;
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(cardAnimationCurve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LocationViewModel>().loadCountries();
        // İzin durumları sadece kullanıcı butona tıkladığında güncellenecek
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı ayarlardan döndüğünde izin durumlarını kontrol et
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<OnboardingViewModel>().refreshPermissions();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _introController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.select<ThemeService, Color>(
      (themeService) => themeService.currentThemeColor,
    );
    final isLoading = context.select<OnboardingViewModel, bool>(
      (onboarding) => onboarding.isLoading,
    );
    final isLocationSelected = context.select<LocationViewModel, bool>(
      (locationVm) => locationVm.isLocationSelected,
    );

    if (_introController.status == AnimationStatus.dismissed) {
      _introController.forward();
    }

    final showHero = !isLocationSelected && !_introDone;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: themeColor),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHero) ...[
                        RepaintBoundary(
                          child: _GreetingHero(
                            arabicOpacity: _arabicOpacity,
                            arabicSlide: _arabicSlide,
                            turkishOpacity: _turkishOpacity,
                            turkishSlide: _turkishSlide,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 12),
                      Expanded(
                        child: _introDone
                            ? _LocationAndPermissionsStep(
                                key: const ValueKey('location-permissions'),
                                searchController: _searchController,
                                searchFocusNode: _searchFocusNode,
                                cardOpacity: _cardOpacity,
                                cardSlide: _cardSlide,
                              )
                            : _IntroSection(
                                key: const ValueKey('intro'),
                                introController: _introController,
                                onContinue: () {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _introDone = true;
                                  });
                                  _introController.forward(from: 0);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// Ayrıştırılmış Widget'lar

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.arabicOpacity,
    required this.arabicSlide,
    required this.turkishOpacity,
    required this.turkishSlide,
  });

  final Animation<double> arabicOpacity;
  final Animation<Offset> arabicSlide;
  final Animation<double> turkishOpacity;
  final Animation<Offset> turkishSlide;
  static const double _baseTextSize = 44.0;
  static const TextStyle _baseStyle = TextStyle(
    fontFamily: _nastaliqFontFamily,
    fontSize: _baseTextSize,
    height: 1,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 220,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // İlk Arapça metin: السلام
            Positioned.fill(
              top: 40,
              child: FadeTransition(
                opacity: arabicOpacity,
                child: SlideTransition(
                  position: arabicSlide,
                  child: Align(
                    alignment: const Alignment(0.55, -0.80),
                    child: Text(
                      'السلام',
                      style: _baseStyle,
                    ),
                  ),
                ),
              ),
            ),
            // İkinci Arapça metin: عليكم
            Positioned.fill(
              left: 0,
              right: 175,
              top: 0,
              child: FadeTransition(
                opacity: arabicOpacity,
                child: SlideTransition(
                  position: arabicSlide,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'عليكم',
                      style: _baseStyle.copyWith(
                        color: _OnboardingColors.white95,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Türkçe metin: Es-Selamu Aleyküm
            Positioned.fill(
              left: 0,
              right: 0,
              top: 190,
              bottom: 0,
              child: FadeTransition(
                opacity: turkishOpacity,
                child: SlideTransition(
                  position: turkishSlide,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Es-Selamu Aleyküm',
                      style: _baseStyle.copyWith(
                        color: _OnboardingColors.white85,
                        fontSize: 16,
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
}

class _IntroSection extends StatefulWidget {
  const _IntroSection({
    super.key,
    required this.onContinue,
    required this.introController,
  });

  final VoidCallback onContinue;
  final AnimationController introController;

  @override
  State<_IntroSection> createState() => _IntroSectionState();
}

class _IntroSectionState extends State<_IntroSection> {
  List<_IntroFeatureData> _buildFeatures(AppLocalizations localizations) {
    return [
      _IntroFeatureData(
        icon: Symbols.schedule_rounded,
        title: localizations.diyanetPrayerTimes,
        subtitle: localizations.diyanetPrayerTimesSubtitle,
      ),
      _IntroFeatureData(
        icon: Symbols.navigation_rounded,
        title: localizations.gpsQiblaCompass,
        subtitle: localizations.gpsQiblaCompassSubtitle,
      ),
      _IntroFeatureData(
        icon: Symbols.palette_rounded,
        title: localizations.richThemeOptions,
        subtitle: localizations.richThemeOptionsSubtitle,
      ),
      _IntroFeatureData(
        icon: Symbols.notifications_active_rounded,
        title: localizations.customizableNotificationsTitle,
        subtitle: localizations.customizableNotificationsSubtitle,
      ),
    ];
  }

  List<_IntroFeatureData> _features = [];
  List<bool> _visibleFlags = [];
  bool _buttonVisible = false;

  @override
  void initState() {
    super.initState();
    // Hero animasyonu 0.65'te bitiyor
    // Hero animasyonu bitince tanıtım metinlerini başlat
    widget.introController.addListener(_checkHeroAnimation);
    
    // Eğer animasyon zaten geçmişse hemen başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.introController.value >= 0.65) {
        _startFeatureAnimations();
        widget.introController.removeListener(_checkHeroAnimation);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context)!;
    _features = _buildFeatures(localizations);
    if (_visibleFlags.length != _features.length) {
      _visibleFlags = List<bool>.filled(_features.length, false);
    }
  }

  void _checkHeroAnimation() {
    // Hero animasyonu 0.65'te bitiyor
    if (widget.introController.value >= 0.65 && mounted) {
      widget.introController.removeListener(_checkHeroAnimation);
      _startFeatureAnimations();
    }
  }

  @override
  void dispose() {
    widget.introController.removeListener(_checkHeroAnimation);
    super.dispose();
  }

  void _startFeatureAnimations() {
    if (_features.isEmpty) return;
    const animationDuration = Duration(milliseconds: 500);
    const delayBetweenFeatures = Duration(milliseconds: 500);
    
    for (var i = 0; i < _features.length; i++) {
      Future.delayed(delayBetweenFeatures * i, () {
        if (!mounted) return;
        setState(() => _visibleFlags[i] = true);
        
        // Son özellik animasyonu bitince butonu göster
        if (i == _features.length - 1) {
          Future.delayed(animationDuration, () {
            if (mounted) {
              setState(() => _buttonVisible = true);
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: List.generate(_features.length, (index) {
            final feature = _features[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == _features.length - 1 ? 18 : 16),
              child: _AnimatedIntroFeature(
                visible: _visibleFlags[index],
                child: _IntroFeature(data: feature),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        _AnimatedIntroFeature(
          visible: _buttonVisible,
          child: SizedBox(
            width: double.infinity,
            child: _GlassButton(
              label: AppLocalizations.of(context)!.continueButton,
              enabled: true,
              onTap: widget.onContinue,
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroFeatureData {
  _IntroFeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

// Optimize edilmiş animasyon widget'ı - AnimatedOpacity ve Transform kullanarak
class _AnimatedIntroFeature extends StatelessWidget {
  const _AnimatedIntroFeature({
    required this.child,
    required this.visible,
  });

  final Widget child;
  final bool visible;

  static const _animationDuration = Duration(milliseconds: 1500);
  static const _animationCurve = Curves.easeOutBack;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: _animationDuration,
        curve: _animationCurve,
        opacity: visible ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: _animationDuration,
          curve: _animationCurve,
          scale: visible ? 1.0 : 0.85,
          child: Transform.translate(
            offset: Offset(0, visible ? 0.0 : -50.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _IntroFeature extends StatelessWidget {
  const _IntroFeature({required this.data});

  final _IntroFeatureData data;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            color: _OnboardingColors.white92,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _OnboardingColors.white92,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _OnboardingColors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationAndPermissionsStep extends StatelessWidget {
  const _LocationAndPermissionsStep({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.cardOpacity,
    required this.cardSlide,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Animation<double> cardOpacity;
  final Animation<Offset> cardSlide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  // Konum seçimi bölümü
                  SlideTransition(
                    position: cardSlide,
                    child: FadeTransition(
                      opacity: cardOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LocationHint(),
                          const SizedBox(height: 10),
                          _LocationSelectionCard(
                            searchController: searchController,
                            searchFocusNode: searchFocusNode,
                          ),
                          const SizedBox(height: 0),
                        ],
                      ),
                    ),
                  ),
                  // İzinler bölümü (konum ve izinler birlikte gösterilir)
                  SlideTransition(
                    position: cardSlide,
                    child: FadeTransition(
                      opacity: cardOpacity,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _PermissionsAndStartSection(),
                          SizedBox(height: 0),
                        ],
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
  }
}

class _LocationSelectionCard extends StatelessWidget {
  const _LocationSelectionCard({
    required this.searchController,
    required this.searchFocusNode,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: _radius24,
        child: BackdropFilter(
          filter: _blurStrong,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _OnboardingColors.white12,
              borderRadius: _radius24,
              border: Border.all(
                color: _OnboardingColors.white30,
                width: 1.5,
              ),
            ),
            child: _LocationSelectionContent(
              searchController: searchController,
              searchFocusNode: searchFocusNode,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSelectionContent extends StatefulWidget {
  const _LocationSelectionContent({
    required this.searchController,
    required this.searchFocusNode,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  State<_LocationSelectionContent> createState() => _LocationSelectionContentState();
}

class _LocationSelectionContentState extends State<_LocationSelectionContent> {
  void _performCitySearch(String query, LocationViewModel locationViewModel) async {
    if (query.length < 2) {
      locationViewModel.clearCitySearchResults();
      return;
    }
    try {
      await locationViewModel.searchAllCities(query);
    } catch (_) {}
  }

  void _selectCityFromSearch(City city, LocationViewModel locationViewModel) async {
    widget.searchController.clear();
    widget.searchFocusNode.unfocus();
    locationViewModel.clearCitySearchResults();
    await locationViewModel.selectCityById(city.id);
    if (mounted) {
      context.read<PrayerTimesViewModel>().loadPrayerTimes(city.id);
      await context.read<OnboardingViewModel>().refreshPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationViewModel = context.watch<LocationViewModel>();
    
    return Column(
      children: [
        _AutoLocationCard(locationViewModel: locationViewModel),
        const SizedBox(height: 15),
        _SearchBar(
          searchController: widget.searchController,
          searchFocusNode: widget.searchFocusNode,
          onCitySearch: _performCitySearch,
          onCitySelect: _selectCityFromSearch,
        ),
        if (locationViewModel.getSelectedLocationText(Localizations.localeOf(context)) != AppLocalizations.of(context)!.locationNotSelected)
          _SelectedLocationDisplay(locationViewModel: locationViewModel),
        if (locationViewModel.errorCode != null || locationViewModel.errorMessage.isNotEmpty)
          _ErrorMessageDisplay(errorMessage: locationViewModel.errorCode != null 
              ? locationViewModel.getErrorMessage(context) 
              : locationViewModel.errorMessage),
      ],
    );
  }
}

// Ayrıştırılmış küçük widget'lar



class _AutoLocationCard extends StatelessWidget {
  const _AutoLocationCard({
    required this.locationViewModel,
  });

  final LocationViewModel locationViewModel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius16,
      child: BackdropFilter(
        filter: _blurMedium,
        child: Container(
          decoration: BoxDecoration(
            color: _OnboardingColors.white10,
            borderRadius: _radius16,
            border: Border.all(
              color: _OnboardingColors.white20,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: locationViewModel.isLoading
                  ? null
                  : () async {
                      await locationViewModel.getCurrentLocationFromGPS();
                      if (context.mounted) {
                        await context.read<OnboardingViewModel>().refreshPermissions();
                      }
                      if (context.mounted && locationViewModel.isLocationSelected) {
                        context.read<PrayerTimesViewModel>()
                            .loadPrayerTimes(locationViewModel.selectedCity!.id);
                      }
                    },
              borderRadius: _radius16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    locationViewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.my_location_rounded, size: 20, color: _OnboardingColors.white80),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locationViewModel.isLoading 
                            ? AppLocalizations.of(context)!.gettingLocation
                            : AppLocalizations.of(context)!.automaticLocation,
                        style: _OnboardingStyles.whiteText14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.onCitySearch,
    required this.onCitySelect,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Function(String, LocationViewModel) onCitySearch;
  final Function(City, LocationViewModel) onCitySelect;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LocationViewModel>();
    
    return Column(
      children: [
        _buildSearchInput(viewModel),
        if (widget.searchController.text.isNotEmpty && viewModel.cities.isNotEmpty)
          _buildSearchResults(viewModel),
      ],
    );
  }

  Widget _buildSearchInput(LocationViewModel viewModel) {
    return ClipRRect(
      borderRadius: _radius16,
      child: BackdropFilter(
        filter: _blurMedium,
        child: Container(
          decoration: BoxDecoration(
            color: _OnboardingColors.white10,
            borderRadius: _radius16,
            border: Border.all(
              color: _OnboardingColors.white20,
            ),
          ),
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocusNode,
            onChanged: (value) => _onQueryChanged(value, viewModel),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchCity,
              hintStyle: TextStyle(color: _OnboardingColors.white50, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: _OnboardingColors.white60),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(LocationViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ClipRRect(
        borderRadius: _radius12,
        child: BackdropFilter(
          filter: _blurMedium,
          child: Container(
            decoration: BoxDecoration(
              color: _OnboardingColors.white10,
              borderRadius: _radius12,
              border: Border.all(
                color: _OnboardingColors.white20,
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: viewModel.cities.length,
              itemBuilder: (context, index) {
                final city = viewModel.cities[index];
                return _SearchResultItem(
                  city: city,
                  onTap: () => widget.onCitySelect(city, viewModel),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onQueryChanged(String value, LocationViewModel viewModel) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _lastQuery = '';
      viewModel.clearCitySearchResults();
      return;
    }

    if (query == _lastQuery && viewModel.cities.isNotEmpty) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _lastQuery = query;
      widget.onCitySearch(query, viewModel);
    });
  }
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({
    required this.city,
    required this.onTap,
  });

  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    city.getDisplayName(Localizations.localeOf(context)),
                    style: _OnboardingStyles.whiteText14,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _OnboardingColors.white60,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedLocationDisplay extends StatelessWidget {
  const _SelectedLocationDisplay({required this.locationViewModel});

  final LocationViewModel locationViewModel;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _OnboardingColors.white15,
          borderRadius: _radius12,
          border: Border.all(
            color: _OnboardingColors.white30,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locationViewModel.getSelectedLocationText(Localizations.localeOf(context)),
                style: _OnboardingStyles.whiteText13,
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessageDisplay extends StatelessWidget {
  const _ErrorMessageDisplay({required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _OnboardingColors.red15,
          borderRadius: _radius12,
          border: Border.all(
            color: _OnboardingColors.red30,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade100,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade100,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsAndStartSection extends StatelessWidget {
  const _PermissionsAndStartSection();

  @override
  Widget build(BuildContext context) {
    final isLocationSelected = context.select<LocationViewModel, bool>(
      (vm) => vm.isLocationSelected,
    );
    final notificationGranted = context.select<OnboardingViewModel, bool>(
      (vm) => vm.notificationGranted,
    );
    final locationGranted = context.select<OnboardingViewModel, bool>(
      (vm) => vm.locationGranted,
    );
    final ignoringBatteryOptimizations = context.select<OnboardingViewModel, bool>(
      (vm) => vm.ignoringBatteryOptimizations,
    );
    final onboardingVm = context.read<OnboardingViewModel>();

    return Column(
      children: [
        const SizedBox(height: 12),
        _PermissionTile(
          icon: Icons.notifications_active,
          title: 'Bildirim İzni',
          description: 'Vakit bildirimleri gönderebilmek için gereklidir.',
          granted: notificationGranted,
          onTap: () => onboardingVm.requestNotificationPermission(),
        ),
        const SizedBox(height: 12),
        _PermissionTile(
          icon: Icons.location_on_rounded,
          title: AppLocalizations.of(context)!.locationPermission,
          description: AppLocalizations.of(context)!.locationPermissionDescription,
          granted: locationGranted,
          onTap: () async {
            await onboardingVm.requestLocationPermission();
          },
        ),
        const SizedBox(height: 12),
        _PermissionTile(
          icon: Icons.battery_saver_rounded,
          title: AppLocalizations.of(context)!.batteryOptimization,
          description: AppLocalizations.of(context)!.batteryOptimizationDescription,
          granted: ignoringBatteryOptimizations,
          onTap: () async {
            await onboardingVm.requestIgnoreBatteryOptimizations();
          },
        ),
        const SizedBox(height: 20),
        _StartButton(canStart: isLocationSelected),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: _radius16,
        child: BackdropFilter(
          filter: _blurMedium,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _OnboardingColors.white10,
              borderRadius: _radius16,
              border: Border.all(color: _OnboardingColors.white20),
            ),
            child: Row(
              textDirection: Directionality.of(context) == TextDirection.rtl 
                  ? TextDirection.rtl 
                  : TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        textDirection: Directionality.of(context) == TextDirection.rtl 
                            ? TextDirection.rtl 
                            : TextDirection.ltr,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                          InkWell(
                            onTap: granted ? null : onTap,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: granted ? _OnboardingColors.green50 : _OnboardingColors.white10,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _OnboardingColors.white20),
                              ),
                              child: Text(
                                granted 
                                    ? AppLocalizations.of(context)!.granted 
                                    : AppLocalizations.of(context)!.grantPermission,
                                style: TextStyle(
                                  color: granted ? Colors.white : _OnboardingColors.white90,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: _OnboardingColors.white85,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: _radius24,
          child: BackdropFilter(
            filter: _blurStrong,
            child: Container(
              decoration: BoxDecoration(
                color: enabled ? _OnboardingColors.white15 : _OnboardingColors.white05,
                borderRadius: _radius24,
                border: Border.all(
                  color: enabled ? _OnboardingColors.white30 : _OnboardingColors.white10,
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  borderRadius: _radius24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: enabled ? Colors.white : _OnboardingColors.white50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _LocationHint extends StatelessWidget {
  const _LocationHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.locationHint,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        color: _OnboardingColors.white90,
        height: 1.3,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.canStart});

  final bool canStart;

  @override
  Widget build(BuildContext context) {
    return _GlassButton(
      label: AppLocalizations.of(context)!.start,
      enabled: canStart,
      onTap: canStart ? () => _completeOnboarding(context) : null,
    );
  }
}

void _completeOnboarding(BuildContext context) async {
  final viewModel = context.read<OnboardingViewModel>();
  await viewModel.completeOnboarding();
  if (context.mounted) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
} 