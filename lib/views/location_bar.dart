import 'dart:ui';
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

class LocationBar extends StatefulWidget {
  final String location;
  final Function(SelectedLocation)? onLocationSelected;

  const LocationBar({
    Key? key,
    required this.location,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationBar> createState() => LocationBarState();
}

class LocationBarState extends State<LocationBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Drawer açıldığında verileri arka planda yükle (UI'ı bloke etmeden)
    // History zaten yüklü, sadece şehirleri arka planda yüklüyoruz
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
    final hintColor = textColor.withOpacity(GlassBarConstants.hintOpacity);
    final backgroundColor = GlassBarConstants.getBackgroundColor(context).withOpacity(0.1);

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
                borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: GlassBarConstants.itemPadding),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: viewModel.isLoading
              ? null
              : () async {
                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    await Geolocator.openLocationSettings();
                    return;
                  }

                  final sl = await viewModel.fetchCurrentLocation();
                  if (sl != null && widget.onLocationSelected != null) {
                    widget.onLocationSelected!(sl);
                    await _refreshHistory(viewModel);
                  }
                },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.my_location_rounded, color: textColor.withOpacity(0.6)),
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

  Widget _buildSelectionList(BuildContext context, LocationBarViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCityList(context, viewModel),
    );
  }

  Widget _buildCityList(BuildContext context, LocationBarViewModel viewModel) {
    final cities = viewModel.filteredCities;
    final locale = Localizations.localeOf(context);

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        return _buildListItem(
          context: context,
          title: city.getDisplayName(locale),
          onTap: () async {
            viewModel.selectCity(city);
            final selectedLocation = viewModel.selectedLocation;
            if (selectedLocation != null && widget.onLocationSelected != null) {
              widget.onLocationSelected!(selectedLocation);
            }
            await _refreshHistory(viewModel);
          },
        );
      },
    );
  }

  Widget _buildListItem({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: GlassBarConstants.getBorderColor(context),
            width: GlassBarConstants.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildMarqueeText(
                text: title,
                style: TextStyle(
                  color: GlassBarConstants.getTextColor(context),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: GlassBarConstants.getTextColor(context).withOpacity(0.6),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, LocationBarViewModel viewModel) {
    final history = viewModel.history;
    final locale = Localizations.localeOf(context);
    
    if (history.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noSavedLocation,
          style: TextStyle(color: GlassBarConstants.getTextColor(context).withOpacity(0.6)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final sl = history[index];
          // Seçili konumu hem normal hem Arapça hem de code (İngilizce) isimle karşılaştır
          final cityDisplayName = sl.city.getDisplayName(locale);
          final isSelected = cityDisplayName == widget.location || 
                            sl.city.name == widget.location || 
                            (sl.city.nameAr != null && sl.city.nameAr == widget.location) ||
                            sl.city.code == widget.location;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return GestureDetector(
            onTap: () async {
              if (widget.onLocationSelected != null) {
                widget.onLocationSelected!(sl);
              }
            },
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.99,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GlassBarConstants.getBackgroundColor(context).withOpacity(0.15)
                        : GlassBarConstants.getBackgroundColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: GlassBarConstants.getBorderColor(context).withOpacity(isSelected ? 0.4 : 0.2),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: 4,
                        height: isSelected ? 30 : 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: isSelected
                              ? (isDark
                                  ? theme.colorScheme.primary
                                  : GlassBarConstants.getTextColor(context).withOpacity(0.8))
                              : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMarqueeText(
                              text: cityDisplayName,
                              style: TextStyle(
                                color: GlassBarConstants.getTextColor(context),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildMarqueeText(
                              text: '${sl.state.getDisplayName(locale)}, ${sl.country.getDisplayName(locale)}',
                              style: TextStyle(
                                color: GlassBarConstants.getTextColor(context).withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSelected)
                        GestureDetector(
                          onTap: () async {
                            await viewModel.removeLocationFromHistory(sl);
                            context.read<PrayerTimesViewModel>().clearCacheForCity(sl.city.id);
                          },
                          child: Container(
                            width: 23,
                            height: 23,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.red.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.red.withOpacity(0.7),
                              size: 12,
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
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(GlassBarConstants.getTextColor(context)),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildMarqueeText({
    required String text,
    required TextStyle style,
  }) {
    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDrawerMode() {
    return Consumer<LocationBarViewModel>(
      builder: (context, viewModel, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
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
                  child: _buildDrawerContent(viewModel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerContent(LocationBarViewModel viewModel) {
    final textColor = GlassBarConstants.getTextColor(context);
    final bool isSearching = viewModel.searchQuery.isNotEmpty;
    final bool isRTL = RTLHelper.isRTLFromContext(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12, 18, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            children: [
              GestureDetector(
                onTap: () {
                  if (isSearching) {
                    _searchController.clear();
                    viewModel.updateSearchQuery('');
                    _searchFocusNode.unfocus();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isSearching ? Icons.arrow_back_rounded : Symbols.location_on_rounded,
                    color: textColor,
                    size: 30,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: 12),
                  child: _buildSearchBar(context, viewModel),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 34),
            child: viewModel.isLoading
                ? _buildLoadingContent(context)
                : viewModel.searchQuery.isEmpty
                    ? _buildHistoryList(context, viewModel)
                    : _buildSelectionList(context, viewModel),
          ),
        ),
      ],
    );
  }

  void closeLocationBar() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }
}