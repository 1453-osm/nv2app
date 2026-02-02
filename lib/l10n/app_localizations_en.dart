// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Prayer Times';

  @override
  String get locationNotSelected => 'Location not selected';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error Occurred';

  @override
  String get retry => 'Retry';

  @override
  String get noInternetConnection => 'No internet connection.';

  @override
  String get dataNotFound => 'Data not found.';

  @override
  String get serverError => 'Server error occurred. Please try again later.';

  @override
  String get unknownError => 'Unknown error occurred.';

  @override
  String get gpsLocationNotAvailable => 'GPS location not available';

  @override
  String get qiblaDirectionCalculationFailed =>
      'Qibla direction calculation failed';

  @override
  String get locationRefreshFailed => 'Location refresh failed';

  @override
  String get compassNeedsCalibration => 'Compass needs calibration';

  @override
  String get compassCalibrationRequired => 'Compass calibration required';

  @override
  String get cityNotFoundForLocation => 'City not found for your location';

  @override
  String get contentNotFound => 'Content not found';

  @override
  String get retryLowercase => 'retry';

  @override
  String get automaticLocation => 'Automatic Location';

  @override
  String get gettingLocation => 'Getting Location...';

  @override
  String get notificationPermission => 'Notification Permission';

  @override
  String get notificationPermissionDescription =>
      'Required to send prayer time notifications.';

  @override
  String get locationPermission => 'Location Permission';

  @override
  String get locationPermissionDescription =>
      'Required to show accurate prayer times based on location.';

  @override
  String get batteryOptimization =>
      'Remove from Battery Optimization (Android)';

  @override
  String get batteryOptimizationDescription =>
      'Recommended for reliable background notifications/reminders.';

  @override
  String get granted => 'Granted';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get locationHint =>
      'Let\'s select your location first so we can get accurate prayer times.';

  @override
  String get start => 'Start';

  @override
  String get monthlyPrayerTimes => 'Monthly Prayer Times';

  @override
  String nextPrayerTime(String prayerName) {
    return '$prayerName time';
  }

  @override
  String get calculatingTime => 'Calculating time';

  @override
  String imsakReminderRamadan(String timeText) {
    return '$timeText until Imsak time. Last minutes for Suhur!';
  }

  @override
  String imsakReminder(String timeText) {
    return '$timeText until Imsak time. Prepare for Fajr prayer.';
  }

  @override
  String sunriseReminder(String timeText) {
    return '$timeText until sunrise. Imsak time is ending.';
  }

  @override
  String fridayPrayerReminder(String timeText) {
    return '$timeText until Friday prayer. Don\'t forget to go to the mosque!';
  }

  @override
  String zuhrReminder(String timeText) {
    return '$timeText until Zuhr prayer. Perform ablution and prepare.';
  }

  @override
  String asrReminder(String timeText) {
    return '$timeText until Asr prayer. Prepare for the second prayer of the day.';
  }

  @override
  String iftarReminder(String timeText) {
    return '$timeText until Iftar time! Maghrib prayer and Iftar time.';
  }

  @override
  String maghribReminder(String timeText) {
    return '$timeText until Maghrib prayer. Maghrib time is approaching.';
  }

  @override
  String ishaReminder(String timeText) {
    return '$timeText until Isha prayer. Prepare for the last prayer of the day.';
  }

  @override
  String prayerTimeReminder(String timeText) {
    return '$timeText until prayer time.';
  }

  @override
  String get noSavedLocation => 'No saved location';

  @override
  String get customizableNotifications => 'Customizable notifications';

  @override
  String get onTime => 'On time';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';

  @override
  String get automatic => 'Automatic';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get notifications => 'Notifications';

  @override
  String get continueButton => 'Continue';

  @override
  String get searchCity => 'Search city...';

  @override
  String get search => 'Search...';

  @override
  String get imsak => 'Imsak';

  @override
  String get gunes => 'Sunrise';

  @override
  String get ogle => 'Zuhr';

  @override
  String get ikindi => 'Asr';

  @override
  String get aksam => 'Maghrib';

  @override
  String get yatsi => 'Isha';

  @override
  String get cuma => 'Friday';

  @override
  String get duaNotification => 'Prayer Notification';

  @override
  String get date => 'Date';

  @override
  String get religiousDays => 'Religious Days and Nights';

  @override
  String get noReligiousDaysThisYear =>
      'No religious days found for this year.';

  @override
  String get diyanetPrayerTimes => 'Diyanet prayer times';

  @override
  String get diyanetPrayerTimesSubtitle =>
      'Official sources, verified prayer time data';

  @override
  String get gpsQiblaCompass => 'GPS-based Qibla compass';

  @override
  String get gpsQiblaCompassSubtitle =>
      'Deviation correction and live GPS tracking';

  @override
  String get richThemeOptions => 'Rich theme options';

  @override
  String get richThemeOptionsSubtitle =>
      'Night/day compatible, unique design with color palettes';

  @override
  String get customizableNotificationsTitle => 'Customizable notifications';

  @override
  String get customizableNotificationsSubtitle =>
      'Flexible configuration tailored to you';

  @override
  String get custom => 'Custom';

  @override
  String get dynamicMode => 'Dynamic';

  @override
  String get customColor => 'Custom Color';

  @override
  String get dark => 'Dark';

  @override
  String get dynamicThemeDescription =>
      'Theme color will be set dynamically according to prayer time. A different color is used for each prayer time.';

  @override
  String get blackThemeDescription =>
      'Pure black color is used. Provides battery savings on OLED screens.';

  @override
  String get customColorDescription =>
      'Choose your desired color with the color picker and apply it to the app.';

  @override
  String get autoDarkMode => 'Auto Dark Mode';

  @override
  String get january => 'Jan';

  @override
  String get february => 'Feb';

  @override
  String get march => 'Mar';

  @override
  String get april => 'Apr';

  @override
  String get may => 'May';

  @override
  String get june => 'Jun';

  @override
  String get july => 'Jul';

  @override
  String get august => 'Aug';

  @override
  String get september => 'Sep';

  @override
  String get october => 'Oct';

  @override
  String get november => 'Nov';

  @override
  String get december => 'Dec';

  @override
  String get autoDarkModeDescription =>
      'Automatically switches to dark mode between 00:00 and sunrise time';

  @override
  String get close => 'Close';

  @override
  String get kerahatTimeInfo => 'Kerahat Time Information';

  @override
  String get hour => 'hour';

  @override
  String get minute => 'minute';

  @override
  String get minuteShort => 'min';

  @override
  String get second => 'second';

  @override
  String get kerahatTime => 'Kerahat Time';

  @override
  String get dailyContent => 'Daily Content';

  @override
  String get dailyVerse => 'Verse of the Day';

  @override
  String get dailyHadith => 'Hadith of the Day';

  @override
  String get qibla => 'Qibla';

  @override
  String get distanceToKaaba => 'Distance to Kaaba';

  @override
  String get calculating => 'Calculating...';

  @override
  String get calibrateDevice => 'Don\'t forget to\ncalibrate your device';

  @override
  String minutesBefore(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String prayerTimesLoadError(String date, String error) {
    return 'Error loading prayer times for $date: $error';
  }

  @override
  String localFilesClearError(String error) {
    return 'Error clearing local files: $error';
  }

  @override
  String countryListLoadError(String error) {
    return 'Error loading country list: $error';
  }

  @override
  String stateListLoadError(String error) {
    return 'Error loading state list: $error';
  }

  @override
  String cityListLoadError(String error) {
    return 'Error loading city list: $error';
  }

  @override
  String locationSaveError(String error) {
    return 'Error saving location: $error';
  }

  @override
  String savedLocationLoadError(String error) {
    return 'Error loading saved location: $error';
  }

  @override
  String locationInitError(String error) {
    return 'Error initializing location: $error';
  }

  @override
  String countrySearchError(String error) {
    return 'Error searching countries: $error';
  }

  @override
  String stateSearchError(String error) {
    return 'Error searching states: $error';
  }

  @override
  String citySearchError(String error) {
    return 'Error searching cities: $error';
  }

  @override
  String locationSelectError(String error) {
    return 'Error selecting location: $error';
  }

  @override
  String defaultLocationLoadError(String error) {
    return 'Error loading default location: $error';
  }

  @override
  String gpsLocationFetchError(String error) {
    return 'Error fetching GPS location: $error';
  }

  @override
  String countryDataLoadError(String error) {
    return 'Error loading country data: $error';
  }

  @override
  String stateDataLoadError(String error) {
    return 'Error loading state data: $error';
  }

  @override
  String cityDataLoadError(String error) {
    return 'Error loading city data: $error';
  }

  @override
  String locationSaveDataError(String error) {
    return 'Error saving location data: $error';
  }

  @override
  String savedLocationClearError(String error) {
    return 'Error clearing saved location: $error';
  }

  @override
  String get notificationTestTitle => '🔔 Test Notification';

  @override
  String get notificationTestBody => 'Notification system is working.';

  @override
  String get notificationTestDuaTitle => '🤲 Test - Prayer of the Day';

  @override
  String get notificationImsakTitle => 'Imsak Time';

  @override
  String get notificationSunriseTitle => 'Sunrise';

  @override
  String get notificationZuhrTitle => 'Zuhr Prayer';

  @override
  String get notificationAsrTitle => 'Asr Prayer';

  @override
  String get notificationMaghribTitle => 'Maghrib Prayer';

  @override
  String get notificationIshaTitle => 'Isha Prayer';

  @override
  String get notificationPrayerTimeTitle => 'Prayer Time';

  @override
  String get notificationImsakImmediateRamadan =>
      'Imsak time has arrived! Suhur has ended, fasting has begun.';

  @override
  String get notificationImsakImmediate =>
      'Imsak time has arrived. Fajr prayer time has begun.';

  @override
  String get notificationSunriseImmediate =>
      'Sun has risen! Imsak time has ended.';

  @override
  String get notificationZuhrImmediateFriday =>
      'Friday prayer time has arrived! May Allah accept.';

  @override
  String get notificationZuhrImmediate =>
      'Zuhr prayer time has arrived. May Allah accept.';

  @override
  String get notificationAsrImmediate =>
      'Asr prayer time has arrived. May Allah accept.';

  @override
  String get notificationMaghribImmediateRamadan =>
      'Maghrib prayer time has arrived! Iftar time has come. 🌙';

  @override
  String get notificationMaghribImmediate =>
      'Maghrib prayer time has arrived. May Allah accept.';

  @override
  String get notificationIshaImmediate =>
      'Isha prayer time has arrived. May Allah accept.';

  @override
  String get notificationPrayerTimeImmediate =>
      'Prayer time has arrived. May Allah accept.';

  @override
  String notificationImsakAdvance(String timeText) {
    return '$timeText until Imsak time';
  }

  @override
  String notificationImsakAfter(String timeText) {
    return '$timeText after Imsak';
  }

  @override
  String notificationSunriseAdvance(String timeText) {
    return '$timeText until sunrise';
  }

  @override
  String notificationSunriseAfter(String timeText) {
    return '$timeText after Sunrise';
  }

  @override
  String notificationZuhrAdvanceFriday(String timeText) {
    return '$timeText until Friday prayer';
  }

  @override
  String notificationZuhrAdvance(String timeText) {
    return '$timeText until Zuhr prayer';
  }

  @override
  String notificationAsrAdvance(String timeText) {
    return '$timeText until Asr prayer';
  }

  @override
  String notificationMaghribAdvanceRamadan(String timeText) {
    return '$timeText until Iftar time!';
  }

  @override
  String notificationMaghribAdvance(String timeText) {
    return '$timeText until Maghrib prayer';
  }

  @override
  String notificationIshaAdvance(String timeText) {
    return '$timeText until Isha prayer';
  }

  @override
  String notificationPrayerTimeAdvance(String timeText) {
    return '$timeText until prayer time.';
  }

  @override
  String get notificationFridayTitle => 'Friday Prayer';

  @override
  String notificationFridayMessage15(String timeText) {
    return '$timeText until Friday prayer. Time to head to the mosque!';
  }

  @override
  String notificationFridayMessage30(String timeText) {
    return '$timeText until Friday prayer. Start preparing.';
  }

  @override
  String notificationFridayMessageMore(String timeText) {
    return '$timeText until Friday prayer. Don\'t forget to perform ablution and prepare.';
  }

  @override
  String get notificationDuaTitle => '🤲 Prayer of the Day';

  @override
  String timeMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String timeHours(int hours) {
    return '$hours hours';
  }

  @override
  String timeHoursMinutes(int hours, int minutes) {
    return '$hours hours $minutes minutes';
  }

  @override
  String get themeColorRavza => 'Ravza';

  @override
  String get themeColorHarem => 'Harem';

  @override
  String get themeColorAksa => 'Al-Aqsa';

  @override
  String get themeColorImsak => 'Imsak';

  @override
  String get themeColorGunes => 'Sunrise';

  @override
  String get themeColorOgle => 'Zuhr';

  @override
  String get themeColorIkindi => 'Asr';

  @override
  String get themeColorAksam => 'Maghrib';

  @override
  String get themeColorYatsi => 'Isha';

  @override
  String get soundDefault => 'Default';

  @override
  String get soundAdhan7 => 'Arabic Adhan';

  @override
  String get soundAdhan => 'Adhan';

  @override
  String get soundSela => 'Sela';

  @override
  String get soundHard => 'Hard Tone';

  @override
  String get soundSoft => 'Soft Tone';

  @override
  String get soundBird => 'Birds';

  @override
  String get soundAlarm => 'Alarm';

  @override
  String get soundSilent => 'Silent';

  @override
  String get silentModeAfterPrayer => 'Silent mode after prayer';

  @override
  String get silentModeDuration => 'Silent mode duration';

  @override
  String minutesAfter(int minutes) {
    return '$minutes minutes after';
  }

  @override
  String minutesAfterNotification(int minutes) {
    return '$minutes minutes after';
  }

  @override
  String get silentModePermissionRequired =>
      'Silent mode permission required. Tap to open settings.';

  @override
  String get silentModePermissionDescription =>
      '\"Notification Access\" permission is required to use silent mode. You will be redirected to settings.';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get silentModePermissionSnackbar =>
      'Please grant permission in settings, then enable silent mode again.';

  @override
  String religiousDayDaysUntil(int days, String name) {
    return '$days days until $name';
  }

  @override
  String religiousDayTomorrow(String name) {
    return 'Tomorrow is $name';
  }

  @override
  String religiousDayToday(String name) {
    return 'Blessed $name';
  }

  @override
  String get religiousDayTodayEid => 'Happy Eid';
}
