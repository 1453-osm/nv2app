import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../viewmodels/qibla_viewmodel.dart';
import '../models/location_model.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';
import '../utils/arabic_numbers_helper.dart';
import '../l10n/app_localizations.dart';
import 'dart:math' as math;

class QiblaBar extends StatefulWidget {
  final SelectedLocation? location;
  final Function(bool)? onExpandedChanged;
  final bool isDrawerMode;
  final VoidCallback? onDrawerClose;
  
  const QiblaBar({
    Key? key,
    this.location,
    this.onExpandedChanged,
    this.isDrawerMode = false,
    this.onDrawerClose,
  }) : super(key: key);

  @override
  State<QiblaBar> createState() => QiblaBarState();
}

class QiblaBarState extends State<QiblaBar> {
  SelectedLocation? _lastCalculatedLocation;

  @override
  void initState() {
    super.initState();
    _ensureInitialLocationCalculation();
  }

  @override
  void didUpdateWidget(covariant QiblaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = widget.location;
    if (location == null) return;

    final bool locationChanged = oldWidget.location?.city.id != location.city.id;
    _triggerLocationCalculation(location, force: locationChanged);
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  void closeQiblaBar() {
    final viewModel = context.read<QiblaViewModel>();
    viewModel.closeQiblaBar();
  }

  void _ensureInitialLocationCalculation() {
    final location = widget.location;
    if (location == null) return;
    _triggerLocationCalculation(location);
  }

  void _triggerLocationCalculation(SelectedLocation location, {bool force = false}) {
    if (!force && _lastCalculatedLocation?.city.id == location.city.id) return;
    _lastCalculatedLocation = location;
    _safePostFrameCallback(() {
      final viewModel = context.read<QiblaViewModel>();
      if (force || viewModel.status != QiblaStatus.ready) {
        viewModel.calculateQiblaDirection();
      }
    });
  }

  // Safe callback execution method to prevent memory leaks
  void _safePostFrameCallback(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildDrawerMode();
  }
  
  Widget _buildDistanceContent(QiblaViewModel viewModel, Color textColor) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final distanceStr = viewModel.distanceToKaaba.toStringAsFixed(0);
    final localizedDistance = isArabic ? localizeNumerals(distanceStr, 'ar') : distanceStr;
    
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.distanceToKaaba,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 0),
        Text(
          '$localizedDistance km',
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
          AppLocalizations.of(context)!.calculating,
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
    return Column (
      children: [
        Icon(
          Symbols.error_rounded,
          color: Colors.red,
          size: 14,
        ),
        const SizedBox(height: 4),
        Text(
          ErrorMessages.gpsLocationNotAvailable(context),
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
  
  // Drawer modu render
  Widget _buildDrawerMode() {
    return Consumer<QiblaViewModel>(
      builder: (context, viewModel, child) {
        final textColor = GlassBarConstants.getTextColor(context);
        
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: _buildDrawerContent(viewModel, textColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Drawer içeriği - eski qibla bar'ın tüm içeriğini koruyarak
  Widget _buildDrawerContent(QiblaViewModel viewModel, Color textColor) {
    final bool isGpsError = viewModel.status == QiblaStatus.error && viewModel.errorMessage == ErrorMessages.gpsLocationNotAvailable;
    
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 24),
      child: Row(
        textDirection: Directionality.of(context),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol taraf - Kalibrasyon GIF ve Butonlar
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 36),
                // Kalibrasyon GIF
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/calibre.gif',
                        width: 110,
                        height: 55,
                        fit: BoxFit.fitWidth,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Symbols.gesture_rounded,
                          color: textColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.calibrateDevice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Butonlar - sol tarafta
                Row(
                  textDirection: Directionality.of(context),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Yenileme butonu
                    GestureDetector(
                      onTap: () {
                        viewModel.calculateQiblaDirection();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Symbols.refresh_rounded,
                          color: textColor,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Konum ayarları butonu
                    GestureDetector(
                      onTap: () => viewModel.openLocationSettings(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Symbols.location_on_rounded,
                          color: textColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Durum mesajları (GPS dışı hatalar ve calibration)
                if ((viewModel.status == QiblaStatus.error && !isGpsError) || viewModel.status == QiblaStatus.needsCalibration)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      viewModel.status == QiblaStatus.needsCalibration
                          ? ErrorMessages.compassCalibrationRequired(context)
                          : viewModel.errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Sağ taraf - Pusula ve bilgiler
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Başlık
                Text(
                  AppLocalizations.of(context)!.qibla,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // Pusula (navigasyon ikonu) - büyük
                Transform.rotate(
                  angle: (!isGpsError && viewModel.status == QiblaStatus.ready)
                      ? (viewModel.qiblaDirection - viewModel.currentDirection) * (math.pi / 180)
                      : 0,
                  child: Icon(
                    isGpsError ? Symbols.near_me_disabled_rounded : Symbols.navigation_rounded,
                    color: textColor,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 16),
                // Orta kısım - mesafe, loading veya GPS hata durumu
                if (viewModel.status == QiblaStatus.ready)
                  _buildDistanceContent(viewModel, textColor)
                else if (viewModel.status == QiblaStatus.loading)
                  _buildLoadingContent(viewModel, textColor)
                else if (isGpsError)
                  _buildCenterErrorContent(viewModel, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}