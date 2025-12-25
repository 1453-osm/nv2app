/// Uygulama genelinde kullanılan SharedPreferences ve diğer anahtar sabitleri.
/// Magic string kullanımını önlemek için tüm anahtarlar burada tanımlanır.
class AppKeys {
  AppKeys._(); // Instantiation engelle

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED PREFERENCES KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  // Tema ayarları
  static const String themeColorMode = 'theme_color_mode';
  static const String selectedThemeColor = 'selected_theme_color';
  static const String currentThemeColor = 'current_theme_color';
  static const String appThemeMode = 'app_theme_mode';
  static const String autoDarkMode = 'auto_dark_mode';

  // Locale/Dil ayarları
  static const String localeKey = 'app_locale';

  // Onboarding
  static const String isFirstLaunch = 'is_first_launch';

  // Konum
  static const String selectedLocation = 'selected_location';

  // Namaz vakitleri cache
  static const String prayerTimesCache = 'prayer_times_cache';
  static const String prayerTimesCacheDate = 'prayer_times_cache_date';
  static const String prayerTimesCityCacheId = 'prayer_times_city_cache_id';

  // Widget senkronizasyon için namaz vakitleri
  static const String prayerFajr = 'nv_fajr';
  static const String prayerSunrise = 'nv_sunrise';
  static const String prayerDhuhr = 'nv_dhuhr';
  static const String prayerAsr = 'nv_asr';
  static const String prayerMaghrib = 'nv_maghrib';
  static const String prayerIsha = 'nv_isha';
  static const String prayerTomorrowFajr = 'nv_tomorrow_fajr';
  static const String prayerFajrTomorrow = 'nv_fajr_tomorrow'; // Alternatif key

  // Bildirim ayarları prefix
  static const String notificationPrefix = 'nv_notif_';
  static const String notificationEnabledSuffix = '_enabled';
  static const String notificationMinutesSuffix = '_minutes';
  static const String notificationSoundSuffix = '_sound';

  /// Belirli bir bildirim için enabled key oluşturur
  static String notificationEnabledKey(String id) =>
      '$notificationPrefix${id}$notificationEnabledSuffix';

  /// Belirli bir bildirim için minutes key oluşturur
  static String notificationMinutesKey(String id) =>
      '$notificationPrefix${id}$notificationMinutesSuffix';

  /// Belirli bir bildirim için sound key oluşturur
  static String notificationSoundKey(String id) =>
      '$notificationPrefix${id}$notificationSoundSuffix';

  // ═══════════════════════════════════════════════════════════════════════════
  // DESTEKLENEN DİLLER
  // ═══════════════════════════════════════════════════════════════════════════

  static const String langTurkish = 'tr';
  static const String langEnglish = 'en';
  static const String langArabic = 'ar';

  static const List<String> supportedLanguages = [
    langTurkish,
    langEnglish,
    langArabic,
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // NAMAZ VAKTİ İSİMLERİ (Dinamik tema için)
  // ═══════════════════════════════════════════════════════════════════════════

  static const String prayerNameImsak = 'İmsak';
  static const String prayerNameGunes = 'Güneş';
  static const String prayerNameOgle = 'Öğle';
  static const String prayerNameIkindi = 'İkindi';
  static const String prayerNameAksam = 'Akşam';
  static const String prayerNameYatsi = 'Yatsı';

  static const List<String> prayerNames = [
    prayerNameImsak,
    prayerNameGunes,
    prayerNameOgle,
    prayerNameIkindi,
    prayerNameAksam,
    prayerNameYatsi,
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // BİLDİRİM ID'LERİ
  // ═══════════════════════════════════════════════════════════════════════════

  static const String notifIdImsak = 'imsak';
  static const String notifIdGunes = 'gunes';
  static const String notifIdOgle = 'ogle';
  static const String notifIdIkindi = 'ikindi';
  static const String notifIdAksam = 'aksam';
  static const String notifIdYatsi = 'yatsi';
  static const String notifIdCuma = 'cuma';
  static const String notifIdDua = 'dua';

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET BRIDGE METHOD CHANNEL
  // ═══════════════════════════════════════════════════════════════════════════

  static const String widgetChannelName = 'com.osm.namazvaktim/widgets';

  // ═══════════════════════════════════════════════════════════════════════════
  // ASSET PATHS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String assetsEnvPath = 'assets/env';
  static const String assetsLocationsPath = 'assets/locations/';
  static const String assetsImagesPath = 'assets/images/';
  static const String assetsNotificationsPath = 'assets/notifications/';
  static const String assetsDualarPath = 'assets/notifications/dualar.json';

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD STORAGE
  // ═══════════════════════════════════════════════════════════════════════════

  static const String prayerTimesBaseUrl =
      'https://storage.googleapis.com/namazvaktimdepo';
}
