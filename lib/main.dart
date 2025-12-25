import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart' as intl;
import 'l10n/app_localizations.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/location_viewmodel.dart';
import 'viewmodels/prayer_times_viewmodel.dart';
import 'viewmodels/location_bar_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/qibla_viewmodel.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'utils/constants.dart';
import 'services/notification_scheduler_service.dart';
import 'services/notification_settings_service.dart';
import 'viewmodels/daily_content_viewmodel.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _ensureDateFormattingInitialized();
    
    // dotenv yükleme - web için opsiyonel
    try {
      await dotenv.load(fileName: "assets/env");
    } catch (e) {
      // Web'de dotenv yüklenemezse devam et (opsiyonel)
      if (kIsWeb && kDebugMode) {
        debugPrint('dotenv loading skipped for web: $e');
      } else if (!kIsWeb) {
        // Mobil platformlarda dotenv zorunlu
        rethrow;
      }
    }

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

    // Firebase initialization - web için opsiyonel
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        // Mobil platformlarda Firebase zorunlu
        if (kDebugMode) {
          debugPrint('Firebase initialization failed: $e');
        }
        rethrow;
      }
    } else {
      // Web'de Firebase yapılandırılmamışsa atla
      if (kDebugMode) {
        debugPrint('Firebase initialization skipped for web');
      }
    }

    // SystemChrome ayarları sadece mobil platformlarda geçerlidir
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Status bar tamamen şeffaf, içerik kenarlara uzansın
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }

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
  late final LocaleService _localeService;
  late final NotificationSettingsService _notificationSettingsService;
  late final NotificationSchedulerService _notificationSchedulerService;
  Timer? _dynamicColorTimer;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _localeService = LocaleService();
    _notificationSettingsService = NotificationSettingsService();
    _notificationSchedulerService = NotificationSchedulerService.instance;
    _initializeServices();
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

  Future<void> _initializeServices() async {
    await Future.wait([
      _themeService.loadSettings(),
      _localeService.loadSavedLocale(),
      _notificationSettingsService.loadSettings(),
    ]);
    // Locale yüklendikten sonra MaterialApp'i rebuild et
    if (mounted) {
      setState(() {});
    }
    // Bildirim planlayıcıyı başlat (izinler onboarding butonlarıyla istenecek)
    // Web'de bildirim servisleri desteklenmiyor
    if (!kIsWeb) {
      await _notificationSchedulerService.initialize();
    // Uygulama açıldığında (reboot sonrası dahil) bugünün bildirimlerini yeniden planla
      await _notificationSchedulerService.rescheduleTodayNotifications();
    }
  }

  // Dinamik renk güncellemesi için optimize edilmiş timer
  void _startDynamicColorTimer() {
    if (AnimationConstants.themeUpdateInterval <= Duration.zero) {
      return;
    }
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
        ChangeNotifierProvider.value(
          value: _localeService,
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final vm = SettingsViewModel();
            vm.startListeningToThemeService();
            vm.loadThemeMode(); // Tema modunu yükle
            return vm;
          },
        ),
        // Lazy loaded services - created only when needed
        ChangeNotifierProxyProvider<LocaleService, PrayerTimesViewModel>(
          lazy: true,
          create: (context) {
            final localeService = context.read<LocaleService>();
            final vm = PrayerTimesViewModel();
            vm.updateLocale(localeService.currentLocale);
            return vm;
          },
          update: (context, localeService, vm) {
            final targetVm = vm ?? PrayerTimesViewModel();
            targetVm.updateLocale(localeService.currentLocale);
            return targetVm;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => LocationBarViewModel(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => QiblaViewModel(),
          lazy: true,
        ),
        ChangeNotifierProxyProvider<LocaleService, DailyContentViewModel>(
          lazy: true,
          create: (context) {
            final localeService = context.read<LocaleService>();
            final vm = DailyContentViewModel();
            vm.attachLocaleService(localeService);
            vm.initialize(preferredLang: localeService.currentLocale.languageCode);
            return vm;
          },
          update: (context, localeService, vm) {
            if (vm == null) {
              final newVm = DailyContentViewModel();
              newVm.attachLocaleService(localeService);
              newVm.initialize(preferredLang: localeService.currentLocale.languageCode);
              return newVm;
            }
            vm.attachLocaleService(localeService);
            return vm;
          },
        ),
      ],
      child: Consumer3<SettingsViewModel, ThemeService, LocaleService>(
        builder: (context, settingsVm, themeService, localeService, child) {
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
                locale: localeService.currentLocale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('tr', ''), // Türkçe
                  Locale('en', ''), // İngilizce
                  Locale('ar', ''), // Arapça
                ],
                theme: themeService.buildTheme(brightness: Brightness.light),
                darkTheme: themeService.buildTheme(brightness: Brightness.dark),
                themeMode: _convertThemeMode(settingsVm.themeMode),
                builder: (context, child) {
                  // RTL desteği için Directionality ekle
                  final textDirection = localeService.textDirection;
                  return Directionality(
                    textDirection: textDirection,
                    child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.0),
                    ),
                    child: AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
                            ? Brightness.light 
                            : Brightness.dark,
                        systemNavigationBarColor: Colors.transparent,
                        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
                            ? Brightness.light 
                            : Brightness.dark,
                        systemNavigationBarDividerColor: Colors.transparent,
                        systemStatusBarContrastEnforced: false,
                        systemNavigationBarContrastEnforced: false,
                      ),
                      child: child!,
                    ),
                  ),
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
    final onboardingVm = context.read<OnboardingViewModel>();
    final locationVm = context.read<LocationViewModel>();
    try {
      // Paralel olarak core servisleri initialize et
      await Future.wait([
        onboardingVm.initialize(),
        locationVm.initialize(),
      ]);
      
      // Prayer times'ı sadece location varsa ve async olarak yükle
      if (mounted) {
        final savedLocation = locationVm.selectedLocation;
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    // OnboardingViewModel'den veri oku ve başlatılmış mı kontrol et
    return Consumer2<OnboardingViewModel, LocationViewModel>(
      builder: (context, onboardingVm, locationVm, child) {
        // Eğer hala başlatılmadıysa, yükleme göster
        if (!onboardingVm.isInitialized) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }
        
        // Başlatıldıysa, doğru view'ı göster
        final shouldShowOnboarding = onboardingVm.isFirstLaunch || locationVm.selectedLocation == null;
        
        return shouldShowOnboarding 
            ? const OnboardingView() 
            : const HomeView();
      },
    );
  }
}

Future<void> _ensureDateFormattingInitialized() async {
  final localeCodes = LocaleService.supportedLocales
      .map(_localeCodeForIntl)
      .toSet();
  await Future.wait(localeCodes.map((code) => intl.initializeDateFormatting(code)));
}

String _localeCodeForIntl(Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}
