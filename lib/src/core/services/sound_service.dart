class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // Scan sound feature removed – class kept only for backward-compat API.

  Future<void> initializeCache() async {}
  Future<void> setSoundVolume(double volume) async {}
  double? get soundVolume => 0.0;
  Future<void> playDeleteSound() async {}
  Future<void> playKeepSound() async {}
  Future<void> setSoundEnabled(bool enabled) async {}
  bool? get isSoundEnabled => false;
  Future<void> stop() async {}
  void dispose() {}
}
