// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Namaz Vakitleri';

  @override
  String get locationNotSelected => 'Konum seçilmedi';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get error => 'Hata Oluştu';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get noInternetConnection => 'İnternet bağlantısı yok.';

  @override
  String get dataNotFound => 'Veri bulunamadı.';

  @override
  String get serverError =>
      'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';

  @override
  String get unknownError => 'Bilinmeyen hata oluştu.';

  @override
  String get gpsLocationNotAvailable => 'GPS konumu alınamadı';

  @override
  String get qiblaDirectionCalculationFailed => 'Kıble yönü hesaplanamadı';

  @override
  String get locationRefreshFailed => 'Konum yenilenemedi';

  @override
  String get compassNeedsCalibration => 'Pusula kalibre edilmeli';

  @override
  String get compassCalibrationRequired => 'Pusula kalibrasyonu gerekli';

  @override
  String get cityNotFoundForLocation => 'Konumunuz için şehir bulunamadı';

  @override
  String get contentNotFound => 'İçerik bulunamadı';

  @override
  String get retryLowercase => 'Tekrar dene';

  @override
  String get automaticLocation => 'Otomatik Konum';

  @override
  String get gettingLocation => 'Konum Alınıyor...';

  @override
  String get notificationPermission => 'Bildirim İzni';

  @override
  String get notificationPermissionDescription =>
      'Vakit bildirimleri gönderebilmek için gereklidir.';

  @override
  String get locationPermission => 'Konum İzni';

  @override
  String get locationPermissionDescription =>
      'Konuma göre doğru namaz vakitlerini göstermek için gereklidir.';

  @override
  String get batteryOptimization => 'Pil Optimizasyonundan Çıkar (Android)';

  @override
  String get batteryOptimizationDescription =>
      'Arka planda güvenilir bildirim/hatırlatıcı için önerilir.';

  @override
  String get granted => 'Verildi';

  @override
  String get grantPermission => 'İzin Ver';

  @override
  String get locationHint =>
      'Namaz vakitlerini doğru alabilmemiz için önce bulunduğun konumu seçelim.';

  @override
  String get start => 'Başla';

  @override
  String get monthlyPrayerTimes => 'Aylık Namaz Vakitleri';

  @override
  String nextPrayerTime(String prayerName) {
    return '$prayerName vaktine';
  }

  @override
  String get calculatingTime => 'Vakit hesaplanıyor';

  @override
  String imsakReminderRamadan(String timeText) {
    return 'İmsak vaktine $timeText kaldı. Sahur için son dakikalar!';
  }

  @override
  String imsakReminder(String timeText) {
    return 'İmsak vaktine $timeText kaldı. Fecr namazına hazırlanın.';
  }

  @override
  String sunriseReminder(String timeText) {
    return 'Güneş doğuşuna $timeText kaldı. İmsak vakti sona eriyor.';
  }

  @override
  String fridayPrayerReminder(String timeText) {
    return 'Cuma namazına $timeText kaldı. Camiye gitmeyi unutmayın!';
  }

  @override
  String zuhrReminder(String timeText) {
    return 'Öğle namazına $timeText kaldı. Abdest alıp hazırlanın.';
  }

  @override
  String asrReminder(String timeText) {
    return 'İkindi namazına $timeText kaldı. Günün ikinci namazı için hazırlanın.';
  }

  @override
  String iftarReminder(String timeText) {
    return 'İftar vaktine $timeText kaldı! Akşam namazı ve iftar zamanı.';
  }

  @override
  String maghribReminder(String timeText) {
    return 'Akşam namazına $timeText kaldı. Maghrib vakti yaklaşıyor.';
  }

  @override
  String ishaReminder(String timeText) {
    return 'Yatsı namazına $timeText kaldı. Günün son namazı için hazırlanın.';
  }

  @override
  String prayerTimeReminder(String timeText) {
    return 'Namaz vaktine $timeText kaldı.';
  }

  @override
  String get noSavedLocation => 'Kayıtlı konum yok';

  @override
  String get customizableNotifications => 'Özelleştirilebilir bildirimler';

  @override
  String get onTime => 'Tam zamanında';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get language => 'Dil';

  @override
  String get automatic => 'Otomatik';

  @override
  String get themeColor => 'Tema Rengi';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get continueButton => 'İlerle';

  @override
  String get searchCity => 'Şehir ara...';

  @override
  String get search => 'Ara...';

  @override
  String get imsak => 'İmsak';

  @override
  String get gunes => 'Güneş';

  @override
  String get ogle => 'Öğle';

  @override
  String get ikindi => 'İkindi';

  @override
  String get aksam => 'Akşam';

  @override
  String get yatsi => 'Yatsı';

  @override
  String get cuma => 'Cuma';

  @override
  String get duaNotification => 'Dua Bildirimi';

  @override
  String get date => 'Tarih';

  @override
  String get religiousDays => 'Dini Gün ve Geceler';

  @override
  String get noReligiousDaysThisYear => 'Bu yıl için dini gün bulunamadı.';

  @override
  String get diyanetPrayerTimes => 'Diyanet kaynaklı vakitler';

  @override
  String get diyanetPrayerTimesSubtitle =>
      'Resmi kaynaklardan, doğrulanmış vakit verileriyle';

  @override
  String get gpsQiblaCompass => 'GPS tabanlı kıble pusulası';

  @override
  String get gpsQiblaCompassSubtitle =>
      'Sapma düzeltmesi ve gps ile her an canlı';

  @override
  String get richThemeOptions => 'Zengin tema seçenekleri';

  @override
  String get richThemeOptionsSubtitle =>
      'Gece/gündüz uyumlu, renk paletleriyle özgün tasarım';

  @override
  String get customizableNotificationsTitle => 'Özelleştirilebilir bildirimler';

  @override
  String get customizableNotificationsSubtitle =>
      'Esnek yapılandırma ile sana özel';

  @override
  String get custom => 'Özel';

  @override
  String get dynamicMode => 'Dinamik';

  @override
  String get customColor => 'Özel Renk';

  @override
  String get dark => 'Karanlık';

  @override
  String get dynamicThemeDescription =>
      'Tema rengi namaz vaktine göre dinamik olarak ayarlanacaktır. Her namaz vakti için farklı bir renk kullanılır.';

  @override
  String get blackThemeDescription =>
      'Tam siyah renk kullanılır. Oled ekranlarda pil tasarrufu sağlar.';

  @override
  String get customColorDescription =>
      'Renk seçici ile istediğiniz rengi seçin ve uygulamaya uygulayın.';

  @override
  String get autoDarkMode => 'Oto Karartma';

  @override
  String get january => 'Oca';

  @override
  String get february => 'Şub';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Nis';

  @override
  String get may => 'May';

  @override
  String get june => 'Haz';

  @override
  String get july => 'Tem';

  @override
  String get august => 'Ağu';

  @override
  String get september => 'Eyl';

  @override
  String get october => 'Eki';

  @override
  String get november => 'Kas';

  @override
  String get december => 'Ara';

  @override
  String get autoDarkModeDescription =>
      '00:00 ile güneş vakti arasında otomatik olarak karanlık temaya geçer';

  @override
  String get close => 'Kapat';

  @override
  String get kerahatTimeInfo => 'Kerahat Vakti Bilgisi';

  @override
  String get hour => 'saat';

  @override
  String get minute => 'dakika';

  @override
  String get minuteShort => 'dk';

  @override
  String get second => 'saniye';

  @override
  String get kerahatTime => 'Kerahat Vakti';

  @override
  String get dailyContent => 'Günlük İçerik';

  @override
  String get dailyVerse => 'Günün Ayeti';

  @override
  String get dailyHadith => 'Günün Hadisi';

  @override
  String get qibla => 'Kıble';

  @override
  String get distanceToKaaba => 'Kabe\'ye mesafe';

  @override
  String get calculating => 'Hesaplanıyor...';

  @override
  String get calibrateDevice => 'Cihazınızı kalibre etmeyi\nunutmayın';

  @override
  String minutesBefore(int minutes) {
    return '$minutes dakika önce';
  }

  @override
  String prayerTimesLoadError(String date, String error) {
    return '$date tarihinin namaz vakitleri yüklenirken hata oluştu: $error';
  }

  @override
  String localFilesClearError(String error) {
    return 'Local dosyalar temizlenirken hata oluştu: $error';
  }

  @override
  String countryListLoadError(String error) {
    return 'Ülke listesi yüklenirken hata oluştu: $error';
  }

  @override
  String stateListLoadError(String error) {
    return 'Eyalet listesi yüklenirken hata oluştu: $error';
  }

  @override
  String cityListLoadError(String error) {
    return 'Şehir listesi yüklenirken hata oluştu: $error';
  }

  @override
  String locationSaveError(String error) {
    return 'Konum kaydedilirken hata oluştu: $error';
  }

  @override
  String savedLocationLoadError(String error) {
    return 'Kaydedilen konum yüklenirken hata oluştu: $error';
  }

  @override
  String locationInitError(String error) {
    return 'Konum başlatılırken hata oluştu: $error';
  }

  @override
  String countrySearchError(String error) {
    return 'Ülke arama yapılırken hata oluştu: $error';
  }

  @override
  String stateSearchError(String error) {
    return 'Eyalet arama yapılırken hata oluştu: $error';
  }

  @override
  String citySearchError(String error) {
    return 'Şehir arama yapılırken hata oluştu: $error';
  }

  @override
  String locationSelectError(String error) {
    return 'Konum seçilirken hata oluştu: $error';
  }

  @override
  String defaultLocationLoadError(String error) {
    return 'Varsayılan konum yüklenirken hata oluştu: $error';
  }

  @override
  String gpsLocationFetchError(String error) {
    return 'GPS konumu alınırken hata oluştu: $error';
  }

  @override
  String countryDataLoadError(String error) {
    return 'Ülke verileri yüklenirken hata oluştu: $error';
  }

  @override
  String stateDataLoadError(String error) {
    return 'Eyalet verileri yüklenirken hata oluştu: $error';
  }

  @override
  String cityDataLoadError(String error) {
    return 'Şehir verileri yüklenirken hata oluştu: $error';
  }

  @override
  String locationSaveDataError(String error) {
    return 'Konum kaydedilirken hata oluştu: $error';
  }

  @override
  String savedLocationClearError(String error) {
    return 'Kaydedilen konum temizlenirken hata oluştu: $error';
  }

  @override
  String get notificationTestTitle => '🔔 Test Bildirimi';

  @override
  String get notificationTestBody => 'Bildirim sistemi çalışıyor.';

  @override
  String get notificationTestDuaTitle => '🤲 Test - Günün Duası';

  @override
  String get notificationImsakTitle => 'İmsak Vakti';

  @override
  String get notificationSunriseTitle => 'Güneş Doğuşu';

  @override
  String get notificationZuhrTitle => 'Öğle Namazı';

  @override
  String get notificationAsrTitle => 'İkindi Namazı';

  @override
  String get notificationMaghribTitle => 'Akşam Namazı';

  @override
  String get notificationIshaTitle => 'Yatsı Namazı';

  @override
  String get notificationPrayerTimeTitle => 'Namaz Vakti';

  @override
  String get notificationImsakImmediateRamadan =>
      'İmsak vakti girdi! Sahur bitmiştir, oruç başladı.';

  @override
  String get notificationImsakImmediate =>
      'İmsak vakti girdi. Sabah namazı vakti başladı.';

  @override
  String get notificationSunriseImmediate =>
      'Güneş doğdu! İmsak vakti sona erdi.';

  @override
  String get notificationZuhrImmediateFriday =>
      'Cuma namazı vakti girdi! Allah kabul etsin.';

  @override
  String get notificationZuhrImmediate =>
      'Öğle namazı vakti girdi. Allah kabul etsin.';

  @override
  String get notificationAsrImmediate =>
      'İkindi namazı vakti girdi. Allah kabul etsin.';

  @override
  String get notificationMaghribImmediateRamadan =>
      'Akşam namazı vakti girdi! İftar zamanı geldi. 🌙';

  @override
  String get notificationMaghribImmediate =>
      'Akşam namazı vakti girdi. Allah kabul etsin.';

  @override
  String get notificationIshaImmediate =>
      'Yatsı namazı vakti girdi. Allah kabul etsin.';

  @override
  String get notificationPrayerTimeImmediate =>
      'Namaz vakti girdi. Allah kabul etsin.';

  @override
  String notificationImsakAdvance(String timeText) {
    return 'İmsak vaktine $timeText kaldı';
  }

  @override
  String notificationImsakAfter(String timeText) {
    return 'İmsak vaktinden $timeText sonra';
  }

  @override
  String notificationSunriseAdvance(String timeText) {
    return 'Güneş doğuşuna $timeText kaldı';
  }

  @override
  String notificationSunriseAfter(String timeText) {
    return 'Güneş doğduktan $timeText sonra';
  }

  @override
  String notificationZuhrAdvanceFriday(String timeText) {
    return 'Cuma namazına $timeText kaldı';
  }

  @override
  String notificationZuhrAdvance(String timeText) {
    return 'Öğle namazına $timeText kaldı';
  }

  @override
  String notificationAsrAdvance(String timeText) {
    return 'İkindi namazına $timeText kaldı';
  }

  @override
  String notificationMaghribAdvanceRamadan(String timeText) {
    return 'İftar vaktine $timeText kaldı !';
  }

  @override
  String notificationMaghribAdvance(String timeText) {
    return 'Akşam namazına $timeText kaldı';
  }

  @override
  String notificationIshaAdvance(String timeText) {
    return 'Yatsı namazına $timeText kaldı';
  }

  @override
  String notificationPrayerTimeAdvance(String timeText) {
    return 'Namaz vaktine $timeText kaldı.';
  }

  @override
  String get notificationFridayTitle => 'Cuma Namazı';

  @override
  String notificationFridayMessage15(String timeText) {
    return 'Cuma namazına $timeText kaldı. Camiye hareket etme zamanı!';
  }

  @override
  String notificationFridayMessage30(String timeText) {
    return 'Cuma namazına $timeText kaldı. Hazırlıklara başlayın.';
  }

  @override
  String notificationFridayMessageMore(String timeText) {
    return 'Cuma namazına $timeText kaldı. Abdest alıp hazırlanmayı unutmayın.';
  }

  @override
  String get notificationDuaTitle => '🤲 Günün Duası';

  @override
  String timeMinutes(int minutes) {
    return '$minutes dakika';
  }

  @override
  String timeHours(int hours) {
    return '$hours saat';
  }

  @override
  String timeHoursMinutes(int hours, int minutes) {
    return '$hours saat $minutes dakika';
  }

  @override
  String get themeColorRavza => 'Ravza';

  @override
  String get themeColorHarem => 'Harem';

  @override
  String get themeColorAksa => 'Aksa';

  @override
  String get themeColorImsak => 'İmsak';

  @override
  String get themeColorGunes => 'Güneş';

  @override
  String get themeColorOgle => 'Öğle';

  @override
  String get themeColorIkindi => 'İkindi';

  @override
  String get themeColorAksam => 'Akşam';

  @override
  String get themeColorYatsi => 'Yatsı';

  @override
  String get soundDefault => 'Varsayılan';

  @override
  String get soundAdhan7 => 'Arap Ezan';

  @override
  String get soundAdhan => 'Ezan';

  @override
  String get soundSela => 'Sela';

  @override
  String get soundHard => 'Sert Ton';

  @override
  String get soundSoft => 'Yumuşak Ton';

  @override
  String get soundBird => 'Kuşlar';

  @override
  String get soundAlarm => 'Alarm';

  @override
  String get soundSilent => 'Sessiz';

  @override
  String get silentModeAfterPrayer => 'Namazdan sonra sessiz mod';

  @override
  String get silentModeDuration => 'Sessiz mod süresi';

  @override
  String minutesAfter(int minutes) {
    return '$minutes dakika';
  }

  @override
  String minutesAfterNotification(int minutes) {
    return '$minutes dakika sonra';
  }

  @override
  String get silentModePermissionRequired =>
      'Sessiz mod izni gerekli. Ayarları açmak için dokunun.';

  @override
  String get silentModePermissionDescription =>
      'Sessiz mod özelliğini kullanmak için \"Bildirim Erişimi\" izni gereklidir. Ayarlar sayfasına yönlendirileceksiniz.';

  @override
  String get goToSettings => 'Ayarlara Git';

  @override
  String get silentModePermissionSnackbar =>
      'Lütfen ayarlardan izin verin, ardından sessiz modu tekrar açın.';

  @override
  String religiousDayDaysUntil(int days, String name) {
    return '$days gün sonra $name';
  }

  @override
  String religiousDayTomorrow(String name) {
    return 'Yarın $name';
  }

  @override
  String religiousDayToday(String name) {
    return '$name mübarek olsun';
  }

  @override
  String get religiousDayTodayEid => 'Hayırlı Bayramlar';
}
