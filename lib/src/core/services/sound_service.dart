import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _scannerPlayer = AudioPlayer(); // Scanner için ayrı player
  final List<AudioPlayer> _deletePlayers = []; // Delete sesleri için player listesi
  bool _isScannerPlaying = false; // Scanner sesinin çalıp çalmadığını takip et

  /// Silme ses efektini çalar (üst üste çalınabilir)
  Future<void> playDeleteSound() async {
    try {
      // Her delete sesi için yeni bir AudioPlayer oluştur
      final deletePlayer = AudioPlayer();
      _deletePlayers.add(deletePlayer);
      
      // Ses bittiğinde player'ı temizle
      deletePlayer.onPlayerComplete.listen((_) {
        deletePlayer.dispose();
        _deletePlayers.remove(deletePlayer);
      });
      
      await deletePlayer.play(AssetSource('sound/delete.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      print('Ses çalma hatası: $e');
    }
  }

  /// Tutma ses efektini çalar
  Future<void> playKeepSound() async {
    try {
      // Eğer ses zaten çalıyorsa tekrar başlatma
      final state = await _audioPlayer.state;
      if (state == PlayerState.playing) {
        return;
      }
      await _audioPlayer.play(AssetSource('sound/keep.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      print('Ses çalma hatası: $e');
    }
  }

  /// Scanner sesini çalar (loop)
  Future<void> playScannerSound() async {
    try {
      // Eğer scanner sesi zaten çalıyorsa tekrar başlatma
      if (_isScannerPlaying) {
        final state = await _scannerPlayer.state;
        if (state == PlayerState.playing) {
          return;
        }
      }
      
      _isScannerPlaying = true;
      await _scannerPlayer.setReleaseMode(ReleaseMode.loop); // Loop modunda çal
      await _scannerPlayer.play(AssetSource('sound/scanner.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      _isScannerPlaying = false;
      print('Scanner ses çalma hatası: $e');
    }
  }

  /// Scanner sesini durdur
  Future<void> stopScannerSound() async {
    try {
      if (!_isScannerPlaying) {
        return;
      }
      
      _isScannerPlaying = false;
      final state = await _scannerPlayer.state;
      if (state == PlayerState.playing) {
      await _scannerPlayer.stop();
      }
    } catch (e) {
      // Hata sessizce yok sayılır
      _isScannerPlaying = false;
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
    // Tüm delete player'ları temizle
    for (final player in _deletePlayers) {
      player.dispose();
    }
    _deletePlayers.clear();
  }
}

