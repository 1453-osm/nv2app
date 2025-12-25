import 'package:flutter_test/flutter_test.dart';
import 'package:nv2/utils/app_keys.dart';

void main() {
  group('AppKeys', () {
    test('notification key generators work correctly', () {
      expect(AppKeys.notificationEnabledKey('imsak'), 'nv_notif_imsak_enabled');
      expect(AppKeys.notificationMinutesKey('imsak'), 'nv_notif_imsak_minutes');
      expect(AppKeys.notificationSoundKey('imsak'), 'nv_notif_imsak_sound');
    });

    test('supported languages are correct', () {
      expect(AppKeys.supportedLanguages, contains('tr'));
      expect(AppKeys.supportedLanguages, contains('en'));
      expect(AppKeys.supportedLanguages, contains('ar'));
      expect(AppKeys.supportedLanguages.length, 3);
    });

    test('prayer names are correct', () {
      expect(AppKeys.prayerNames, contains('İmsak'));
      expect(AppKeys.prayerNames, contains('Güneş'));
      expect(AppKeys.prayerNames, contains('Öğle'));
      expect(AppKeys.prayerNames, contains('İkindi'));
      expect(AppKeys.prayerNames, contains('Akşam'));
      expect(AppKeys.prayerNames, contains('Yatsı'));
      expect(AppKeys.prayerNames.length, 6);
    });

    test('notification IDs are correct', () {
      expect(AppKeys.notifIdImsak, 'imsak');
      expect(AppKeys.notifIdGunes, 'gunes');
      expect(AppKeys.notifIdOgle, 'ogle');
      expect(AppKeys.notifIdIkindi, 'ikindi');
      expect(AppKeys.notifIdAksam, 'aksam');
      expect(AppKeys.notifIdYatsi, 'yatsi');
      expect(AppKeys.notifIdCuma, 'cuma');
      expect(AppKeys.notifIdDua, 'dua');
    });

    test('asset paths are correct', () {
      expect(AppKeys.assetsEnvPath, 'assets/env');
      expect(AppKeys.assetsLocationsPath, 'assets/locations/');
      expect(AppKeys.assetsDualarPath, 'assets/notifications/dualar.json');
    });
  });
}
