import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/preferences_service.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(preferencesServiceProvider);
  return await service.isOnboardingCompleted();
});

final onboardingControllerProvider = Provider<OnboardingController>((ref) {
  return OnboardingController(ref.read(preferencesServiceProvider));
});

class OnboardingController {
  final PreferencesService _service;

  OnboardingController(this._service);

  Future<void> completeOnboarding() async {
    await _service.setOnboardingCompleted(true);
  }
}
