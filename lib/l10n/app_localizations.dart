import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr')
  ];

  /// Uygulama başlığı
  ///
  /// In tr, this message translates to:
  /// **'Namaz Vakitleri'**
  String get appTitle;

  /// Konum seçilmediğinde gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Konum seçilmedi'**
  String get locationNotSelected;

  /// Yükleme durumu metni
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loading;

  /// Genel hata başlığı
  ///
  /// In tr, this message translates to:
  /// **'Hata Oluştu'**
  String get error;

  /// Tekrar deneme butonu metni
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retry;

  /// İnternet bağlantısı hatası
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok.'**
  String get noInternetConnection;

  /// Veri bulunamadı hatası
  ///
  /// In tr, this message translates to:
  /// **'Veri bulunamadı.'**
  String get dataNotFound;

  /// Sunucu hatası mesajı
  ///
  /// In tr, this message translates to:
  /// **'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.'**
  String get serverError;

  /// Bilinmeyen hata mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen hata oluştu.'**
  String get unknownError;

  /// GPS konumu alınamadı hatası
  ///
  /// In tr, this message translates to:
  /// **'GPS konumu alınamadı'**
  String get gpsLocationNotAvailable;

  /// Kıble yönü hesaplama hatası
  ///
  /// In tr, this message translates to:
  /// **'Kıble yönü hesaplanamadı'**
  String get qiblaDirectionCalculationFailed;

  /// Konum yenileme hatası
  ///
  /// In tr, this message translates to:
  /// **'Konum yenilenemedi'**
  String get locationRefreshFailed;

  /// Pusula kalibrasyon uyarısı
  ///
  /// In tr, this message translates to:
  /// **'Pusula kalibre edilmeli'**
  String get compassNeedsCalibration;

  /// Pusula kalibrasyon gerekliliği
  ///
  /// In tr, this message translates to:
  /// **'Pusula kalibrasyonu gerekli'**
  String get compassCalibrationRequired;

  /// Şehir bulunamadı hatası
  ///
  /// In tr, this message translates to:
  /// **'Konumunuz için şehir bulunamadı'**
  String get cityNotFoundForLocation;

  /// İçerik bulunamadı hatası
  ///
  /// In tr, this message translates to:
  /// **'İçerik bulunamadı'**
  String get contentNotFound;

  /// Küçük harfli tekrar deneme metni
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retryLowercase;

  /// Otomatik konum butonu metni
  ///
  /// In tr, this message translates to:
  /// **'Otomatik Konum'**
  String get automaticLocation;

  /// Konum alınırken gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Konum Alınıyor...'**
  String get gettingLocation;

  /// Bildirim izni başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim İzni'**
  String get notificationPermission;

  /// Bildirim izni açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Vakit bildirimleri gönderebilmek için gereklidir.'**
  String get notificationPermissionDescription;

  /// Konum izni başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konum İzni'**
  String get locationPermission;

  /// Konum izni açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Konuma göre doğru namaz vakitlerini göstermek için gereklidir.'**
  String get locationPermissionDescription;

  /// Pil optimizasyonu başlığı
  ///
  /// In tr, this message translates to:
  /// **'Pil Optimizasyonundan Çıkar (Android)'**
  String get batteryOptimization;

  /// Pil optimizasyonu açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Arka planda güvenilir bildirim/hatırlatıcı için önerilir.'**
  String get batteryOptimizationDescription;

  /// İzin verildi durumu
  ///
  /// In tr, this message translates to:
  /// **'Verildi'**
  String get granted;

  /// İzin verme butonu metni
  ///
  /// In tr, this message translates to:
  /// **'İzin Ver'**
  String get grantPermission;

  /// Konum seçimi ipucu metni
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakitlerini doğru alabilmemiz için önce bulunduğun konumu seçelim.'**
  String get locationHint;

  /// Başlatma butonu metni
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get start;

  /// Aylık namaz vakitleri başlığı
  ///
  /// In tr, this message translates to:
  /// **'Aylık Namaz Vakitleri'**
  String get monthlyPrayerTimes;

  /// Sonraki namaz vakti metni
  ///
  /// In tr, this message translates to:
  /// **'{prayerName} vaktine'**
  String nextPrayerTime(String prayerName);

  /// Vakit hesaplanıyor metni
  ///
  /// In tr, this message translates to:
  /// **'Vakit hesaplanıyor'**
  String get calculatingTime;

  /// Ramazan'da imsak hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vaktine {timeText} kaldı. Sahur için son dakikalar!'**
  String imsakReminderRamadan(String timeText);

  /// Normal imsak hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vaktine {timeText} kaldı. Fecr namazına hazırlanın.'**
  String imsakReminder(String timeText);

  /// Güneş doğuşu hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Güneş doğuşuna {timeText} kaldı. İmsak vakti sona eriyor.'**
  String sunriseReminder(String timeText);

  /// Cuma namazı hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazına {timeText} kaldı. Camiye gitmeyi unutmayın!'**
  String fridayPrayerReminder(String timeText);

  /// Öğle namazı hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Öğle namazına {timeText} kaldı. Abdest alıp hazırlanın.'**
  String zuhrReminder(String timeText);

  /// İkindi namazı hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'İkindi namazına {timeText} kaldı. Günün ikinci namazı için hazırlanın.'**
  String asrReminder(String timeText);

  /// İftar hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'İftar vaktine {timeText} kaldı! Akşam namazı ve iftar zamanı.'**
  String iftarReminder(String timeText);

  /// Akşam namazı hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Akşam namazına {timeText} kaldı. Maghrib vakti yaklaşıyor.'**
  String maghribReminder(String timeText);

  /// Yatsı namazı hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı namazına {timeText} kaldı. Günün son namazı için hazırlanın.'**
  String ishaReminder(String timeText);

  /// Genel namaz vakti hatırlatıcısı
  ///
  /// In tr, this message translates to:
  /// **'Namaz vaktine {timeText} kaldı.'**
  String prayerTimeReminder(String timeText);

  /// Kayıtlı konum olmadığında gösterilen metin
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı konum yok'**
  String get noSavedLocation;

  /// Özelleştirilebilir bildirimler başlığı
  ///
  /// In tr, this message translates to:
  /// **'Özelleştirilebilir bildirimler'**
  String get customizableNotifications;

  /// Tam zamanında metni
  ///
  /// In tr, this message translates to:
  /// **'Tam zamanında'**
  String get onTime;

  /// Kaydet butonu metni
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// İptal butonu metni
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get cancel;

  /// Dil seçici başlığı
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// Otomatik dil seçimi
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get automatic;

  /// Tema rengi menü başlığı
  ///
  /// In tr, this message translates to:
  /// **'Tema Rengi'**
  String get themeColor;

  /// Bildirimler menü başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notifications;

  /// İlerle butonu metni
  ///
  /// In tr, this message translates to:
  /// **'İlerle'**
  String get continueButton;

  /// Şehir arama placeholder metni
  ///
  /// In tr, this message translates to:
  /// **'Şehir ara...'**
  String get searchCity;

  /// Genel arama placeholder metni
  ///
  /// In tr, this message translates to:
  /// **'Ara...'**
  String get search;

  /// İmsak namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'İmsak'**
  String get imsak;

  /// Güneş doğuşu adı
  ///
  /// In tr, this message translates to:
  /// **'Güneş'**
  String get gunes;

  /// Öğle namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Öğle'**
  String get ogle;

  /// İkindi namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'İkindi'**
  String get ikindi;

  /// Akşam namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Akşam'**
  String get aksam;

  /// Yatsı namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı'**
  String get yatsi;

  /// Cuma namazı adı
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get cuma;

  /// Dua bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Dua Bildirimi'**
  String get duaNotification;

  /// Tarih başlığı
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get date;

  /// Dini günler başlığı
  ///
  /// In tr, this message translates to:
  /// **'Dini Gün ve Geceler'**
  String get religiousDays;

  /// Dini gün bulunamadı mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bu yıl için dini gün bulunamadı.'**
  String get noReligiousDaysThisYear;

  /// Onboarding özellik başlığı
  ///
  /// In tr, this message translates to:
  /// **'Diyanet kaynaklı vakitler'**
  String get diyanetPrayerTimes;

  /// Onboarding özellik alt başlığı
  ///
  /// In tr, this message translates to:
  /// **'Resmi kaynaklardan, doğrulanmış vakit verileriyle'**
  String get diyanetPrayerTimesSubtitle;

  /// Onboarding özellik başlığı
  ///
  /// In tr, this message translates to:
  /// **'GPS tabanlı kıble pusulası'**
  String get gpsQiblaCompass;

  /// Onboarding özellik alt başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sapma düzeltmesi ve gps ile her an canlı'**
  String get gpsQiblaCompassSubtitle;

  /// Onboarding özellik başlığı
  ///
  /// In tr, this message translates to:
  /// **'Zengin tema seçenekleri'**
  String get richThemeOptions;

  /// Onboarding özellik alt başlığı
  ///
  /// In tr, this message translates to:
  /// **'Gece/gündüz uyumlu, renk paletleriyle özgün tasarım'**
  String get richThemeOptionsSubtitle;

  /// Onboarding özellik başlığı
  ///
  /// In tr, this message translates to:
  /// **'Özelleştirilebilir bildirimler'**
  String get customizableNotificationsTitle;

  /// Onboarding özellik alt başlığı
  ///
  /// In tr, this message translates to:
  /// **'Esnek yapılandırma ile sana özel'**
  String get customizableNotificationsSubtitle;

  /// Özel tema modu
  ///
  /// In tr, this message translates to:
  /// **'Özel'**
  String get custom;

  /// Dinamik tema modu
  ///
  /// In tr, this message translates to:
  /// **'Dinamik'**
  String get dynamicMode;

  /// Sistem tema modu
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get system;

  /// Karanlık tema modu
  ///
  /// In tr, this message translates to:
  /// **'Karanlık'**
  String get dark;

  /// Dinamik tema açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Tema rengi namaz vaktine göre dinamik olarak ayarlanacaktır. Her namaz vakti için farklı bir renk kullanılır.'**
  String get dynamicThemeDescription;

  /// Siyah tema açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Tam siyah renk kullanılır. Oled ekranlarda pil tasarrufu sağlar.'**
  String get blackThemeDescription;

  /// Sistem teması açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Desteklenen cihazlarda renkler sistem renk paletine göre otomatik olarak ayarlanır.'**
  String get systemThemeDescription;

  /// Otomatik karartma başlığı
  ///
  /// In tr, this message translates to:
  /// **'Oto Karartma'**
  String get autoDarkMode;

  /// Ocak ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Oca'**
  String get january;

  /// Şubat ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Şub'**
  String get february;

  /// Mart ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Mar'**
  String get march;

  /// Nisan ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Nis'**
  String get april;

  /// Mayıs ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'May'**
  String get may;

  /// Haziran ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Haz'**
  String get june;

  /// Temmuz ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Tem'**
  String get july;

  /// Ağustos ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Ağu'**
  String get august;

  /// Eylül ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Eyl'**
  String get september;

  /// Ekim ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Eki'**
  String get october;

  /// Kasım ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Kas'**
  String get november;

  /// Aralık ayı kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get december;

  /// Otomatik karartma açıklaması
  ///
  /// In tr, this message translates to:
  /// **'00:00 ile güneş vakti arasında otomatik olarak karanlık temaya geçer'**
  String get autoDarkModeDescription;

  /// Kapat butonu metni
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// Kerahat vakti debug dialog başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kerahat Vakti Bilgisi'**
  String get kerahatTimeInfo;

  /// Saat birimi
  ///
  /// In tr, this message translates to:
  /// **'saat'**
  String get hour;

  /// Dakika birimi
  ///
  /// In tr, this message translates to:
  /// **'dakika'**
  String get minute;

  /// Dakika kısaltması
  ///
  /// In tr, this message translates to:
  /// **'dk'**
  String get minuteShort;

  /// Saniye birimi
  ///
  /// In tr, this message translates to:
  /// **'saniye'**
  String get second;

  /// Kerahat vakti uyarı metni
  ///
  /// In tr, this message translates to:
  /// **'Kerahat Vakti'**
  String get kerahatTime;

  /// Günlük içerik başlığı
  ///
  /// In tr, this message translates to:
  /// **'Günlük İçerik'**
  String get dailyContent;

  /// Günün ayeti başlığı
  ///
  /// In tr, this message translates to:
  /// **'Günün Ayeti'**
  String get dailyVerse;

  /// Günün hadisi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Günün Hadisi'**
  String get dailyHadith;

  /// Kıble başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kıble'**
  String get qibla;

  /// Kabe'ye mesafe metni
  ///
  /// In tr, this message translates to:
  /// **'Kabe\'ye mesafe'**
  String get distanceToKaaba;

  /// Hesaplanıyor metni
  ///
  /// In tr, this message translates to:
  /// **'Hesaplanıyor...'**
  String get calculating;

  /// Kalibrasyon uyarısı
  ///
  /// In tr, this message translates to:
  /// **'Cihazınızı kalibre etmeyi\nunutmayın'**
  String get calibrateDevice;

  /// Dakika önce metni
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika önce'**
  String minutesBefore(int minutes);

  /// Namaz vakitleri yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'{date} tarihinin namaz vakitleri yüklenirken hata oluştu: {error}'**
  String prayerTimesLoadError(String date, String error);

  /// Local dosya temizleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Local dosyalar temizlenirken hata oluştu: {error}'**
  String localFilesClearError(String error);

  /// Ülke listesi yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Ülke listesi yüklenirken hata oluştu: {error}'**
  String countryListLoadError(String error);

  /// Eyalet listesi yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Eyalet listesi yüklenirken hata oluştu: {error}'**
  String stateListLoadError(String error);

  /// Şehir listesi yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Şehir listesi yüklenirken hata oluştu: {error}'**
  String cityListLoadError(String error);

  /// Konum kaydetme hatası
  ///
  /// In tr, this message translates to:
  /// **'Konum kaydedilirken hata oluştu: {error}'**
  String locationSaveError(String error);

  /// Kaydedilen konum yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilen konum yüklenirken hata oluştu: {error}'**
  String savedLocationLoadError(String error);

  /// Konum başlatma hatası
  ///
  /// In tr, this message translates to:
  /// **'Konum başlatılırken hata oluştu: {error}'**
  String locationInitError(String error);

  /// Ülke arama hatası
  ///
  /// In tr, this message translates to:
  /// **'Ülke arama yapılırken hata oluştu: {error}'**
  String countrySearchError(String error);

  /// Eyalet arama hatası
  ///
  /// In tr, this message translates to:
  /// **'Eyalet arama yapılırken hata oluştu: {error}'**
  String stateSearchError(String error);

  /// Şehir arama hatası
  ///
  /// In tr, this message translates to:
  /// **'Şehir arama yapılırken hata oluştu: {error}'**
  String citySearchError(String error);

  /// Konum seçme hatası
  ///
  /// In tr, this message translates to:
  /// **'Konum seçilirken hata oluştu: {error}'**
  String locationSelectError(String error);

  /// Varsayılan konum yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan konum yüklenirken hata oluştu: {error}'**
  String defaultLocationLoadError(String error);

  /// GPS konumu alma hatası
  ///
  /// In tr, this message translates to:
  /// **'GPS konumu alınırken hata oluştu: {error}'**
  String gpsLocationFetchError(String error);

  /// Ülke verileri yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Ülke verileri yüklenirken hata oluştu: {error}'**
  String countryDataLoadError(String error);

  /// Eyalet verileri yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Eyalet verileri yüklenirken hata oluştu: {error}'**
  String stateDataLoadError(String error);

  /// Şehir verileri yükleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Şehir verileri yüklenirken hata oluştu: {error}'**
  String cityDataLoadError(String error);

  /// Konum kaydetme hatası (servis)
  ///
  /// In tr, this message translates to:
  /// **'Konum kaydedilirken hata oluştu: {error}'**
  String locationSaveDataError(String error);

  /// Kaydedilen konum temizleme hatası
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilen konum temizlenirken hata oluştu: {error}'**
  String savedLocationClearError(String error);

  /// Test bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'🔔 Test Bildirimi'**
  String get notificationTestTitle;

  /// Test bildirimi gövdesi
  ///
  /// In tr, this message translates to:
  /// **'Bildirim sistemi çalışıyor.'**
  String get notificationTestBody;

  /// Test dua bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'🤲 Test - Günün Duası'**
  String get notificationTestDuaTitle;

  /// İmsak bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'İmsak Vakti'**
  String get notificationImsakTitle;

  /// Güneş doğuşu bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Güneş Doğuşu'**
  String get notificationSunriseTitle;

  /// Öğle namazı bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Öğle Namazı'**
  String get notificationZuhrTitle;

  /// İkindi namazı bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'İkindi Namazı'**
  String get notificationAsrTitle;

  /// Akşam namazı bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Akşam Namazı'**
  String get notificationMaghribTitle;

  /// Yatsı namazı bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı Namazı'**
  String get notificationIshaTitle;

  /// Genel namaz vakti bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Namaz Vakti'**
  String get notificationPrayerTimeTitle;

  /// Ramazan'da imsak vakti anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vakti girdi! Sahur bitmiştir, oruç başladı.'**
  String get notificationImsakImmediateRamadan;

  /// İmsak vakti anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vakti girdi. Sabah namazı vakti başladı.'**
  String get notificationImsakImmediate;

  /// Güneş doğuşu anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Güneş doğdu! İmsak vakti sona erdi.'**
  String get notificationSunriseImmediate;

  /// Cuma günü öğle namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazı vakti girdi! Allah kabul etsin.'**
  String get notificationZuhrImmediateFriday;

  /// Öğle namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Öğle namazı vakti girdi. Allah kabul etsin.'**
  String get notificationZuhrImmediate;

  /// İkindi namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'İkindi namazı vakti girdi. Allah kabul etsin.'**
  String get notificationAsrImmediate;

  /// Ramazan'da akşam namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Akşam namazı vakti girdi! İftar zamanı geldi. 🌙'**
  String get notificationMaghribImmediateRamadan;

  /// Akşam namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Akşam namazı vakti girdi. Allah kabul etsin.'**
  String get notificationMaghribImmediate;

  /// Yatsı namazı anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı namazı vakti girdi. Allah kabul etsin.'**
  String get notificationIshaImmediate;

  /// Genel namaz vakti anlık mesajı
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakti girdi. Allah kabul etsin.'**
  String get notificationPrayerTimeImmediate;

  /// İmsak vakti önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vaktine {timeText} kaldı'**
  String notificationImsakAdvance(String timeText);

  /// İmsak vakti sonrası mesajı
  ///
  /// In tr, this message translates to:
  /// **'İmsak vaktinden {timeText} sonra'**
  String notificationImsakAfter(String timeText);

  /// Güneş doğuşu önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Güneş doğuşuna {timeText} kaldı'**
  String notificationSunriseAdvance(String timeText);

  /// Güneş doğuşu sonrası mesajı
  ///
  /// In tr, this message translates to:
  /// **'Güneş doğduktan {timeText} sonra'**
  String notificationSunriseAfter(String timeText);

  /// Cuma namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazına {timeText} kaldı'**
  String notificationZuhrAdvanceFriday(String timeText);

  /// Öğle namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Öğle namazına {timeText} kaldı'**
  String notificationZuhrAdvance(String timeText);

  /// İkindi namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'İkindi namazına {timeText} kaldı'**
  String notificationAsrAdvance(String timeText);

  /// Ramazan'da akşam namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'İftar vaktine {timeText} kaldı !'**
  String notificationMaghribAdvanceRamadan(String timeText);

  /// Akşam namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Akşam namazına {timeText} kaldı'**
  String notificationMaghribAdvance(String timeText);

  /// Yatsı namazı önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı namazına {timeText} kaldı'**
  String notificationIshaAdvance(String timeText);

  /// Genel namaz vakti önceden mesajı
  ///
  /// In tr, this message translates to:
  /// **'Namaz vaktine {timeText} kaldı.'**
  String notificationPrayerTimeAdvance(String timeText);

  /// Cuma namazı bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Cuma Namazı'**
  String get notificationFridayTitle;

  /// Cuma namazı 15 dakika öncesi mesajı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazına {timeText} kaldı. Camiye hareket etme zamanı!'**
  String notificationFridayMessage15(String timeText);

  /// Cuma namazı 30 dakika öncesi mesajı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazına {timeText} kaldı. Hazırlıklara başlayın.'**
  String notificationFridayMessage30(String timeText);

  /// Cuma namazı 30 dakikadan fazla öncesi mesajı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazına {timeText} kaldı. Abdest alıp hazırlanmayı unutmayın.'**
  String notificationFridayMessageMore(String timeText);

  /// Dua bildirimi başlığı
  ///
  /// In tr, this message translates to:
  /// **'🤲 Günün Duası'**
  String get notificationDuaTitle;

  /// Dakika metni
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika'**
  String timeMinutes(int minutes);

  /// Saat metni
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat'**
  String timeHours(int hours);

  /// Saat ve dakika metni
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat {minutes} dakika'**
  String timeHoursMinutes(int hours, int minutes);

  /// Ravza tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Ravza'**
  String get themeColorRavza;

  /// Harem tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Harem'**
  String get themeColorHarem;

  /// Aksa tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Aksa'**
  String get themeColorAksa;

  /// İmsak tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'İmsak'**
  String get themeColorImsak;

  /// Güneş tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Güneş'**
  String get themeColorGunes;

  /// Öğle tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Öğle'**
  String get themeColorOgle;

  /// İkindi tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'İkindi'**
  String get themeColorIkindi;

  /// Akşam tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Akşam'**
  String get themeColorAksam;

  /// Yatsı tema rengi adı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı'**
  String get themeColorYatsi;

  /// Varsayılan ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan'**
  String get soundDefault;

  /// Arap ezan sesi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Arap Ezan'**
  String get soundAdhan7;

  /// Ezan sesi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Ezan'**
  String get soundAdhan;

  /// Sela sesi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sela'**
  String get soundSela;

  /// Sert ton ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sert Ton'**
  String get soundHard;

  /// Yumuşak ton ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Yumuşak Ton'**
  String get soundSoft;

  /// Kuşlar sesi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Kuşlar'**
  String get soundBird;

  /// Alarm sesi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Alarm'**
  String get soundAlarm;

  /// Sessiz ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get soundSilent;

  /// Namazdan sonra sessiz moda alma seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Namazdan sonra sessiz mod'**
  String get silentModeAfterPrayer;

  /// Sessiz mod süresi başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sessiz mod süresi'**
  String get silentModeDuration;

  /// Kaç dakika metni
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika'**
  String minutesAfter(int minutes);

  /// Dakika sonra metni (bildirimler için)
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika sonra'**
  String minutesAfterNotification(int minutes);

  /// No description provided for @silentModePermissionRequired.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz mod izni gerekli. Ayarları açmak için dokunun.'**
  String get silentModePermissionRequired;

  /// No description provided for @religiousDayDaysUntil.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün sonra {name}'**
  String religiousDayDaysUntil(int days, String name);

  /// No description provided for @religiousDayTomorrow.
  ///
  /// In tr, this message translates to:
  /// **'Yarın {name}'**
  String religiousDayTomorrow(String name);

  /// No description provided for @religiousDayToday.
  ///
  /// In tr, this message translates to:
  /// **'{name} mübarek olsun'**
  String religiousDayToday(String name);

  /// No description provided for @religiousDayTodayEid.
  ///
  /// In tr, this message translates to:
  /// **'Hayırlı Bayramlar'**
  String get religiousDayTodayEid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
