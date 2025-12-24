import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _isFirstLaunchKey = 'is_first_launch';

  /// Uygulamanın ilk kez açılıp açılmadığını kontrol eder
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  /// İlk kurulum tamamlandı olarak işaretler
  Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }
} 