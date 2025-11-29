import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Merkezi logger yapılandırması
/// Tüm uygulama logları bu logger üzerinden yönetilir
class AppLogger {
  static Logger? _instance;

  /// Logger instance'ını al (singleton)
  static Logger get instance {
    _instance ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2, // Stack trace'de gösterilecek method sayısı
        errorMethodCount: 8, // Hata durumunda gösterilecek method sayısı
        lineLength: 120, // Log satır uzunluğu
        colors: true, // Renkli çıktı
        printEmojis: true, // Emoji kullanımı
        printTime: true, // Zaman damgası
      ),
      level: kDebugMode
          ? Level.debug
          : Level
                .info, // Debug modda tüm loglar, release'de sadece info ve üzeri
    );
    return _instance!;
  }

  /// Debug log (detaylı bilgi)
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info log (bilgilendirme)
  static void i(String message) {
    instance.i(message);
  }

  /// Warning log (uyarı)
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error log (hata)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal log (kritik hata)
  static void f(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.f(message, error: error, stackTrace: stackTrace);
  }

  /// Tag'li log (servis/modül bazlı loglama)
  static void logWithTag(
    String tag,
    String message, {
    Level level = Level.debug,
  }) {
    final taggedMessage = '[$tag] $message';
    switch (level) {
      case Level.debug:
        d(taggedMessage);
      case Level.info:
        i(taggedMessage);
      case Level.warning:
        w(taggedMessage);
      case Level.error:
        e(taggedMessage);
      case Level.fatal:
        f(taggedMessage);
      default:
        d(taggedMessage);
    }
  }

  /// Logger'ı temizle (test için)
  static void dispose() {
    _instance = null;
  }
}

/// Logger extension'ları - kolay kullanım için
extension LoggerExtensions on String {
  /// Debug log
  void logD([String? tag]) {
    if (tag != null) {
      AppLogger.logWithTag(tag, this, level: Level.debug);
    } else {
      AppLogger.d(this);
    }
  }

  /// Info log
  void logI([String? tag]) {
    if (tag != null) {
      AppLogger.logWithTag(tag, this, level: Level.info);
    } else {
      AppLogger.i(this);
    }
  }

  /// Warning log
  void logW([String? tag]) {
    if (tag != null) {
      AppLogger.logWithTag(tag, this, level: Level.warning);
    } else {
      AppLogger.w(this);
    }
  }

  /// Error log
  void logE([String? tag, dynamic error, StackTrace? stackTrace]) {
    if (tag != null) {
      AppLogger.logWithTag(tag, this, level: Level.error);
      if (error != null) {
        AppLogger.e('Error details: $error', error, stackTrace);
      }
    } else {
      AppLogger.e(this, error, stackTrace);
    }
  }
}
