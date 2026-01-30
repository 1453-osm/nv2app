import 'package:audioplayers/audioplayers.dart';
import '../utils/app_logger.dart';

/// Bildirim sesleri için MVVM uyumlu servis.
/// Seçilen ses kimliğini platform tarafında çalınacak asset yoluna çevirir.
class NotificationSoundService {
  /// Desteklenen ses kimliği -> asset yolu eşlemesi.
  static const Map<String, String> _soundAssetMap = <String, String>{
    'default': '', // platform varsayılanı, özel yol yok
    'silent': '',  // sessiz: ses yolları gönderilmez
    'alarm': 'assets/notifications/alarm.mp3',
    'bird': 'assets/notifications/bird.mp3',
    'soft': 'assets/notifications/soft.mp3',
    'hard': 'assets/notifications/hard.mp3',
    'sela': 'assets/notifications/sela.mp3',
    // Ezan sesleri: eğer map'te bulunmazsa dinamik olarak resolve edilir (aşağıdaki logic)
  };

  /// UI/VM tarafındaki `soundId` değerini asset yoluna dönüştürür.
  /// '' dönerse platform varsayılanını (veya sessizi) kullanın.
  static String resolveAssetPath(String soundId) {
    // Önce açık eşlemeye bak
    final mapped = _soundAssetMap[soundId];
    if (mapped != null) return mapped;

    // Dinamik: adhan*, adhanarabic → assets/notifications/$soundId.mp3
    if (soundId.startsWith('adhan')) {
      return 'assets/notifications/$soundId.mp3';
    }
    return '';
  }

  /// Bu ses kimliği özel asset gerektiriyor mu?
  static bool requiresCustomAsset(String soundId) {
    final path = resolveAssetPath(soundId);
    return path.isNotEmpty;
  }

  /// Desteklenen ses seçenekleri listesi (UI doğrulama için kullanılabilir).
  static List<String> supportedSoundIds() => _soundAssetMap.keys.toList(growable: false);

  /// Debug yardımcı: eşlemeyi logla (geliştirme sırasında).
  static void debugLogMap() {
    AppLogger.debug('Sound asset map: $_soundAssetMap', tag: 'NotificationSound');
  }

  // --- Preview playback (for settings selection) ---
  static final AudioPlayer _previewPlayer = AudioPlayer();

  /// Seçilen `soundId` için kısa bir önizleme çalar.
  /// 'default' ve 'silent' için çalmaz, varsa mevcut önizlemeyi durdurur.
  static Future<void> previewSound(String soundId) async {
    try {
      // Varsayılan veya sessiz: yalnızca durdur
      if (soundId == 'default' || soundId == 'silent') {
        await stopPreview();
        return;
      }

      final String assetPath = resolveAssetPath(soundId);
      if (assetPath.isEmpty) {
        // Haritalanmamış (ör: adhanX henüz yok) → sessizce çık
        await stopPreview();
        return;
      }

      // AudioPlayers AssetSource, pubspec'teki assets köküne göre relatif yol ister
      final String sourcePath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;

      await _previewPlayer.stop();
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.setVolume(1.0);
      await _previewPlayer.play(AssetSource(sourcePath));
    } catch (_) {
      // Sessiz başarısızlık: UI'yi bozma
    }
  }

  /// Önizleme sesini durdurur.
  static Future<void> stopPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
  }
}


