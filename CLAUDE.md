# CLAUDE.md

Bu dosya Claude Code (claude.ai/code) için bu depoyla çalışırken rehberlik sağlar.

**ÖNEMLİ: Lütfen tüm yanıtlarınızı TÜRKÇE olarak verin.**

## Proje Özeti

**nv2** Android/iOS için Dart-Flutter ile yazılmış İslami namaz vakitleri uygulamasıdır. Günlük namaz vakitlerini, kıble yönünü, Hicri takvim tarihlerini, dini günleri gösterir ve azan sesleriyle namaz bildirimleri sağlar.

## Derleme ve Geliştirme Komutları

```bash
# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır (debug modu)
flutter run

# Belirli cihazda çalıştır
flutter devices
flutter run -d <device_id>

# Release APK derle
flutter build apk --release

# iOS derle
flutter build ios --release

# Kod analizini çalıştır
flutter analyze

# Yerelleştirmeleri oluştur (lib/l10n/*.arb dosyalarını değiştirdikten sonra)
flutter gen-l10n

# Başlatıcı simgelerini oluştur (pubspec.yaml'daki flutter_icons'ı değiştirdikten sonra)
flutter pub run flutter_launcher_icons
```

## Mimari Yapı

Uygulama **MVVM (Model-View-ViewModel)** tasarım deseniyle Provider kütüphanesi kullanılarak geliştirilmiştir.

### Ana Mimari Katmanlar

```
lib/
├── main.dart              # Uygulama giriş, MultiProvider kurulumu, Firebase başlatma
├── models/                # Veri sınıfları (PrayerTime, Location, ReligiousDay)
├── viewmodels/            # ChangeNotifier sınıfları (iş mantığı)
├── views/                 # UI widget'ları/ekranlar
├── services/              # Veri çekme, bildirimler, kalıcılık
├── data/                  # Statik veriler (Hicri aylar, dini gün çevirileri)
├── l10n/                  # Yerelleştirme (Türkçe, İngilizce, Arapça)
└── utils/                 # Sabitler, yardımcı işlevler (RTL, Arapça rakamlar)
```

### Temel Veri Akışı

1. **LocationService** konum verilerini `assets/locations/*.json` dosyalarından yükler ve SharedPreferences ile kalıcı hale getirir
2. **PrayerTimesService** Google Cloud Storage'dan (`storage.googleapis.com/namazvaktimdepo`) yıllık namaz verilerini indirer ve yerel olarak önbelleğe alır
3. **PrayerTimesViewModel** veri yüklemesini, geri sayım zamanlayıcılarını, Hicri tarih yerelleştirmesini ve widget senkronizasyonunu yönetir
4. **NotificationSchedulerService** Android bildirimlerini `flutter_local_notifications` ile yapılandırarak kesin alarmlar ve özel azan sesleriyle zamanlar

### Önemli Desenler

- **Tembel Provider Başlatma**: `PrayerTimesViewModel`, `QiblaViewModel` gibi ViewModeller ihtiyaç halinde oluşturulur
- **ProxyProvider Kullanımı**: `PrayerTimesViewModel` ve `DailyContentViewModel` `ChangeNotifierProxyProvider` ile `LocaleService` güncellemelerini alırlar
- **Widget Bridge**: Android widget'ları `WidgetBridgeService` üzerinden MethodChannel (`com.osm.namazvaktim/widgets`) kullanılarak güncellenir
- **Skeleton Loading**: ViewModellerdeki `_showSkeleton` deseni, şehir değiştirilirken yükleme durumlarını gösterir

### Temel Servisler

| Servis | Görev |
|--------|-------|
| `PrayerTimesService` | Uzak JSON'dan namaz vakitlerini indir/önbelleğe al |
| `LocationService` | Ülke/İl/Şehir verileri, GPS konumu, kalıcılık |
| `NotificationSchedulerService` | Namaz bildirimleri, kesin alarmlar |
| `ThemeService` | Namaz vakitine göre dinamik tema uygulaması |
| `LocaleService` | Yerelleştirme (RTL desteğiyle: Türkçe, İngilizce, Arapça) |
| `ReligiousDaysService` | Hicri takvim verilerinden dini günleri tespit et |

### Yerelleştirme

Yerelleştirme Flutter'ın gen-l10n aracı ve ARB dosyaları kullanılarak yapılır:
- Şablon: `lib/l10n/app_tr.arb`
- Çıktı: `lib/l10n/app_localizations*.dart`
- Desteklenen Diller: Türkçe (`tr`), İngilizce (`en`), Arapça (`ar`)

Arapça yerelleştirmesi içerir:
- RTL mizanpaj desteği (`RTLHelper`)
- Arapça rakam dönüştürme (`arabic_numbers_helper.dart` içindeki `localizeNumerals`)

### Yerel (Native) Entegrasyon

- **Android Widget'ları**: Küçük geri sayım widget'ı, takvim widget'ı `WidgetBridgeService` aracılığıyla güncellenir
- **Kesin Alarmlar**: Uygulama kapatıldığında bile güvenilir bildirimler için yerel Android `AlarmManager` kullanır
- **Firebase**: Günlük içerik (dua, hadis) için Firestore, yalnızca mobil platformlarda başlatılır

### Sabitler ve Yapılandırma

- **AppKeys**: `lib/utils/app_keys.dart` - Tüm SharedPreferences anahtarları ve magic string'ler
- **AppLogger**: `lib/utils/app_logger.dart` - Debug/release loglama servisi
- **Result Pattern**: `lib/utils/result.dart` - Railway-oriented error handling (Success/Failure)
- Animasyon sabitleri: `lib/utils/constants.dart` - `AnimationConstants` sınıfı
- Tema renkleri: `SettingsConstants.themeColors`, `SettingsConstants.prayerColors`
- Bildirim sesleri: `assets/notifications/` içindeki özel sesler (azan, alarm, kuşlar, vb.)

### Utility Sınıfları

| Utility | Görev |
|---------|-------|
| `AppKeys` | SharedPreferences anahtarları, dil kodları, bildirim ID'leri |
| `AppLogger` | Debug modda detaylı log, release modda sessiz |
| `Result<T>` | Success/Failure pattern ile güvenli error handling |
| `AppException` | Kategorize edilmiş exception sınıfı |

### Test Yapısı

```bash
# Tüm testleri çalıştır
flutter test

# Belirli test dosyasını çalıştır
flutter test test/models/location_model_test.dart

# Coverage ile test
flutter test --coverage
```

Test dosyaları:
- `test/models/` - Model sınıfları testleri
- `test/utils/` - Utility sınıfları testleri

### Ortam Kurulumu

Uygulama dotenv yapılandırması için `assets/env` dosyasına gereksinim duyar (Firebase, API anahtarları). Bu dosya başlangıçta `flutter_dotenv` aracılığıyla yüklenir.

### Kod Standartları

- **Magic String Yasağı**: Tüm anahtarlar `AppKeys` sınıfında tanımlanmalı
- **Loglama**: `print()` yerine `AppLogger` kullanılmalı
- **Error Handling**: Try-catch yerine `Result` pattern tercih edilmeli
- **Model Equality**: `==` ve `hashCode` override edilmeli
- **Dokümantasyon**: Karmaşık metodlar için doc comment yazılmalı
