import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_bar_viewmodel.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../models/location_model.dart';
import '../utils/constants.dart';

class LocationBar extends StatefulWidget {
  final String location;
  final Function(SelectedLocation)? onLocationSelected;
  final Function(bool)? onExpandedChanged;
  
  const LocationBar({
    Key? key, 
    required this.location,
    this.onLocationSelected,
    this.onExpandedChanged,
  }) : super(key: key);

  @override
  State<LocationBar> createState() => LocationBarState();
}

class LocationBarState extends State<LocationBar> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  double _collapsedWidth = 40.0; // Dinamik olarak güncellenecek
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // Arama barının gerçek yüksekliği ölçümü için
  final GlobalKey _searchBarKey = GlobalKey();
  double _measuredSearchBarHeight = GlassBarConstants.searchBarHeight;
  bool _previousIsExpanded = false;
  
  // Performans için cache değişkenleri
  double? _cachedHeaderHeight;
  double? _cachedLeftPadding;
  double? _cachedIconSize;
  double? _cachedFontSize;
  Color? _cachedTextColor;
  Color? _cachedBackgroundColor;
  Color? _cachedBorderColor;
  double? _lastAnimValue;
  bool _locationChanged = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AnimationConstants.expansionTransition.duration,
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: _collapsedWidth,
      end: GlassBarConstants.expandedWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationConstants.expansionTransition.curve,
    ));

    // Stabilize collapse: update collapsed width, clear search, unfocus after reverse completes
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (_locationChanged) {
          _updateCollapsedWidth();
          _locationChanged = false;
        }
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });

    // İlk render sonrası collapsedWidth güncellemesi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCollapsedWidth();
      _updateSearchBarHeight();
    });
  }

  // Animasyon sırasında yoğun hesaplamaları önlemek için değerleri cache'ler
  ({
    double headerHeight,
    double leftPadding, 
    double iconSize,
    double fontSize,
    Color textColor,
    Color backgroundColor,
    Color borderColor,
  }) _getCachedAnimationValues(double animValue, BuildContext context) {
    if (_lastAnimValue == null || (_lastAnimValue! - animValue).abs() > 0.01) {
      _lastAnimValue = animValue;
      _cachedHeaderHeight = lerpDouble(
        GlassBarConstants.collapsedHeaderHeight, 
        GlassBarConstants.expandedHeaderHeight, 
        animValue
      )!;
      _cachedLeftPadding = lerpDouble(0, GlassBarConstants.headerPadding, animValue)!;
      _cachedIconSize = lerpDouble(
        GlassBarConstants.collapsedIconSize, 
        GlassBarConstants.expandedIconSize, 
        animValue
      )!;
      _cachedFontSize = lerpDouble(
        GlassBarConstants.collapsedFontSize, 
        GlassBarConstants.expandedFontSize, 
        animValue
      )!;
      _cachedTextColor = GlassBarConstants.getTextColor(context);
      _cachedBackgroundColor = GlassBarConstants.getBackgroundColor(context);
      _cachedBorderColor = GlassBarConstants.getBorderColor(context);
    }
    return (
      headerHeight: _cachedHeaderHeight!,
      leftPadding: _cachedLeftPadding!,
      iconSize: _cachedIconSize!,
      fontSize: _cachedFontSize!,
      textColor: _cachedTextColor!,
      backgroundColor: _cachedBackgroundColor!,
      borderColor: _cachedBorderColor!,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Konum değiştiğinde collapsed genişliği hemen güncelle
    if (widget.location != oldWidget.location) {
      _locationChanged = true;
      if (!_animationController.isAnimating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCollapsedWidth();
          _locationChanged = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationBarViewModel>(
      builder: (context, viewModel, child) {
        // Animasyonu yalnızca genişleme durumu değiştiğinde çalıştır
        if (viewModel.isExpanded != _previousIsExpanded) {
          if (viewModel.isExpanded) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
          _previousIsExpanded = viewModel.isExpanded;
          
          // Overlay callback'ini güvenli şekilde çağır
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.onExpandedChanged != null) {
              widget.onExpandedChanged!(viewModel.isExpanded);
            }
          });
        }
        
        // Avoid scheduling post-frame updates on each build to prevent jank

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final animValue = AnimationConstants.expansionTransition.curve.transform(_animationController.value);
            final cached = _getCachedAnimationValues(animValue, context);
            final headerHeight = cached.headerHeight;
            final leftPadding = cached.leftPadding;
            final iconSize = cached.iconSize;
            final fontSize = cached.fontSize;
            final textColor = cached.textColor;
            final backgroundColor = cached.backgroundColor;
            final borderColor = cached.borderColor;

            return LayoutBuilder(
              builder: (context, constraints) {
                // Taşmayı engelle: mevcut maxWidth'i geçme (her iki yönde)
                // Expanded hedef genişliğini, ekran/sütun sınırlarına göre zorla kısalt
                final double targetWidth = GlassBarConstants.expandedWidth;
                final double allowedMax = constraints.maxWidth.isFinite ? constraints.maxWidth : targetWidth;
                // En az 20 piksel margin bırak
                final double clampedExpanded = targetWidth.clamp(GlassBarConstants.minCollapsedWidth, allowedMax - 20);
                final double current = lerpDouble(_collapsedWidth, clampedExpanded, _animationController.value) ?? _widthAnimation.value;
                final double safeWidth = current;
                return Container(
              width: safeWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassBarConstants.blurSigma, 
                    sigmaY: GlassBarConstants.blurSigma
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(GlassBarConstants.borderRadius),
                      border: Border.all(
                        color: borderColor,
                        width: GlassBarConstants.borderWidth,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Static header with improved gesture handling
                        SizedBox(
                          height: headerHeight,
                          child: GestureDetector(
                            onTap: () => viewModel.toggleExpansion(),
                            child: Align(
                              alignment: Alignment(-animValue, 0),
                              child: Padding(
                                padding: EdgeInsets.only(left: leftPadding, right: GlassBarConstants.iconPadding),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Symbols.location_on, color: textColor, size: iconSize),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: AnimatedSwitcher(
                                        duration: GlassBarConstants.transitionDuration,
                                        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                          return Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              ...previousChildren,
                                              if (currentChild != null) currentChild,
                                            ],
                                          );
                                        },
                                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                        child: Container(
                                          key: ValueKey<String>(widget.location),
                                          child: _buildMarqueeText(
                                            text: widget.location,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: fontSize,
                                              letterSpacing: 0.7,
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
                        ),
                        // Expanded content with gesture handling
                        SizeTransition(
                          sizeFactor: CurvedAnimation(
                            parent: _animationController,
                            curve: AnimationConstants.expansionTransition.curve,
                          ),
                          axis: Axis.vertical,
                          axisAlignment: -1.0,
                          child: _buildExpandedContent(context, viewModel),
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
      },
    );
  }

  Widget _buildExpandedContent(BuildContext context, LocationBarViewModel viewModel) {
    return viewModel.isLoading
        ? _buildLoadingContent(context)
        : _buildSelectionContent(context, viewModel);
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

  Widget _buildSelectionContent(BuildContext context, LocationBarViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final bool isPortrait = media.orientation == Orientation.portrait;
        final double fallbackMax = media.size.height - media.padding.top - 24;
        final double maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : fallbackMax;
        
        // Portre: içerik dinamik büyür (max GlassBarConstants.maxContentHeight), arama kutusu altta sabit
        // Manzara: tüm içerik (liste + arama kutusu) tek bir dikey scroll içinde, böylece overflow olmaz
        if (isPortrait) {
          final double portraitMaxContent = GlassBarConstants.maxContentHeight;
          final double reservedForSearch = _measuredSearchBarHeight;
          final double effectiveMaxHeight = (maxHeight - reservedForSearch) <= portraitMaxContent
              ? (maxHeight - reservedForSearch)
              : portraitMaxContent;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama kutusu: başlığın hemen altında sabit
              _buildSearchBar(context, viewModel),
              // Liste: arama kutusunun altında kaydırılabilir
              Flexible(
                child: AnimatedSize(
                  duration: GlassBarConstants.transitionDuration,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: effectiveMaxHeight,
                    ),
                    child: viewModel.searchQuery.isEmpty
                        ? _buildHistoryList(context, viewModel)
                        : _buildSelectionList(context, viewModel),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Landscape: Arama kutusu altta sabit, üstteki içerik kaydırılabilir
          final double reservedForSearch = _measuredSearchBarHeight;
          final double effectiveMaxHeight = (maxHeight - reservedForSearch).clamp(0, maxHeight - reservedForSearch);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama kutusu: başlığın hemen altında sabit
              _buildSearchBar(context, viewModel),
              // Liste: arama kutusunun altında kaydırılabilir
              Flexible(
                child: AnimatedSize(
                  duration: GlassBarConstants.transitionDuration,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: effectiveMaxHeight,
                    ),
                    child: viewModel.searchQuery.isEmpty
                        ? _buildHistoryList(context, viewModel)
                        : _buildSelectionList(context, viewModel),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, LocationBarViewModel viewModel) {
    // Post-frame'de yüksekliği güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSearchBarHeight());
    return Container(
      key: _searchBarKey,
      margin: EdgeInsets.symmetric(
        horizontal: GlassBarConstants.contentPadding, 
        vertical: 8
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => viewModel.updateSearchQuery(value),
              cursorColor: GlassBarConstants.getTextColor(context),
              style: TextStyle(color: GlassBarConstants.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Ara...',
                hintStyle: TextStyle(color: GlassBarConstants.getTextColor(context).withOpacity(GlassBarConstants.hintOpacity)),
                prefixIcon: Icon(Icons.search, color: GlassBarConstants.getTextColor(context).withOpacity(GlassBarConstants.hintOpacity)),
                filled: true,
                fillColor: GlassBarConstants.getBackgroundColor(context).withOpacity(0.1),
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
            onTap: viewModel.isLoading ? null : () async {
              final sl = await viewModel.fetchCurrentLocation();
              if (sl != null && widget.onLocationSelected != null) {
                widget.onLocationSelected!(sl);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlassBarConstants.getBackgroundColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.my_location, color: GlassBarConstants.getTextColor(context).withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionList(BuildContext context, LocationBarViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCityList(context, viewModel),
    );
  }

  Widget _buildCityList(BuildContext context, LocationBarViewModel viewModel) {
    final cities = viewModel.filteredCities;
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        return _buildListItem(
          context: context,
          title: city.name,
          onTap: () {
            viewModel.selectCity(city);
            // Seçim tamamlandığında callback'i çağır
            final selectedLocation = viewModel.selectedLocation;
            if (selectedLocation != null && widget.onLocationSelected != null) {
              widget.onLocationSelected!(selectedLocation);
            }
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
            color: GlassBarConstants.getTextColor(context).withOpacity(0.2),
            width: 0.5,
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
              Icons.arrow_forward_ios,
              color: GlassBarConstants.getTextColor(context).withOpacity(0.6),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the list of previously selected locations from history
  Widget _buildHistoryList(BuildContext context, LocationBarViewModel viewModel) {
    final history = viewModel.history;
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Kayıtlı konum yok',
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
          final isSelected = sl.city.name == widget.location;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return GestureDetector(
            onTap: () {
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
                      color: isSelected
                          ? GlassBarConstants.getTextColor(context).withOpacity(0.3)
                          : GlassBarConstants.getTextColor(context).withOpacity(0.1),
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
                              text: sl.city.name,
                              style: TextStyle(
                                color: GlassBarConstants.getTextColor(context),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildMarqueeText(
                              text: '${sl.state.name}, ${sl.country.name}',
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
                              Icons.close,
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

  // Dışarıdan location bar'ı kapatmak için public metod
  void closeLocationBar() {
    final viewModel = context.read<LocationBarViewModel>();
    if (viewModel.isExpanded) {
      viewModel.toggleExpansion();
    }
  }

  void _updateCollapsedWidth() {
    final text = widget.location;
    final textStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.5,
    );
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    double textWidth = textPainter.width;
    // Icon(24) + SizedBox(3) + padding(5+13) + textWidth
    double totalWidth = 0 + 5 + 5 + 10 + textWidth;
         totalWidth = totalWidth.clamp(GlassBarConstants.minCollapsedWidth, GlassBarConstants.maxCollapsedWidth);
    if ((_collapsedWidth - totalWidth).abs() > 1) {
      setState(() {
        _collapsedWidth = totalWidth;
        // Animasyonun başlangıç değerini güncelle
        _widthAnimation = Tween<double>(
          begin: _collapsedWidth,
          end: GlassBarConstants.expandedWidth,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: AnimationConstants.expansionTransition.curve,
        ));
      });
    }
  }

  // Arama barının gerçek yüksekliğini ölç ve state'e yaz
  void _updateSearchBarHeight() {
    if (!mounted) return;
    final currentContext = _searchBarKey.currentContext;
    if (currentContext == null) return;
    final renderObject = currentContext.findRenderObject();
    if (renderObject is RenderBox) {
      final double newHeight = renderObject.size.height;
      if ((newHeight - _measuredSearchBarHeight).abs() > 0.5) {
        setState(() {
          _measuredSearchBarHeight = newHeight;
        });
      }
    }
  }

  // Builds text with ellipsis if text is wider than container
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
}

 