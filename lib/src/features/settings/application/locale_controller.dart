import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/preferences_service.dart';

enum AppLocale { tr, en, es }

class LocaleCubit extends Cubit<Locale> {
  final _prefsService = PreferencesService();

  LocaleCubit() : super(_getInitialLocale()) {
    _loadLocale();
  }

  /// İlk açılışta sistem diline göre locale belirle
  /// Türkçe ise Türkçe, değilse İngilizce
  static Locale _getInitialLocale() {
    final systemLocale = PlatformDispatcher.instance.locale;
    if (systemLocale.languageCode == 'tr') {
      return const Locale('tr');
    }
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final saved = await _prefsService.getLocale();
    if (saved != null) {
      // Kullanıcı daha önce bir dil seçmişse onu kullan
      emit(saved);
    } else {
      // İlk açılışta sistem diline göre ayarla ve kaydet
      final initialLocale = _getInitialLocale();
      emit(initialLocale);
      await _prefsService.saveLocale(initialLocale);
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
