import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'firebase_options.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/location_viewmodel.dart';
import 'viewmodels/prayer_times_viewmodel.dart';
import 'viewmodels/location_bar_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/qibla_viewmodel.dart';
import 'services/theme_service.dart';
import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'utils/constants.dart';
import 'services/notification_scheduler_service.dart';
import 'services/notification_settings_service.dart';
import 'viewmodels/daily_content_viewmodel.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Giriş örnekleme (touch resampling) ve resim önbelleği optimizasyonu
    GestureBinding.instance.resamplingEnabled = true;
    PaintingBinding.instance.imageCache.maximumSize = 250;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

    // Global hata yakalama
    FlutterError.onError = (FlutterErrorDetails details) {
      Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
    };
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      return true;
    };

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    runApp(const MyApp());
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrint('$stack');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeService _themeService;
  Timer? _dynamicColorTimer;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _initializeTheme();
    _startDynamicColorTimer();
  }

  // Not: Alarm izni artık onboarding içinde butonla istenecek.

  @override
  void dispose() {
    // Timer'ı güvenli şekilde temizle
    _dynamicColorTimer?.cancel();
    _dynamicColorTimer = null;
    super.dispose();
  }

  Future<void> _initializeTheme() async {
    await _themeService.loadSettings();
    // Bildirim ayarlarını yükle
    await NotificationSettingsService().loadSettings();
    // Bildirim planlayıcıyı başlat (izinler onboarding butonlarıyla istenecek)
    await NotificationSchedulerService.instance.initialize();
    // Uygulama açıldığında (reboot sonrası dahil) bugünün bildirimlerini yeniden planla
    await NotificationSchedulerService.instance.rescheduleTodayNotifications();
  }

  // Dinamik renk güncellemesi için optimize edilmiş timer
  void _startDynamicColorTimer() {
    // Timer'ı sadece gerektiğinde başlat
    _dynamicColorTimer?.cancel();
    _dynamicColorTimer = Timer.periodic(
      AnimationConstants.themeUpdateInterval, 
      (timer) {
        // Sadece widget mounted ise güncelle
        if (mounted) {
          _themeService.checkAndUpdateDynamicColor();
        } else {
          timer.cancel();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services - immediately needed
        ChangeNotifierProvider.value(
          value: _themeService,
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel()..startListeningToThemeService(),
        ),
        // Lazy loaded services - created only when needed
        ChangeNotifierProvider(
          create: (_) => PrayerTimesViewModel(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => LocationBarViewModel(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => QiblaViewModel(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => DailyContentViewModel()..initialize(),
          lazy: true,
        ),
      ],
      child: Consumer2<SettingsViewModel, ThemeService>(
        builder: (context, settingsVm, themeService, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              // Sistem dinamik şemaları servise aktar (yalnızca değiştiğinde etkili olur)
              themeService.updateSystemDynamicSchemes(
                light: lightDynamic,
                dark: darkDynamic,
              );
              return MaterialApp(
                title: AppConstants.appTitle,
                debugShowCheckedModeBanner: false,
                scrollBehavior: const _AppScrollBehavior(),
                theme: themeService.buildTheme(brightness: Brightness.light),
                darkTheme: themeService.buildTheme(brightness: Brightness.dark),
                themeMode: _convertThemeMode(settingsVm.themeMode),
                builder: (context, child) {
                  // MediaQuery optimizasyonu - sadece gerekli değerleri kopyala
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.0),
                    ),
                    child: child!,
                  );
                },
                home: const AppInitializer(),
                routes: {
                  '/home': (context) => const HomeView(),
                },
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _convertThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Platforma göre uygun fiziği kullan, overscroll parıltısı yok
    return const ClampingScrollPhysics();
  }
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Paralel olarak core servisleri initialize et
      await Future.wait([
        context.read<OnboardingViewModel>().initialize(),
        context.read<LocationViewModel>().initialize(),
      ]);
      
      // Prayer times'ı sadece location varsa ve async olarak yükle
      if (mounted) {
        final savedLocation = context.read<LocationViewModel>().selectedLocation;
        if (savedLocation != null) {
          // Prayer times'ı background'da yükle, UI'yi bloke etme
          unawaited(
            context.read<PrayerTimesViewModel>().loadPrayerTimes(savedLocation.city.id)
          );
        }
      }
    } catch (e, s) {
      // Hata durumunda loglar sadece debug modda yazılır
      if (kDebugMode) {
        debugPrint('Initialization error: $e');
        debugPrint('$s');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: SizedBox.shrink(),
        ),
      );
    }

    // Optimize edilmiş selector - sadece gerekli durumları izle
    return Selector2<OnboardingViewModel, LocationViewModel, bool>(
      selector: (context, onboardingVm, locationVm) => 
          onboardingVm.isFirstLaunch || locationVm.selectedLocation == null,
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, shouldShowOnboarding, child) {
        return shouldShowOnboarding 
            ? const OnboardingView() 
            : const HomeView();
      },
    );
  }
}
