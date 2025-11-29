import 'package:audioplayers/audioplayers.dart';
import 'preferences_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _scannerPlayer = AudioPlayer(); // Scanner için ayrı player
  final List<AudioPlayer> _deletePlayers = []; // Delete sesleri için player listesi
  bool _isScannerPlaying = false; // Scanner sesinin çalıp çalmadığını takip et
  bool? _isSoundEnabledCache; // Ses durumu cache'i - gereksiz async çağrıları önlemek için
  final PreferencesService _prefsService = PreferencesService();
  
  /// Ses durumunu cache'den oku veya yükle
  Future<bool> _getSoundEnabled() async {
    if (_isSoundEnabledCache != null) {
      return _isSoundEnabledCache!;
    }
    _isSoundEnabledCache = await _prefsService.isScanSoundEnabled();
    return _isSoundEnabledCache!;
  }
  
  /// Ses durumu cache'ini güncelle
  void _updateSoundEnabledCache(bool enabled) {
    _isSoundEnabledCache = enabled;
  }
  
  /// Cache'i başlangıçta yükle (opsiyonel - performans için)
  Future<void> initializeCache() async {
    if (_isSoundEnabledCache == null) {
      _isSoundEnabledCache = await _prefsService.isScanSoundEnabled();
    }
  }

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
      // Eğer ses zaten çalıyorsa tekrar başlatma - optimize et
      try {
        final state = _audioPlayer.state;
        if (state == PlayerState.playing) {
          return;
        }
      } catch (_) {
        // State okunamazsa async kontrol yap
        final state = await _audioPlayer.state;
        if (state == PlayerState.playing) {
          return;
        }
      }
      await _audioPlayer.play(AssetSource('sound/keep.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      // Debug log'ları kaldır - production'da gereksiz
    }
  }

  /// Scanner sesini çalar (loop)
  Future<void> playScannerSound() async {
    try {
      // Ses kapalıysa çalma - cache'den oku
      final isSoundEnabled = await _getSoundEnabled();
      if (!isSoundEnabled) {
        return;
      }

      // Eğer scanner sesi zaten çalıyorsa tekrar başlatma
      if (_isScannerPlaying) {
        // State kontrolünü optimize et - sadece gerekirse async çağrı yap
        try {
          final state = _scannerPlayer.state;
          if (state == PlayerState.playing) {
            return;
          }
        } catch (_) {
          // State okunamazsa async kontrol yap
          final state = await _scannerPlayer.state;
          if (state == PlayerState.playing) {
            return;
          }
        }
      }
      
      _isScannerPlaying = true;
      // Release mode'u sadece değiştiyse set et
      await _scannerPlayer.setReleaseMode(ReleaseMode.loop); // Loop modunda çal
      await _scannerPlayer.play(AssetSource('sound/scanner.mp3'));
    } catch (e) {
      // Ses çalma hatası sessizce yok sayılır
      _isScannerPlaying = false;
      // Debug log'ları kaldır - production'da gereksiz
    }
  }

  /// Scanner sesini durdur
  Future<void> stopScannerSound() async {
    try {
      // Flag'i önce false yap (tekrar çağrıları engellemek için)
      if (!_isScannerPlaying) {
        return; // Zaten durdurulmuş
      }
      
      _isScannerPlaying = false;
      
      // Player durumunu optimize et - sadece gerekirse async çağrı yap
      try {
        final state = _scannerPlayer.state;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          await _scannerPlayer.stop();
          // Release mode'u reset et (loop'u kaldır)
          await _scannerPlayer.setReleaseMode(ReleaseMode.release);
        }
      } catch (_) {
        // State okunamazsa async kontrol yap
        final state = await _scannerPlayer.state;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          await _scannerPlayer.stop();
          await _scannerPlayer.setReleaseMode(ReleaseMode.release);
        }
      }
    } catch (e) {
      // Hata durumunda da flag'i false yap
      _isScannerPlaying = false;
      // Debug log'ları kaldır - production'da gereksiz
    }
  }
  
  /// Ses durumunu güncelle (cache'i de günceller)
  Future<void> setSoundEnabled(bool enabled) async {
    _updateSoundEnabledCache(enabled);
    await _prefsService.setScanSoundEnabled(enabled);
    
    // Eğer ses kapatıldıysa ve scanner çalıyorsa durdur
    if (!enabled && _isScannerPlaying) {
      await stopScannerSound();
    }
  }
  
  /// Ses durumunu oku (cache'den)
  bool? get isSoundEnabled => _isSoundEnabledCache;

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

