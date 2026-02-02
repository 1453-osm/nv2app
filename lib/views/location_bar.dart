import '../utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../viewmodels/location_bar_viewmodel.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../models/location_model.dart';
import '../utils/constants.dart';
import '../utils/rtl_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Header ikonu widget'ı - rebuild'lerden izole
class _HeaderIcon extends StatelessWidget {
  final bool isSearching;
  final Color textColor;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.isSearching,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.space(SpaceSize.xxl),
        height: context.space(SpaceSize.xxl),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(context.space(SpaceSize.sm)),
        ),
        alignment: Alignment.center,
        child: Icon(
          isSearching ? Icons.arrow_back_rounded : Symbols.location_on_rounded,
          color: textColor,
          size: context.icon(IconSizeLevel.lg),
        ),
      ),
    );
  }
}

class LocationBar extends StatefulWidget {
  final String location;
  final Function(SelectedLocation)? onLocationSelected;

  const LocationBar({
    super.key,
    required this.location,
    this.onLocationSelected,
  });

  @override
  State<LocationBar> createState() => LocationBarState();
}

class LocationBarState extends State<LocationBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Drawer açıldığında sadece history'yi yükle (şehirler sadece arama yapıldığında yüklenecek)
    // Bu sayede ilk açılış performansı artar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // UI'ı bloke etmemek için await kullanmıyoruz
      context.read<LocationBarViewModel>().ensureDataLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDrawerMode();
  }

  Widget _buildSearchBar(BuildContext context, LocationBarViewModel viewModel) {
    final textColor = GlassBarConstants.getTextColor(context);
    final hintColor =
        textColor.withValues(alpha: GlassBarConstants.hintOpacity);
    final backgroundColor =
        GlassBarConstants.getBackgroundColor(context).withValues(alpha: 0.1);

    return Row(
      textDirection: Directionality.of(context) == TextDirection.rtl
          ? TextDirection.rtl
          : TextDirection.ltr,
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: viewModel.updateSearchQuery,
            cursorColor: textColor,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.search,
              hintStyle: TextStyle(color: hintColor),
              prefixIcon: Icon(Icons.search_rounded, color: hintColor),
              filled: true,
              fillColor: backgroundColor,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(GlassBarConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: context.space(SpaceSize.md)),
            ),
          ),
        ),
        SizedBox(width: context.space(SpaceSize.sm)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: viewModel.isLoading
              ? null
              : () => _handleCurrentLocationTap(context, viewModel),
          child: Container(
            // iOS'ta minimum dokunma alanı 44x44 pt olmalı
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.all(context.space(SpaceSize.sm)),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(context.space(SpaceSize.lg)),
            ),
            child: viewModel.isLoading
                ? SizedBox(
                    width: context.icon(IconSizeLevel.md),
                    height: context.icon(IconSizeLevel.md),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  )
                : Icon(Icons.my_location_rounded,
                    color: textColor.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshHistory(LocationBarViewModel viewModel) async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    await viewModel.refreshHistory();
  }

  /// Mevcut konum butonuna tıklandığında izin kontrolü ve konum alma işlemi
  Future<void> _handleCurrentLocationTap(
      BuildContext context, LocationBarViewModel viewModel) async {
    final l10n = AppLocalizations.of(context)!;

    // 1. Konum servisinin açık olup olmadığını kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showLocationSnackBar(
        context,
        l10n.locationServiceDisabled,
        action: SnackBarAction(
          label: l10n.settings,
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      );
      return;
    }

    // 2. Konum iznini kontrol et
    PermissionStatus permission = await Permission.location.status;

    // İzin henüz sorulmamışsa veya reddedilmişse (ama kalıcı değilse) iste
    if (permission.isDenied) {
      permission = await Permission.location.request();
    }

    // İzin kalıcı olarak reddedilmişse ayarlara yönlendir
    if (permission.isPermanentlyDenied) {
      if (!mounted) return;
      _showLocationSnackBar(
        context,
        l10n.locationPermissionDenied,
        action: SnackBarAction(
          label: l10n.settings,
          onPressed: () => openAppSettings(),
        ),
      );
      return;
    }

    // İzin verilmediyse (reddedildi ama kalıcı değil)
    if (!permission.isGranted && !permission.isLimited) {
      if (!mounted) return;
      _showLocationSnackBar(context, l10n.locationPermissionRequired);
      return;
    }

    // 3. Konum al
    final sl = await viewModel.fetchCurrentLocation();
    if (!mounted) return;

    if (sl != null && widget.onLocationSelected != null) {
      widget.onLocationSelected!(sl);
      await _refreshHistory(viewModel);
    } else {
      // Konum alınamadı
      _showLocationSnackBar(context, l10n.locationNotFound);
    }
  }

  void _showLocationSnackBar(BuildContext context, String message,
      {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Optimize edilmiş şehir listesi - Key ile
  Widget _buildCityListOptimized(BuildContext context, List<City> cities) {
    final locale = Localizations.localeOf(context);
    final viewModel = context.read<LocationBarViewModel>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: cities.length,
        itemBuilder: (context, index) {
          final city = cities[index];
          return _CityListItem(
            key: ValueKey('city_${city.id}'),
            city: city,
            locale: locale,
            onTap: () async {
              viewModel.selectCity(city);
              final selectedLocation = viewModel.selectedLocation;
              if (selectedLocation != null &&
                  widget.onLocationSelected != null) {
                widget.onLocationSelected!(selectedLocation);
              }
              await _refreshHistory(viewModel);
            },
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }

  /// Optimize edilmiş history listesi
  Widget _buildHistoryList(
      BuildContext context, List<SelectedLocation> history) {
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          AppLocalizations.of(context)!.noSavedLocation,
          style: TextStyle(
            color:
                GlassBarConstants.getTextColor(context).withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final locale = Localizations.localeOf(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final sl = history[index];
            return _HistoryListItem(
              key: ValueKey('history_${sl.city.id}'),
              selectedLocation: sl,
              currentLocation: widget.location,
              locale: locale,
              onLocationSelected: widget.onLocationSelected,
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 8),
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDrawerMode() {
    final padding = MediaQuery.of(context).padding;

    return Padding(
      padding: EdgeInsets.only(
        top: padding.top,
      ),
      child: _buildDrawerContent(),
    );
  }

  Widget _buildDrawerContent() {
    final textColor = GlassBarConstants.getTextColor(context);
    final bool isRTL = RTLHelper.isRTLFromContext(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header - sadece searchQuery değiştiğinde rebuild
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.space(SpaceSize.sm),
            context.space(SpaceSize.md),
            context.space(SpaceSize.sm),
            context.space(SpaceSize.sm),
          ),
          child: _buildHeader(textColor, isRTL),
        ),
        // Content listesi - Selector ile optimize
        Flexible(
          fit: FlexFit.loose,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              context.space(SpaceSize.sm),
              context.space(SpaceSize.sm),
              context.space(SpaceSize.sm),
              context.space(SpaceSize.md),
            ),
            child: _buildContentList(),
          ),
        ),
      ],
    );
  }

  /// Header - ikon ve search bar
  Widget _buildHeader(Color textColor, bool isRTL) {
    return Selector<LocationBarViewModel, String>(
      selector: (_, vm) => vm.searchQuery,
      builder: (context, searchQuery, _) {
        final isSearching = searchQuery.isNotEmpty;
        final viewModel = context.read<LocationBarViewModel>();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            _HeaderIcon(
              isSearching: isSearching,
              textColor: textColor,
              onTap: () {
                if (isSearching) {
                  _searchController.clear();
                  viewModel.updateSearchQuery('');
                  _searchFocusNode.unfocus();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _buildSearchBar(context, viewModel),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Content listesi - isLoading ve searchQuery'ye göre render
  Widget _buildContentList() {
    return Selector<LocationBarViewModel, (bool, String, bool)>(
      selector: (_, vm) => (vm.isLoading, vm.searchQuery, vm.cities.isEmpty),
      builder: (context, data, _) {
        final (isLoading, searchQuery, citiesEmpty) = data;

        // Şehirler yükleniyorsa ve arama yapılıyorsa loading göster
        if (isLoading && searchQuery.isNotEmpty) {
          return _buildLoadingContent(context);
        }

        return searchQuery.isEmpty
            ? _buildHistoryListSelector()
            : _buildCityListSelector();
      },
    );
  }

  /// History listesi - Selector ile
  Widget _buildHistoryListSelector() {
    return Selector<LocationBarViewModel, List<SelectedLocation>>(
      selector: (_, vm) => vm.history,
      shouldRebuild: (prev, next) {
        // Liste uzunluğu veya içerik değiştiyse rebuild et
        if (prev.length != next.length) return true;
        // İçerik kontrolü - her bir item'ın city.id'sini karşılaştır
        for (int i = 0; i < prev.length; i++) {
          if (prev[i].city.id != next[i].city.id) return true;
        }
        return false;
      },
      builder: (context, history, _) {
        return _buildHistoryList(context, history);
      },
    );
  }

  /// Şehir listesi - Selector ile
  Widget _buildCityListSelector() {
    return Selector<LocationBarViewModel, List<City>>(
      selector: (_, vm) => vm.filteredCities,
      builder: (context, cities, _) {
        return _buildCityListOptimized(context, cities);
      },
    );
  }

  void closeLocationBar() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }
}

/// Şehir listesi item widget'ı - rebuild'den izole
class _CityListItem extends StatelessWidget {
  final City city;
  final Locale locale;
  final VoidCallback onTap;

  const _CityListItem({
    required super.key,
    required this.city,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = GlassBarConstants.getTextColor(context);
    final backgroundColor = GlassBarConstants.getBackgroundColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.space(SpaceSize.md),
          vertical: context.space(SpaceSize.md),
        ),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(context.space(SpaceSize.md)),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: GlassBarConstants.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city.getDisplayName(locale),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: context.font(FontSize.md),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textColor.withValues(alpha: 0.6),
              size: context.icon(IconSizeLevel.xs),
            ),
          ],
        ),
      ),
    );
  }
}

/// History listesi item widget'ı - rebuild'den izole ve animasyonlu
class _HistoryListItem extends StatefulWidget {
  final SelectedLocation selectedLocation;
  final String currentLocation;
  final Locale locale;
  final Function(SelectedLocation)? onLocationSelected;

  const _HistoryListItem({
    required super.key,
    required this.selectedLocation,
    required this.currentLocation,
    required this.locale,
    this.onLocationSelected,
  });

  @override
  State<_HistoryListItem> createState() => _HistoryListItemState();
}

class _HistoryListItemState extends State<_HistoryListItem>
    with SingleTickerProviderStateMixin {
  bool _isDeleting = false;
  double _opacity = 1.0;
  late AnimationController _sizeController;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _sizeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _sizeController,
      curve: Curves.easeInOut,
    );
    _sizeController.value = 1.0; // Başlangıçta tam boyutta
  }

  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    // Fade-out ve size animasyonunu başlat
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    setState(() {
      _opacity = 0.0;
    });

    // Size animasyonunu başlat (yüksekliği 0'a düşür)
    _sizeController.reverse();

    // Animasyon tamamlanana kadar bekle
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Silme işlemini gerçekleştir
    final viewModel = context.read<LocationBarViewModel>();
    await viewModel.removeLocationFromHistory(widget.selectedLocation);
    if (mounted) {
      context
          .read<PrayerTimesViewModel>()
          .clearCacheForCity(widget.selectedLocation.city.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityDisplayName =
        widget.selectedLocation.city.getDisplayName(widget.locale);
    final isSelected = cityDisplayName == widget.currentLocation ||
        widget.selectedLocation.city.name == widget.currentLocation ||
        (widget.selectedLocation.city.nameAr != null &&
            widget.selectedLocation.city.nameAr == widget.currentLocation) ||
        widget.selectedLocation.city.code == widget.currentLocation;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = GlassBarConstants.getTextColor(context);
    final backgroundColor = GlassBarConstants.getBackgroundColor(context);

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: _isDeleting
              ? null
              : () async {
                  if (widget.onLocationSelected != null) {
                    widget.onLocationSelected!(widget.selectedLocation);
                  }
                },
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.99,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.space(SpaceSize.sm),
                  vertical: context.space(SpaceSize.sm),
                ),
                margin: EdgeInsets.only(bottom: context.space(SpaceSize.sm)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? backgroundColor.withValues(alpha: 0.15)
                      : backgroundColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(context.space(SpaceSize.md)),
                  border: Border.all(
                    color: GlassBarConstants.getBorderColor(context)
                        .withValues(alpha: isSelected ? 0.4 : 0.2),
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: context.space(SpaceSize.xs),
                      height: isSelected
                          ? context.space(SpaceSize.xl)
                          : context.space(SpaceSize.lg),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(context.space(SpaceSize.xxs)),
                        color: isSelected
                            ? (isDark
                                ? theme.colorScheme.primary
                                : textColor.withValues(alpha: 0.8))
                            : Colors.transparent,
                      ),
                    ),
                    SizedBox(width: context.space(SpaceSize.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cityDisplayName,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: context.font(FontSize.md),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.space(SpaceSize.xxs)),
                          Text(
                            '${widget.selectedLocation.state.getDisplayName(widget.locale)}, ${widget.selectedLocation.country.getDisplayName(widget.locale)}',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: context.font(FontSize.xs),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isSelected)
                      _DeleteButton(
                        key: ValueKey(
                            'delete_${widget.selectedLocation.city.id}'),
                        selectedLocation: widget.selectedLocation,
                        onDelete: _handleDelete,
                        isDeleting: _isDeleting,
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

/// Silme butonu widget'ı
class _DeleteButton extends StatelessWidget {
  final SelectedLocation selectedLocation;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _DeleteButton({
    required super.key,
    required this.selectedLocation,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleting ? null : onDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.space(SpaceSize.xl),
        height: context.space(SpaceSize.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.space(SpaceSize.xl)),
          color: isDeleting
              ? Colors.red.withValues(alpha: 0.05)
              : Colors.red.withValues(alpha: 0.1),
        ),
        child: Icon(
          isDeleting ? Icons.hourglass_empty_rounded : Icons.close_rounded,
          color: isDeleting
              ? Colors.red.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.7),
          size: context.icon(IconSizeLevel.xs),
        ),
      ),
    );
  }
}
