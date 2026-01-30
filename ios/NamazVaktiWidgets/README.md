# iOS Widget Extension Kurulum Kılavuzu

Bu belge, iOS widget extension'ı Xcode projesine nasıl ekleyeceğinizi açıklar.

## Önkoşullar

- Xcode 14.0 veya üzeri
- iOS 14.0 minimum deployment target
- Apple Developer hesabı (App Groups için)

## Kurulum Adımları

### 1. Xcode'da Widget Extension Ekleme

1. Xcode'da `ios/Runner.xcworkspace` dosyasını açın
2. **File → New → Target** menüsüne gidin
3. **Widget Extension** seçin ve **Next**'e tıklayın
4. Aşağıdaki bilgileri girin:
   - **Product Name:** `NamazVaktiWidgets`
   - **Team:** Kendi team'inizi seçin
   - **Bundle Identifier:** `com.osm.namazvaktim.NamazVaktiWidgets`
   - **Include Live Activity:** İşaretsiz bırakın
   - **Include Configuration Intent:** İşaretsiz bırakın
5. **Finish**'e tıklayın
6. **Activate** diyaloğunda "Activate" seçin

### 2. Oluşturulan Dosyaları Değiştirme

Xcode otomatik olarak bazı dosyalar oluşturacak. Bunları bu klasördeki dosyalarla değiştirin:

1. Xcode'un oluşturduğu `NamazVaktiWidgets.swift` dosyasını silin
2. Bu klasördeki tüm `.swift` dosyalarını Xcode projesine sürükleyip bırakın:
   - `NamazVaktiWidgets.swift`
   - `SharedData.swift`
   - `PrayerTimesWidget.swift`
   - `CalendarWidget.swift`
   - `TextOnlyWidget.swift`
3. "Copy items if needed" işaretli olduğundan emin olun
4. Target olarak `NamazVaktiWidgets` seçili olduğundan emin olun

### 3. App Groups Yapılandırması

Her iki target için de App Groups etkinleştirin:

#### Runner Target:
1. **Runner** target'ı seçin
2. **Signing & Capabilities** sekmesine gidin
3. **+ Capability** butonuna tıklayın
4. **App Groups** seçin
5. `group.com.osm.namazvaktim` ekleyin

#### NamazVaktiWidgets Target:
1. **NamazVaktiWidgets** target'ı seçin
2. **Signing & Capabilities** sekmesine gidin
3. **+ Capability** butonuna tıklayın
4. **App Groups** seçin
5. `group.com.osm.namazvaktim` ekleyin

### 4. Entitlements Dosyalarını Bağlama

1. **Runner** target → **Build Settings** → "Code Signing Entitlements" araması yapın
2. Değeri `Runner/Runner.entitlements` olarak ayarlayın
3. **NamazVaktiWidgets** target → **Build Settings** → "Code Signing Entitlements" araması yapın  
4. Değeri `NamazVaktiWidgets/NamazVaktiWidgets.entitlements` olarak ayarlayın

### 5. Build Settings Kontrolü

**NamazVaktiWidgets** target için:

1. **Build Settings** → **Deployment** → **iOS Deployment Target**: `14.0`
2. **Build Settings** → **Swift Compiler** → **Swift Language Version**: `5.0`

### 6. Info.plist Kontrolü

`NamazVaktiWidgets/Info.plist` dosyasının doğru yapılandırıldığından emin olun:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

### 7. Build ve Test

1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Product → Build** (Cmd+B)
3. iOS cihazda veya simulatörde çalıştırın
4. Ana ekrana uzun basın → Widget'lar → "Namaz Vakti" araması yapın

## Widget Türleri

### 1. Namaz Vakti Widget (Küçük & Orta)
- Sonraki namaz vaktine geri sayım gösterir
- Dinamik tema rengi desteği
- Özelleştirilebilir arka plan opaklığı

### 2. Takvim Widget (Küçük)
- Hicri ve Miladi tarihi gösterir
- Sadece Hicri veya sadece Miladi gösterme seçeneği

### 3. Sadece Metin Widget (Küçük)
- Arkaplan olmadan minimal görünüm
- Özelleştirilebilir metin boyutu

## Sorun Giderme

### Widget Görünmüyor
- App Groups'un her iki target'ta da doğru yapılandırıldığından emin olun
- Build'i temizleyip yeniden yapın
- Cihazı yeniden başlatın

### Veri Güncellenmiyor
- App Group identifier'ın (`group.com.osm.namazvaktim`) her iki tarafta da aynı olduğundan emin olun
- Flutter uygulamasının `saveWidgetData` metodunu çağırdığından emin olun

### Build Hataları
- Swift dosyalarının NamazVaktiWidgets target'ına eklendiğinden emin olun
- WidgetKit framework'ünün bağlandığından emin olun

## Notlar

- Widget'lar iOS 14.0 ve üzeri sürümlerde çalışır
- Widget timeline her saat başı otomatik güncellenir
- Uygulama arka plandayken widget verileri App Groups üzerinden paylaşılır
