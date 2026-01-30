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
  static const String autoDarkModeOriginalThemeColorMode =
      'auto_dark_mode_original_theme_color_mode';

  // Locale/Dil ayarları
  static const String localeKey = 'app_locale';
  static const String localeAutoModeKey = 'app_locale_auto_mode';
  static const String localeAutoValue = 'auto';

  // Onboarding
  static const String isFirstLaunch = 'is_first_launch';

  // Konum
  static const String selectedLocation = 'selected_location';

  // Namaz vakitleri cache
  static const String prayerTimesCache = 'prayer_times_cache';
  static const String prayerTimesCacheDate = 'prayer_times_cache_date';
  static const String prayerTimesCityCacheId = 'prayer_times_city_cache_id';

  // Gelecek yıl verisi ön yükleme
  static const String nextYearDataLastCheckDate =
      'next_year_data_last_check_date';
  static const String nextYearDataDownloaded = 'next_year_data_downloaded';
  static const String nextYearDataTargetYear = 'next_year_data_target_year';

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
      '$notificationPrefix$id$notificationEnabledSuffix';

  /// Belirli bir bildirim için minutes key oluşturur
  static String notificationMinutesKey(String id) =>
      '$notificationPrefix$id$notificationMinutesSuffix';

  /// Belirli bir bildirim için sound key oluşturur
  static String notificationSoundKey(String id) =>
      '$notificationPrefix$id$notificationSoundSuffix';

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
  // DAILY CONTENT CACHE KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Günlük içerik cache prefix'i (ayet/hadis için)
  static const String dailyContentPrefix = 'daily_content_';
  static const String dailyContentAyetPrefix = 'daily_content_ayet_';
  static const String dailyContentHadisPrefix = 'daily_content_hadis_';
  static const String latestDailyContentAyet = 'latest_daily_content_ayet';
  static const String latestDailyContentHadis = 'latest_daily_content_hadis';

  /// Günlük içerik cache key'i oluşturur
  static String dailyContentKey(String dateKey) => '$dailyContentPrefix$dateKey';
  static String dailyContentAyetKey(String dateKey) =>
      '$dailyContentAyetPrefix$dateKey';
  static String dailyContentHadisKey(String dateKey) =>
      '$dailyContentHadisPrefix$dateKey';

  // ═══════════════════════════════════════════════════════════════════════════
  // RELIGIOUS DAYS CACHE KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String religiousDaysPrefix = 'religious_days_';
  static const String lastCheckedYear = 'last_checked_year';

  /// Belirli bir yıl için dini günler cache key'i
  static String religiousDaysKey(int year) => '$religiousDaysPrefix$year';

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTDOWN FORMAT
  // ═══════════════════════════════════════════════════════════════════════════

  static const String countdownFormat = 'nv_countdown_format';

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET BRIDGE KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  // Widget veri anahtarları
  static const String widgetNextPrayerName = 'nv_next_prayer_name';
  static const String widgetCountdownText = 'nv_countdown_text';
  static const String widgetNextEpochMs = 'nv_next_epoch_ms';
  static const String widgetCurrentThemeColor = 'current_theme_color';
  static const String widgetSelectedThemeColor = 'selected_theme_color';
  static const String widgetLocale = 'nv_widget_locale';
  static const String widgetTodayDateIso = 'nv_today_date_iso';
  static const String widgetTomorrowDateIso = 'nv_tomorrow_date_iso';

  // Widget görünüm ayarları
  static const String widgetCardAlpha = 'nv_card_alpha';
  static const String widgetGradientOn = 'nv_gradient_on';
  static const String widgetCardRadiusDp = 'nv_card_radius_dp';
  static const String widgetTextColorMode = 'nv_text_color_mode';
  static const String widgetBgColorMode = 'nv_bg_color_mode';
  static const String widgetBgImageB64 = 'nv_bg_image_b64';
  static const String widgetBgImagePath = 'nv_bg_image_path';

  // Text-only widget ayarları
  static const String textOnlyWidgetTextColorMode = 'nv_textonly_text_color_mode';
  static const String textOnlyWidgetTextScalePct = 'nv_textonly_text_scale_pct';

  // Takvim widget ayarları
  static const String calendarWidgetHijriDate = 'nv_calendar_hijri_date';
  static const String calendarWidgetGregorianDate = 'nv_calendar_gregorian_date';
  static const String calendarWidgetCardAlpha = 'nv_calendar_card_alpha';
  static const String calendarWidgetGradientOn = 'nv_calendar_gradient_on';
  static const String calendarWidgetCardRadiusDp = 'nv_calendar_card_radius_dp';
  static const String calendarWidgetDisplayMode = 'nv_calendar_display_mode';
  static const String calendarWidgetTextColorMode = 'nv_calendar_text_color_mode';
  static const String calendarWidgetBgColorMode = 'nv_calendar_bg_color_mode';
  static const String calendarWidgetHijriFontStyle = 'nv_calendar_hijri_font_style';
  static const String calendarWidgetGregorianFontStyle =
      'nv_calendar_gregorian_font_style';

  // Yarınki namaz vakitleri (widget için)
  static const String widgetTomorrowFajr = 'nv_tomorrow_fajr';
  static const String widgetTomorrowSunrise = 'nv_tomorrow_sunrise';
  static const String widgetTomorrowDhuhr = 'nv_tomorrow_dhuhr';
  static const String widgetTomorrowAsr = 'nv_tomorrow_asr';
  static const String widgetTomorrowMaghrib = 'nv_tomorrow_maghrib';
  static const String widgetTomorrowIsha = 'nv_tomorrow_isha';

  // Legacy yarın keys (geriye dönük uyumluluk)
  static const String widgetFajrTomorrow = 'nv_fajr_tomorrow';
  static const String widgetSunriseTomorrow = 'nv_sunrise_tomorrow';
  static const String widgetDhuhrTomorrow = 'nv_dhuhr_tomorrow';
  static const String widgetAsrTomorrow = 'nv_asr_tomorrow';
  static const String widgetMaghribTomorrow = 'nv_maghrib_tomorrow';
  static const String widgetIshaTomorrow = 'nv_isha_tomorrow';

  // Dua bildirimi cache keys
  static const String duaTitleDayOffsetPrefix = 'nv_dua_title_dayOffset_';
  static const String duaBodyDayOffsetPrefix = 'nv_dua_body_dayOffset_';
  static const String duaLastTitle = 'nv_dua_last_title';
  static const String duaLastBody = 'nv_dua_last_body';

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
