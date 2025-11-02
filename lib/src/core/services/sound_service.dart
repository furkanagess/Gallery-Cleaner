import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _scannerPlayer = AudioPlayer(); // Scanner için ayrı player

  /// Silme ses efektini çalar
  Future<void> playDeleteSound() async {
    try {
      await _audioPlayer.play(AssetSource('sound/delete.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      print('Ses çalma hatası: $e');
    }
  }

  /// Tutma ses efektini çalar
  Future<void> playKeepSound() async {
    try {
      await _audioPlayer.play(AssetSource('sound/keep.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      print('Ses çalma hatası: $e');
    }
  }

  /// Scanner sesini çalar (loop)
  Future<void> playScannerSound() async {
    try {
      await _scannerPlayer.setReleaseMode(ReleaseMode.loop); // Loop modunda çal
      await _scannerPlayer.play(AssetSource('sound/scanner.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      print('Scanner ses çalma hatası: $e');
    }
  }

  /// Scanner sesini durdur
  Future<void> stopScannerSound() async {
    try {
      await _scannerPlayer.stop();
    } catch (e) {
      // Hata sessizce yok sayılır
      print('Scanner ses durdurma hatası: $e');
    }
  }

  /// Ses çalmayı durdur
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // Hata sessizce yok sayılır
    }
  }

  /// Dispose
  void dispose() {
    _audioPlayer.dispose();
    _scannerPlayer.dispose();
  }
}

