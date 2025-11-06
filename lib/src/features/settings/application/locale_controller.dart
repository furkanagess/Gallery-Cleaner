import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/preferences_service.dart';

enum AppLocale { tr, en, es }

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale> {
  final _prefsService = PreferencesService();

  LocaleController() : super(const Locale('tr')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final saved = await _prefsService.getLocale();
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _prefsService.saveLocale(locale);
  }

  AppLocale getAppLocale() {
    switch (state.languageCode) {
      case 'tr':
        return AppLocale.tr;
      case 'en':
        return AppLocale.en;
      case 'es':
        return AppLocale.es;
      default:
        return AppLocale.tr;
    }
  }

  Future<void> setAppLocale(AppLocale locale) async {
    final newLocale = switch (locale) {
      AppLocale.tr => const Locale('tr'),
      AppLocale.en => const Locale('en'),
      AppLocale.es => const Locale('es'),
    };
    await setLocale(newLocale);
  }
}

