import '../utils/responsive.dart';
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

/// Kalibrasyon GIF widget'ı - rebuild'lerden izole edilmiş
class _CalibrationGif extends StatelessWidget {
  final Color textColor;

  const _CalibrationGif({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.space(SpaceSize.md)),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(context.space(SpaceSize.md)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/calibre.gif',
            width: context.icon(IconSizeLevel.xxl),
            height: context.space(SpaceSize.xxl),
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              Symbols.gesture_rounded,
              color: textColor,
              size: context.icon(IconSizeLevel.lg),
            ),
          ),
          SizedBox(height: context.space(SpaceSize.sm)),
          Text(
            AppLocalizations.of(context)!.calibrateDevice,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: context.font(FontSize.xs),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pusula ikonu - AnimatedRotation ile akıcı dönüş
class _CompassIcon extends StatelessWidget {
  final double rotationAngle;
  final bool isGpsError;
  final Color textColor;

  const _CompassIcon({
    required this.rotationAngle,
    required this.isGpsError,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // Radyanı tura çevir (AnimatedRotation turns kullanıyor)
    final double turns = rotationAngle / (2 * math.pi);
    final iconSize = context.icon(IconSizeLevel.xxl);

    return RepaintBoundary(
      child: AnimatedRotation(
        turns: turns,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOutCubic,
        child: Icon(
          isGpsError
              ? Symbols.near_me_disabled_rounded
              : Symbols.navigation_rounded,
          color: textColor,
          size: iconSize,
        ),
      ),
    );
  }
}

class QiblaBar extends StatefulWidget {
  final SelectedLocation? location;
  final Function(bool)? onExpandedChanged;
  final bool isDrawerMode;
  final VoidCallback? onDrawerClose;

  const QiblaBar({
    super.key,
    this.location,
    this.onExpandedChanged,
    this.isDrawerMode = false,
    this.onDrawerClose,
  });

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

    final bool locationChanged =
        oldWidget.location?.city.id != location.city.id;
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

  void _triggerLocationCalculation(SelectedLocation location,
      {bool force = false}) {
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

  Widget _buildDistanceContent(double distance, Color textColor) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final distanceStr = distance.toStringAsFixed(0);
    final localizedDistance =
        isArabic ? localizeNumerals(distanceStr, 'ar') : distanceStr;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.distanceToKaaba,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: context.font(FontSize.xs),
          ),
        ),
        Text(
          '$localizedDistance km',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.9),
            fontSize: context.font(FontSize.lg),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: context.space(SpaceSize.md),
          height: context.space(SpaceSize.md),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
        SizedBox(height: context.space(SpaceSize.xs)),
        Text(
          AppLocalizations.of(context)!.calculating,
          style: TextStyle(
            color: textColor,
            fontSize: context.font(FontSize.sm),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCenterErrorContent(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.error_rounded,
          color: Colors.red,
          size: context.icon(IconSizeLevel.xs),
        ),
        SizedBox(height: context.space(SpaceSize.xs)),
        Text(
          ErrorMessages.gpsLocationNotAvailable(context),
          style: TextStyle(
            color: Colors.red,
            fontSize: context.font(FontSize.sm),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Drawer modu render
  Widget _buildDrawerMode() {
    final textColor = GlassBarConstants.getTextColor(context);
    final padding = MediaQuery.of(context).padding;

    return Padding(
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _buildDrawerContent(textColor),
          ),
        ],
      ),
    );
  }

  // Drawer içeriği - Selector ile optimize edilmiş
  Widget _buildDrawerContent(Color textColor) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.space(SpaceSize.lg),
        context.space(SpaceSize.lg),
        context.space(SpaceSize.lg),
        context.space(SpaceSize.xl),
      ),
      child: Row(
        textDirection: Directionality.of(context),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol taraf - Kalibrasyon GIF ve Butonlar (statik, rebuild olmaz)
          Expanded(
            flex: 1,
            child: _buildLeftPanel(textColor),
          ),
          SizedBox(width: context.space(SpaceSize.lg)),
          // Sağ taraf - Pusula ve bilgiler (Selector ile optimize)
          Expanded(
            flex: 1,
            child: _buildRightPanel(textColor),
          ),
        ],
      ),
    );
  }

  /// Sol panel - Kalibrasyon GIF ve butonlar
  Widget _buildLeftPanel(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: context.space(SpaceSize.xxl)),
        // Kalibrasyon GIF - ayrı widget olarak izole edildi
        _CalibrationGif(textColor: textColor),
        SizedBox(height: context.space(SpaceSize.md)),
        // Butonlar
        _buildActionButtons(textColor),
        SizedBox(height: context.space(SpaceSize.md)),
        // Durum mesajları - sadece status değiştiğinde rebuild
        _buildStatusMessage(textColor),
      ],
    );
  }

  /// Aksiyon butonları
  Widget _buildActionButtons(Color textColor) {
    final viewModel = context.read<QiblaViewModel>();

    return Row(
      textDirection: Directionality.of(context),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Yenileme butonu
        _ActionButton(
          icon: Symbols.refresh_rounded,
          textColor: textColor,
          onTap: viewModel.calculateQiblaDirection,
        ),
        SizedBox(width: context.space(SpaceSize.sm)),
        // Konum ayarları butonu
        _ActionButton(
          icon: Symbols.location_on_rounded,
          textColor: textColor,
          onTap: viewModel.openLocationSettings,
        ),
      ],
    );
  }

  /// Durum mesajı - Selector ile sadece status değiştiğinde rebuild
  Widget _buildStatusMessage(Color textColor) {
    return Selector<QiblaViewModel, (QiblaStatus, ErrorCode?, String)>(
      selector: (_, vm) => (vm.status, vm.errorCode, vm.errorMessage),
      builder: (context, data, _) {
        final (status, errorCode, errorMessage) = data;
        final bool isGpsError = status == QiblaStatus.error &&
            errorCode == ErrorCode.gpsLocationNotAvailable;

        if ((status == QiblaStatus.error && !isGpsError) ||
            status == QiblaStatus.needsCalibration) {
          return Container(
            padding: EdgeInsets.all(context.space(SpaceSize.sm)),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(context.space(SpaceSize.sm)),
            ),
            child: Text(
              status == QiblaStatus.needsCalibration
                  ? ErrorMessages.compassCalibrationRequired(context)
                  : errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: context.font(FontSize.xs),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Sağ panel - Pusula ve bilgiler
  Widget _buildRightPanel(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: context.space(SpaceSize.lg)),
        // Başlık - statik
        Text(
          AppLocalizations.of(context)!.qibla,
          style: TextStyle(
            color: textColor,
            fontSize: context.font(FontSize.lg),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.space(SpaceSize.md)),
        // Pusula - Selector ile sadece açı değiştiğinde rebuild
        _buildCompass(textColor),
        SizedBox(height: context.space(SpaceSize.md)),
        // Durum içeriği - Selector ile optimize
        _buildStatusContent(textColor),
      ],
    );
  }

  /// Pusula widget'ı - Selector ile sadece açı değiştiğinde rebuild
  Widget _buildCompass(Color textColor) {
    return Selector<QiblaViewModel, (double, double, QiblaStatus, ErrorCode?)>(
      selector: (_, vm) =>
          (vm.qiblaDirection, vm.currentDirection, vm.status, vm.errorCode),
      builder: (context, data, _) {
        final (qiblaDir, currentDir, status, errorCode) = data;
        final bool isGpsError = status == QiblaStatus.error &&
            errorCode == ErrorCode.gpsLocationNotAvailable;

        final double angle = (!isGpsError && status == QiblaStatus.ready)
            ? (qiblaDir - currentDir) * (math.pi / 180)
            : 0;

        return _CompassIcon(
          rotationAngle: angle,
          isGpsError: isGpsError,
          textColor: textColor,
        );
      },
    );
  }

  /// Durum içeriği - mesafe, loading veya hata
  Widget _buildStatusContent(Color textColor) {
    return Selector<QiblaViewModel, (QiblaStatus, double, ErrorCode?)>(
      selector: (_, vm) => (vm.status, vm.distanceToKaaba, vm.errorCode),
      builder: (context, data, _) {
        final (status, distance, errorCode) = data;
        final bool isGpsError = status == QiblaStatus.error &&
            errorCode == ErrorCode.gpsLocationNotAvailable;

        if (status == QiblaStatus.ready) {
          return _buildDistanceContent(distance, textColor);
        } else if (status == QiblaStatus.loading) {
          return _buildLoadingContent(textColor);
        } else if (isGpsError) {
          return _buildCenterErrorContent(textColor);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Aksiyon butonu widget'ı - rebuild'lerden izole
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.space(SpaceSize.md)),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.space(SpaceSize.md)),
        ),
        child: Icon(
          icon,
          color: textColor,
          size: context.icon(IconSizeLevel.md),
        ),
      ),
    );
  }
}
