// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'أوقات الصلاة';

  @override
  String get locationNotSelected => 'الموقع غير محدد';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get error => 'حدث خطأ';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get noInternetConnection => 'لا يوجد اتصال بالإنترنت.';

  @override
  String get dataNotFound => 'البيانات غير موجودة.';

  @override
  String get serverError => 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.';

  @override
  String get unknownError => 'حدث خطأ غير معروف.';

  @override
  String get gpsLocationNotAvailable => 'موقع GPS غير متاح';

  @override
  String get qiblaDirectionCalculationFailed => 'فشل حساب اتجاه القبلة';

  @override
  String get locationRefreshFailed => 'فشل تحديث الموقع';

  @override
  String get compassNeedsCalibration => 'يحتاج البوصلة إلى المعايرة';

  @override
  String get compassCalibrationRequired => 'معايرة البوصلة مطلوبة';

  @override
  String get cityNotFoundForLocation => 'لم يتم العثور على المدينة لموقعك';

  @override
  String get contentNotFound => 'المحتوى غير موجود';

  @override
  String get retryLowercase => 'إعادة المحاولة';

  @override
  String get automaticLocation => 'الموقع التلقائي';

  @override
  String get gettingLocation => 'جاري الحصول على الموقع...';

  @override
  String get notificationPermission => 'إذن الإشعارات';

  @override
  String get notificationPermissionDescription =>
      'مطلوب لإرسال إشعارات أوقات الصلاة.';

  @override
  String get locationPermission => 'إذن الموقع';

  @override
  String get locationPermissionDescription =>
      'مطلوب لعرض أوقات الصلاة الدقيقة بناءً على الموقع.';

  @override
  String get batteryOptimization => 'إزالة من تحسين البطارية (Android)';

  @override
  String get batteryOptimizationDescription =>
      'موصى به للإشعارات/التذكيرات الموثوقة في الخلفية.';

  @override
  String get granted => 'ممنوح';

  @override
  String get grantPermission => 'منح الإذن';

  @override
  String get locationHint =>
      'دعنا نحدد موقعك أولاً حتى نتمكن من الحصول على أوقات الصلاة الدقيقة.';

  @override
  String get start => 'ابدأ';

  @override
  String get monthlyPrayerTimes => 'أوقات الصلاة الشهرية';

  @override
  String nextPrayerTime(String prayerName) {
    return 'وقت $prayerName';
  }

  @override
  String get calculatingTime => 'جاري حساب الوقت';

  @override
  String imsakReminderRamadan(String timeText) {
    return 'متبقي $timeText حتى وقت الإمساك. الدقائق الأخيرة للسحور!';
  }

  @override
  String imsakReminder(String timeText) {
    return 'متبقي $timeText حتى وقت الإمساك. استعد لصلاة الفجر.';
  }

  @override
  String sunriseReminder(String timeText) {
    return 'متبقي $timeText حتى شروق الشمس. وقت الإمساك ينتهي.';
  }

  @override
  String fridayPrayerReminder(String timeText) {
    return 'متبقي $timeText حتى صلاة الجمعة. لا تنس الذهاب إلى المسجد!';
  }

  @override
  String zuhrReminder(String timeText) {
    return 'متبقي $timeText حتى صلاة الظهر. توضأ واستعد.';
  }

  @override
  String asrReminder(String timeText) {
    return 'متبقي $timeText حتى صلاة العصر. استعد للصلاة الثانية في اليوم.';
  }

  @override
  String iftarReminder(String timeText) {
    return 'متبقي $timeText حتى وقت الإفطار! صلاة المغرب ووقت الإفطار.';
  }

  @override
  String maghribReminder(String timeText) {
    return 'متبقي $timeText حتى صلاة المغرب. وقت المغرب يقترب.';
  }

  @override
  String ishaReminder(String timeText) {
    return 'متبقي $timeText حتى صلاة العشاء. استعد لآخر صلاة في اليوم.';
  }

  @override
  String prayerTimeReminder(String timeText) {
    return 'متبقي $timeText حتى وقت الصلاة.';
  }

  @override
  String get noSavedLocation => 'لا يوجد موقع محفوظ';

  @override
  String get customizableNotifications => 'إشعارات قابلة للتخصيص';

  @override
  String get onTime => 'في الوقت المحدد';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get language => 'اللغة';

  @override
  String get themeColor => 'لون المظهر';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get continueButton => 'تابع';

  @override
  String get searchCity => 'ابحث عن مدينة...';

  @override
  String get search => 'بحث...';

  @override
  String get imsak => 'الإمساك';

  @override
  String get gunes => 'الشروق';

  @override
  String get ogle => 'الظهر';

  @override
  String get ikindi => 'العصر';

  @override
  String get aksam => 'المغرب';

  @override
  String get yatsi => 'العشاء';

  @override
  String get cuma => 'الجمعة';

  @override
  String get duaNotification => 'إشعار الدعاء';

  @override
  String get date => 'التاريخ';

  @override
  String get religiousDays => 'الأيام والليالي الدينية';

  @override
  String get noReligiousDaysThisYear =>
      'لم يتم العثور على أيام دينية لهذا العام.';

  @override
  String get diyanetPrayerTimes => 'أوقات الصلاة من الديانات';

  @override
  String get diyanetPrayerTimesSubtitle =>
      'مصادر رسمية، بيانات أوقات صلاة موثقة';

  @override
  String get gpsQiblaCompass => 'بوصلة القبلة القائمة على GPS';

  @override
  String get gpsQiblaCompassSubtitle =>
      'تصحيح الانحراف والتتبع المباشر عبر GPS';

  @override
  String get richThemeOptions => 'خيارات مظهر غنية';

  @override
  String get richThemeOptionsSubtitle =>
      'متوافق مع الليل/النهار، تصميم فريد مع لوحات ألوان';

  @override
  String get customizableNotificationsTitle => 'إشعارات قابلة للتخصيص';

  @override
  String get customizableNotificationsSubtitle => 'تكوين مرن مصمم خصيصاً لك';

  @override
  String get custom => 'مخصص';

  @override
  String get dynamicMode => 'ديناميكي';

  @override
  String get system => 'النظام';

  @override
  String get dark => 'داكن';

  @override
  String get dynamicThemeDescription =>
      'سيتم تعيين لون المظهر ديناميكياً وفقاً لوقت الصلاة. يتم استخدام لون مختلف لكل وقت صلاة.';

  @override
  String get blackThemeDescription =>
      'يتم استخدام اللون الأسود النقي. يوفر توفير البطارية على شاشات OLED.';

  @override
  String get systemThemeDescription =>
      'على الأجهزة المدعومة، يتم تعديل الألوان تلقائياً وفقاً لوحة ألوان النظام.';

  @override
  String get autoDarkMode => 'الوضع الداكن التلقائي';

  @override
  String get january => 'يناير';

  @override
  String get february => 'فبراير';

  @override
  String get march => 'مارس';

  @override
  String get april => 'أبريل';

  @override
  String get may => 'مايو';

  @override
  String get june => 'يونيو';

  @override
  String get july => 'يوليو';

  @override
  String get august => 'أغسطس';

  @override
  String get september => 'سبتمبر';

  @override
  String get october => 'أكتوبر';

  @override
  String get november => 'نوفمبر';

  @override
  String get december => 'ديسمبر';

  @override
  String get autoDarkModeDescription =>
      'يتحول تلقائياً إلى الوضع الداكن بين 00:00 ووقت شروق الشمس';

  @override
  String get close => 'إغلاق';

  @override
  String get kerahatTimeInfo => 'معلومات وقت الكراهة';

  @override
  String get hour => 'ساعة';

  @override
  String get minute => 'دقيقة';

  @override
  String get minuteShort => 'د';

  @override
  String get second => 'ثانية';

  @override
  String get kerahatTime => 'وقت الكراهة';

  @override
  String get dailyContent => 'المحتوى اليومي';

  @override
  String get dailyVerse => 'آية اليوم';

  @override
  String get dailyHadith => 'حديث اليوم';

  @override
  String get qibla => 'القبلة';

  @override
  String get distanceToKaaba => 'المسافة إلى الكعبة';

  @override
  String get calculating => 'جاري الحساب...';

  @override
  String get calibrateDevice => 'لا تنس معايرة\nجهازك';

  @override
  String minutesBefore(int minutes) {
    return 'قبل $minutes دقيقة';
  }

  @override
  String prayerTimesLoadError(String date, String error) {
    return 'حدث خطأ أثناء تحميل أوقات الصلاة لـ $date: $error';
  }

  @override
  String localFilesClearError(String error) {
    return 'حدث خطأ أثناء مسح الملفات المحلية: $error';
  }

  @override
  String countryListLoadError(String error) {
    return 'حدث خطأ أثناء تحميل قائمة البلدان: $error';
  }

  @override
  String stateListLoadError(String error) {
    return 'حدث خطأ أثناء تحميل قائمة الولايات: $error';
  }

  @override
  String cityListLoadError(String error) {
    return 'حدث خطأ أثناء تحميل قائمة المدن: $error';
  }

  @override
  String locationSaveError(String error) {
    return 'حدث خطأ أثناء حفظ الموقع: $error';
  }

  @override
  String savedLocationLoadError(String error) {
    return 'حدث خطأ أثناء تحميل الموقع المحفوظ: $error';
  }

  @override
  String locationInitError(String error) {
    return 'حدث خطأ أثناء تهيئة الموقع: $error';
  }

  @override
  String countrySearchError(String error) {
    return 'حدث خطأ أثناء البحث عن البلدان: $error';
  }

  @override
  String stateSearchError(String error) {
    return 'حدث خطأ أثناء البحث عن الولايات: $error';
  }

  @override
  String citySearchError(String error) {
    return 'حدث خطأ أثناء البحث عن المدن: $error';
  }

  @override
  String locationSelectError(String error) {
    return 'حدث خطأ أثناء اختيار الموقع: $error';
  }

  @override
  String defaultLocationLoadError(String error) {
    return 'حدث خطأ أثناء تحميل الموقع الافتراضي: $error';
  }

  @override
  String gpsLocationFetchError(String error) {
    return 'حدث خطأ أثناء جلب موقع GPS: $error';
  }

  @override
  String countryDataLoadError(String error) {
    return 'حدث خطأ أثناء تحميل بيانات البلد: $error';
  }

  @override
  String stateDataLoadError(String error) {
    return 'حدث خطأ أثناء تحميل بيانات الولاية: $error';
  }

  @override
  String cityDataLoadError(String error) {
    return 'حدث خطأ أثناء تحميل بيانات المدينة: $error';
  }

  @override
  String locationSaveDataError(String error) {
    return 'حدث خطأ أثناء حفظ بيانات الموقع: $error';
  }

  @override
  String savedLocationClearError(String error) {
    return 'حدث خطأ أثناء مسح الموقع المحفوظ: $error';
  }
}
