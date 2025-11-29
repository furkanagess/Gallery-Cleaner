import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/preferences_service.dart';

enum AppLocale { tr, en, es }

class LocaleCubit extends Cubit<Locale> {
  final _prefsService = PreferencesService();

  LocaleCubit() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final saved = await _prefsService.getLocale();
    if (saved != null) {
      emit(saved);
    }
  }

  Future<void> setLocale(Locale locale) async {
    emit(locale);
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
        return AppLocale.en;
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
