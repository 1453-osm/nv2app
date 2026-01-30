import 'package:flutter/foundation.dart';

/// Uygulama genelinde kullanılan loglama servisi.
/// Debug modda detaylı log, release modda sessiz çalışır.
class AppLogger {
  AppLogger._(); // Instantiation engelle

  static const String _tag = 'NV2';

  /// Debug seviyesinde log
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      _log('DEBUG', tag ?? _tag, message);
    }
  }

  /// Info seviyesinde log
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      _log('INFO', tag ?? _tag, message);
    }
  }

  /// Warning seviyesinde log
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      _log('WARN', tag ?? _tag, message);
    }
  }

  /// Error seviyesinde log
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _log('ERROR', tag ?? _tag, message);
      if (error != null) {
        debugPrint('  └─ Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('  └─ StackTrace:\n$stackTrace');
      }
    }
  }

  /// Servis başarı logları için
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      _log('OK', tag ?? _tag, message);
    }
  }

  /// Network istekleri için
  static void network(String method, String url, {int? statusCode}) {
    if (kDebugMode) {
      final status = statusCode != null ? ' [$statusCode]' : '';
      _log('NET', 'HTTP', '$method $url$status');
    }
  }

  /// Performans ölçümleri için
  static void performance(String operation, Duration duration) {
    if (kDebugMode) {
      _log('PERF', 'TIMER', '$operation completed in ${duration.inMilliseconds}ms');
    }
  }

  /// Timer başlatır ve Stopwatch döndürür
  static Stopwatch startTimer(String operation) {
    if (kDebugMode) {
      _log('PERF', 'TIMER', '$operation started...');
    }
    return Stopwatch()..start();
  }

  /// Timer'ı durdurur ve süreyi loglar
  static void stopTimer(Stopwatch stopwatch, String operation) {
    stopwatch.stop();
    performance(operation, stopwatch.elapsed);
  }

  static void _log(String level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[$timestamp][$level][$tag] $message');
  }
}

/// Performans ölçümü için extension
extension StopwatchExtension on Stopwatch {
  void logElapsed(String operation) {
    AppLogger.performance(operation, elapsed);
  }
}
