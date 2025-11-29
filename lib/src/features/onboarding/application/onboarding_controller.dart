import '../../../core/services/preferences_service.dart';

class OnboardingController {
  final PreferencesService _service;

  OnboardingController(this._service);

  Future<void> completeOnboarding() async {
    await _service.setOnboardingCompleted(true);
  }
}
